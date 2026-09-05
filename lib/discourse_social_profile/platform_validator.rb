# frozen_string_literal: true

require "uri"

module ::DiscourseSocialProfile
  module PlatformValidator
    CONTROL_OR_STYLE_BREAK = /[\u0000-\u001F\u007F;{}<>]/
    UNSAFE_CSS_URL_CHARS = /[\'"()\\]/
    COLOR_PATTERNS = [
      /\A#[0-9a-fA-F]{3,8}\z/,
      /\A[a-zA-Z][a-zA-Z0-9-]{0,31}\z/,
      /\A(?:rgb|rgba|hsl|hsla)\([0-9.,%\s+-]+\)\z/,
      /\Avar\(--[a-zA-Z0-9_-]+\)\z/,
    ].freeze
    RADIUS_TOKEN = /(?:0|(?:\d+(?:\.\d+)?)(?:px|em|rem|%|vh|vw|vmin|vmax)?|var\(--[a-zA-Z0-9_-]+\))/
    RADIUS_PATTERN = /\A#{RADIUS_TOKEN}(?:\s+#{RADIUS_TOKEN}){0,3}(?:\s*\/\s*#{RADIUS_TOKEN}(?:\s+#{RADIUS_TOKEN}){0,3})?\z/

    module_function

    def call(platform)
      errors = {}
      validate_url_fields(platform, errors)
      validate_regex(platform, errors)
      validate_css(platform, errors)
      validate_external_icons(platform, errors)
      validate_input_contract(platform, errors)
      { valid: errors.empty?, errors: errors }
    end

    def validate_url_fields(platform, errors)
      return if platform.base_url.blank?
      uri = safe_https_uri(platform.base_url)
      if uri.nil? || uri.userinfo.present? || uri.host.blank? || non_default_port?(uri) || uri.query.present? || uri.fragment.present?
        errors[:base_url] = "must be an absolute HTTPS URL without credentials, query, fragment, or a non-default port"
      end
    end

    def validate_regex(platform, errors)
      return if platform.path_regex.blank?
      begin
        regex = Regexp.new(platform.path_regex, timeout: LinkBuilder::REGEX_TIMEOUT)
        regex.match?("/validation-probe/path")
      rescue RegexpError
        errors[:path_regex] = "is invalid or too expensive"
      end
    end

    def validate_css(platform, errors)
      %i[badge_background badge_background_dark color color_dark].each do |attribute|
        value = platform.public_send(attribute).to_s.strip
        next if value.blank?
        if value.match?(CONTROL_OR_STYLE_BREAK) || !COLOR_PATTERNS.any? { |pattern| value.match?(pattern) }
          errors[attribute] = "is not a supported safe CSS color"
        end
      end

      radius = platform.badge_radius.to_s.strip
      if radius.present? && (radius.match?(CONTROL_OR_STYLE_BREAK) || !radius.match?(RADIUS_PATTERN))
        errors[:badge_radius] = "is not a supported safe border radius"
      end
    end

    def validate_external_icons(platform, errors)
      %i[icon_image_url icon_mask_url].each do |attribute|
        value = platform.public_send(attribute).to_s.strip
        next if value.blank?
        unless SiteSetting.discourse_social_profile_allow_external_icon_urls
          errors[attribute] = "is disabled by the global external icon URL setting"
          next
        end
        uri = safe_https_uri(value)
        invalid = uri.nil? || uri.userinfo.present? || uri.host.blank? || non_default_port?(uri)
        invalid ||= attribute == :icon_mask_url && value.match?(UNSAFE_CSS_URL_CHARS)
        if invalid
          errors[attribute] =
            attribute == :icon_mask_url ?
              "must be a safe absolute HTTPS URL without credentials, CSS-breaking characters, or a non-default port" :
              "must be a safe absolute HTTPS URL without credentials or a non-default port"
        end
      end
    end

    def validate_input_contract(platform, errors)
      case platform.input_type.to_s
      when "handle", "numeric_id"
        errors[:base_url] = "is required for this input type" if platform.base_url.blank?
      when "url_locked"
        errors[:allowed_hosts] = "is required for url_locked" if normalized_hosts(platform.allowed_hosts).empty?
      end

      normalized_hosts(platform.allowed_hosts).each do |host|
        bare = host.delete_prefix(".")
        if bare.blank? || bare.include?(":") || bare.include?("/") || !bare.ascii_only? || bare.match?(/\s/)
          errors[:allowed_hosts] = "contains an invalid hostname"
          break
        end
      end
    end

    def safe_https_uri(value)
      return nil if value.blank? || value.match?(/[\u0000-\u001F\u007F]/) || value.match?(/%(?:0[0-9a-f]|1[0-9a-f]|7f)/i) || value.start_with?("//")
      uri = URI.parse(value)
      return nil unless uri.is_a?(URI::HTTPS)
      return nil unless uri.host.to_s.ascii_only?
      uri
    rescue URI::InvalidURIError
      nil
    end

    def non_default_port?(uri)
      uri.port && uri.port != 443
    end

    def normalized_hosts(value)
      value.to_s.split(/[,\s]+/).map { |h| h.strip.downcase.chomp(".") }.reject(&:blank?).uniq
    end
  end
end
