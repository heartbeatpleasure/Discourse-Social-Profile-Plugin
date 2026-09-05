# frozen_string_literal: true

module ::DiscourseSocialProfile
  class Platform < ActiveRecord::Base
    self.table_name = "discourse_social_profile_platforms"

    INPUT_TYPES = %w[handle numeric_id email url_locked url_any_https].freeze
    MAX_ICON_UPLOAD_BYTES = 1.megabyte
    MAX_PLATFORMS = 250

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
    validate :validate_configuration
    validate :platform_limit
    validate :key_immutable_when_used, on: :update
    validate :validate_upload_types

    before_validation :normalize_fields
    after_save :sync_upload_references
    after_commit :ensure_svg_icon_preloaded
    after_destroy :clear_upload_references

    scope :ordered, -> { order(:position, :id) }
    scope :enabled, -> { where(enabled: true) }

    def usage_count
      links.count
    end

    def image_url
      return GlobalPath.full_cdn_url(icon_image_upload.url) if icon_image_upload
      return nil unless SiteSetting.discourse_social_profile_allow_external_icon_urls
      icon_image_url.presence
    end

    def mask_url
      return GlobalPath.full_cdn_url(icon_mask_upload.url) if icon_mask_upload
      if SiteSetting.discourse_social_profile_allow_external_icon_urls && icon_mask_url.present?
        return icon_mask_url
      end
      return nil if builtin_icon.blank?

      "#{Discourse.base_path}#{DiscourseSocialProfile::PUBLIC_ASSET_BASE}/#{builtin_icon}.svg"
    end

    private

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
      validate_upload(icon_image_upload, :icon_image_upload, %w[png jpg jpeg svg webp])
      validate_upload(icon_mask_upload, :icon_mask_upload, %w[svg])
    end

    def validate_upload(upload, attribute, extensions)
      return if upload.blank?
      extension = upload.extension.to_s.downcase
      errors.add(attribute, "has an unsupported file type") unless extensions.include?(extension)
      errors.add(attribute, "must not be a secure upload") if upload.secure?
      errors.add(attribute, "must be 1 MB or smaller") if upload.filesize.to_i > MAX_ICON_UPLOAD_BYTES
    end

    def sync_upload_references
      ids = [icon_image_upload_id, icon_mask_upload_id].compact
      UploadReference.ensure_exist!(upload_ids: ids, target: self)
    end

    def ensure_svg_icon_preloaded
      return unless previous_changes.key?("icon_name")
      return if icon_name.blank?

      icons =
        SiteSetting.discourse_social_profile_extra_svg_icons.to_s.split("|").map(&:strip).reject(&:blank?)
      return if icons.include?(icon_name)

      SiteSetting.discourse_social_profile_extra_svg_icons = (icons + [icon_name]).uniq.join("|")
    rescue => e
      Rails.logger.warn("[discourse-social-profile] SVG icon preload update failed: #{e.class}")
    end

    def clear_upload_references
      UploadReference.ensure_exist!(upload_ids: [], target_type: self.class.name, target_id: id)
    end
  end
end
