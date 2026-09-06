# frozen_string_literal: true

require "nokogiri"
require "fastimage"
require "stringio"

module ::DiscourseSocialProfile
  class Platform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"

    INPUT_TYPES = %w[handle numeric_id email url_locked url_any_https].freeze
    MAX_ICON_UPLOAD_BYTES = 1.megabyte
    MAX_ICON_DIMENSION = 4096
    MAX_SVG_NODES = 5000
    MAX_PLATFORMS = 250
    SVG_NAMESPACE = "http://www.w3.org/2000/svg"
    SVG_RAW_FORBIDDEN = /<!\s*(?:doctype|entity)\b/i
    SVG_ALLOWED_ELEMENTS = %w[
      circle clippath defs ellipse g line lineargradient marker path polygon polyline
      radialgradient rect stop style svg text textpath tref tspan use
    ].freeze
    RASTER_TYPES = { "png" => :png, "jpg" => :jpeg, "jpeg" => :jpeg, "webp" => :webp }.freeze
    SVG_LOCAL_URL_REFERENCE = /url\(\s*(["']?)#[A-Za-z0-9_.:-]+\1\s*\)/i
    SVG_DANGEROUS_CSS = /(?:@import|expression\s*\(|behavior\s*:|(?:image|image-set|-webkit-image-set|cross-fade|element)\s*\()/i

    has_many :links,
             class_name: "::DiscourseSocialProfile::Link",
             foreign_key: :platform_id,
             inverse_of: :platform
    has_many :click_stats,
             class_name: "::DiscourseSocialProfile::ClickStat",
             foreign_key: :platform_id,
             inverse_of: :platform

    belongs_to :icon_image_upload, class_name: "::Upload", optional: true
    belongs_to :icon_mask_upload, class_name: "::Upload", optional: true

    validates :key,
              presence: true,
              uniqueness: true,
              length: { maximum: 64 },
              format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
    validates :label, presence: true, length: { maximum: 100 }
    validates :input_type, inclusion: { in: INPUT_TYPES }
    validates :user_instructions, length: { maximum: 1000 }, allow_blank: true
    validates :placeholder, length: { maximum: 255 }, allow_blank: true
    validates :base_url, length: { maximum: 2048 }, allow_blank: true
    validates :allowed_hosts, length: { maximum: 4096 }, allow_blank: true
    validates :path_regex, length: { maximum: 512 }, allow_blank: true
    validates :icon_name,
              length: { maximum: 100 },
              format: { with: /\A[a-z0-9][a-z0-9-]*\z/ },
              allow_blank: true
    validates :builtin_icon,
              inclusion: { in: DiscourseSocialProfile::BUNDLED_MASKS },
              allow_blank: true
    validates :icon_image_url, length: { maximum: 2048 }, allow_blank: true
    validates :icon_mask_url, length: { maximum: 2048 }, allow_blank: true
    validates :badge_background,
              :badge_background_dark,
              :color,
              :color_dark,
              length: { maximum: 128 },
              allow_blank: true
    validates :badge_radius, length: { maximum: 64 }, allow_blank: true
    validates :legacy_user_field_name, length: { maximum: 255 }, allow_blank: true
    validate :validate_configuration
    validate :platform_limit
    validate :key_immutable_when_used, on: :update
    validate :validate_upload_types

    before_validation :normalize_fields
    after_save :sync_upload_references
    after_commit :sync_svg_icon_preloads
    after_destroy :clear_upload_references

    scope :ordered, -> { order(:position, :id) }
    scope :enabled, -> { where(enabled: true) }

    def usage_count
      links.count
    end

    def image_url
      if public_icon_upload?(icon_image_upload, %w[png jpg jpeg svg webp])
        return GlobalPath.full_cdn_url(icon_image_upload.url)
      end

      if SiteSetting.discourse_social_profile_allow_external_icon_urls
        return icon_image_url if PlatformValidator.safe_external_icon_url?(icon_image_url, mask: false)

        # A CSS mask request cannot carry an element-level Referrer-Policy. Render
        # administrator-configured external mask URLs as ordinary <img> resources
        # instead, so the frontend can enforce referrerpolicy="no-referrer". Native
        # uploaded and bundled masks remain true CSS masks and retain recoloring.
        return icon_mask_url if PlatformValidator.safe_external_icon_url?(icon_mask_url, mask: true)
      end

      nil
    end

    def mask_url
      if public_icon_upload?(icon_mask_upload, %w[svg])
        return GlobalPath.full_cdn_url(icon_mask_upload.url)
      end
      return nil unless DiscourseSocialProfile::BUNDLED_MASKS.include?(builtin_icon)

      "#{Discourse.base_path}#{DiscourseSocialProfile::PUBLIC_ASSET_BASE}/#{builtin_icon}.svg"
    end

    private

    def public_icon_upload?(upload, extensions)
      return false unless upload
      return false if upload.secure? || upload.filesize.to_i <= 0 || upload.filesize.to_i > MAX_ICON_UPLOAD_BYTES

      extension = upload.extension.to_s.downcase
      extensions.include?(extension) && FileHelper.is_supported_image?("icon.#{extension}")
    end

    # Upload bytes are verified when an administrator attaches or changes an icon.
    # Rendering deliberately avoids re-reading Upload#content so profile/user-card
    # requests never acquire a new local/S3 I/O dependency. Discourse sanitizes SVGs
    # at upload ingestion and Upload content is treated as immutable by core.
    def safe_upload_content?(upload, extension)
      extension == "svg" ? safe_svg_upload?(upload) : safe_raster_upload?(upload, extension)
    end

    def normalize_fields
      self.key = key.to_s.strip.downcase
      self.label = label.to_s.strip
      self.input_type = input_type.to_s.strip
      self.base_url = base_url.to_s.strip.presence
      self.allowed_hosts = allowed_hosts.to_s.strip.presence
      self.path_regex = path_regex.to_s.strip.presence
      self.icon_name = icon_name.to_s.strip.presence
      self.builtin_icon = builtin_icon.to_s.strip.presence
      self.icon_image_url = icon_image_url.to_s.strip.presence
      self.icon_mask_url = icon_mask_url.to_s.strip.presence
      self.badge_background = badge_background.to_s.strip.presence
      self.badge_background_dark = badge_background_dark.to_s.strip.presence
      self.badge_radius = badge_radius.to_s.strip.presence
      self.color = color.to_s.strip.presence
      self.color_dark = color_dark.to_s.strip.presence
      self.legacy_user_field_name = legacy_user_field_name.to_s.strip.presence
    end

    def validate_configuration
      result = ::DiscourseSocialProfile::PlatformValidator.call(self)
      result[:errors].each { |attribute, message| errors.add(attribute, message) }
    end

    def platform_limit
      return unless new_record?
      return if self.class.count < MAX_PLATFORMS
      errors.add(:base, "cannot exceed #{MAX_PLATFORMS} social profile platforms")
    end

    def key_immutable_when_used
      return unless will_save_change_to_key?
      return unless links.exists?
      errors.add(:key, "cannot be changed after user values exist")
    end

    def validate_upload_types
      validate_upload_reference(icon_image_upload_id, icon_image_upload, :icon_image_upload, %w[png jpg jpeg svg webp])
      validate_upload_reference(icon_mask_upload_id, icon_mask_upload, :icon_mask_upload, %w[svg])
    end

    def validate_upload_reference(upload_id, upload, attribute, extensions)
      if upload_id.present? && upload.blank?
        errors.add(attribute, "does not reference an existing upload")
        return
      end

      validate_upload(upload, attribute, extensions)
    end

    def validate_upload(upload, attribute, extensions)
      return if upload.blank?

      extension = upload.extension.to_s.downcase
      unless extensions.include?(extension) && FileHelper.is_supported_image?("icon.#{extension}")
        errors.add(attribute, "has an unsupported image type")
        return
      end

      if upload.secure?
        errors.add(attribute, "must not be a secure upload")
        return
      end
      if upload.filesize.to_i > MAX_ICON_UPLOAD_BYTES
        errors.add(attribute, "must be 1 MB or smaller")
        return
      end

      errors.add(attribute, "does not contain a valid safe image") unless safe_upload_content?(upload, extension)
    end

    # Discourse sanitizes SVGs in UploadCreator. Validate again when an existing
    # upload is attached to this plugin because uploads can originate from other
    # upload surfaces and SVG handling has historically been security-sensitive.
    def safe_svg_upload?(upload)
      content = upload.content
      return false if content.blank? || content.bytesize > MAX_ICON_UPLOAD_BYTES
      # Reject declarations before handing the bytes to an XML parser. Libxml/Nokogiri
      # already applies entity-expansion limits, but DTD/entities are unnecessary for
      # icons and have repeatedly been a source of SVG parser vulnerabilities.
      return false if content.match?(SVG_RAW_FORBIDDEN)

      document = Nokogiri.XML(content) { |config| config.strict.nonet }
      root = document.root
      return false unless root && root.name.to_s.downcase == "svg"
      root_namespace = root.namespace&.href.to_s
      return false unless root_namespace.blank? || root_namespace == SVG_NAMESPACE
      return false if document.internal_subset || document.external_subset
      return false if document.xpath("//processing-instruction()").present?
      elements = document.xpath("//*")
      return false if elements.length > MAX_SVG_NODES
      return false if elements.any? { |node| !SVG_ALLOWED_ELEMENTS.include?(node.name.to_s.downcase) }
      return false if document.xpath("//@*[starts-with(translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'on')]").present?

      document.xpath("//@*").each do |attribute|
        name = attribute.name.to_s.downcase
        value = attribute.value.to_s
        namespace_prefix = attribute.namespace&.prefix.to_s.downcase
        return false if name == "base" && namespace_prefix == "xml"
        if name == "href" && value.present? && !value.start_with?("#")
          return false
        end
        return false unless safe_svg_css_references?(value)
      end

      document.xpath("//*[local-name()='style']").each do |style|
        return false unless safe_svg_css_references?(style.text.to_s)
      end

      true
    rescue StandardError
      false
    end

    def safe_raster_upload?(upload, extension)
      content = upload.content
      return false if content.blank? || content.bytesize > MAX_ICON_UPLOAD_BYTES

      expected = RASTER_TYPES[extension]
      return false unless expected

      image = FastImage.new(StringIO.new(content))
      return false unless image.type == expected

      dimensions = image.size
      dimensions.is_a?(Array) && dimensions.length == 2 &&
        dimensions.all? { |dimension| dimension.to_i.positive? && dimension.to_i <= MAX_ICON_DIMENSION }
    rescue StandardError
      false
    end

    def safe_svg_css_references?(value)
      text = value.to_s
      return false if text.include?("\\") || text.include?("/*") || text.include?("*/")
      return false if text.match?(SVG_DANGEROUS_CSS)
      return true unless text.match?(/url\s*\(/i)

      remainder = text.gsub(SVG_LOCAL_URL_REFERENCE, "")
      !remainder.match?(/url\s*\(/i)
    end

    def sync_upload_references
      ids = [icon_image_upload_id, icon_mask_upload_id].compact
      UploadReference.ensure_exist!(upload_ids: ids, target: self)
    end

    def sync_svg_icon_preloads
      # Keep the generated SiteSetting bounded to icon names actually referenced by
      # current platform records. The previous append-only behavior could retain an
      # unlimited history of renamed/deleted custom icons and unnecessarily grow the
      # SVG sprite over time. MAX_PLATFORMS + icon_name validation bounds this list.
      icons =
        self.class
          .where.not(icon_name: [nil, ""])
          .distinct
          .order(:icon_name)
          .limit(MAX_PLATFORMS)
          .pluck(:icon_name)
          .reject { |name| DiscourseSocialProfile::BASE_SVG_ICONS.include?(name) }
      serialized = icons.join("|")
      return if SiteSetting.discourse_social_profile_extra_svg_icons.to_s == serialized

      SiteSetting.discourse_social_profile_extra_svg_icons = serialized
    rescue => e
      Rails.logger.warn("[discourse-social-profile] SVG icon preload sync failed: #{e.class}")
    end

    def clear_upload_references
      UploadReference.ensure_exist!(upload_ids: [], target_type: self.class.name, target_id: id)
    end
  end
end
