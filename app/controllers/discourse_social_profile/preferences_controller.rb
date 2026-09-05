# frozen_string_literal: true

module ::DiscourseSocialProfile
  class PreferencesController < ::ApplicationController
    requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_plugin_enabled

    MAX_PREFERENCES_ENTRIES = Platform::MAX_PLATFORMS

    def index
      response.headers["Cache-Control"] = "no-store"
      render_json_dump(enabled: true, platforms: platform_payloads)
    end

    def update
      response.headers["Cache-Control"] = "no-store"
      RateLimiter.new(current_user, "social-profile-preferences-save", 20, 1.minute).performed!

      raw_entries = raw_links
      if raw_entries.length > MAX_PREFERENCES_ENTRIES
        return render_json_dump(
          { success: false, errors: { base: "too_many_platforms" } },
          status: :unprocessable_entity,
        )
      end

      entries = permitted_links(raw_entries)
      platform_ids = entries.map { |entry| strict_positive_id(entry[:platform_id]) }
      if platform_ids.any?(&:nil?)
        return render_json_dump(
          { success: false, errors: { base: "invalid_platform" } },
          status: :unprocessable_entity,
        )
      end

      if platform_ids.uniq.length != platform_ids.length
        return render_json_dump(
          { success: false, errors: { base: "duplicate_platform" } },
          status: :unprocessable_entity,
        )
      end

      platforms = Platform.enabled.where(id: platform_ids).index_by(&:id)
      errors = {}
      normalized = {}

      entries.each do |entry|
        platform_id = strict_positive_id(entry[:platform_id])
        platform = platforms[platform_id]
        if platform.nil?
          errors[platform_id] = "invalid_platform"
          next
        end

        value = entry[:value].to_s.strip
        next normalized[platform_id] = nil if value.blank?

        result = LinkBuilder.call(platform, value)
        if result.ok?
          normalized[platform_id] = result.canonical_value
        else
          errors[platform_id] = result.error_code
        end
      end

      if errors.present?
        return render_json_dump({ success: false, errors: errors }, status: :unprocessable_entity)
      end

      Link.transaction do
        normalized.each do |platform_id, value|
          if value.nil?
            Link.where(user_id: current_user.id, platform_id: platform_id).delete_all
          else
            link = Link.find_or_initialize_by(user_id: current_user.id, platform_id: platform_id)
            link.value = value
            link.save!
          end
        end
      end

      Statistics.clear!
      render_json_dump(success: true, platforms: platform_payloads)
    rescue RateLimiter::LimitExceeded
      render_json_error(I18n.t("rate_limiter.slow_down"), status: :too_many_requests)
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_enabled
    end

    def raw_links
      raw = params[:links]
      raise ActionController::BadRequest, "links must be an array" unless raw.is_a?(Array)
      raw
    end

    def permitted_links(raw)
      raw.map do |entry|
        permitted =
          case entry
          when ActionController::Parameters
            entry.permit(:platform_id, :value)
          when Hash
            ActionController::Parameters.new(entry).permit(:platform_id, :value)
          else
            raise ActionController::BadRequest, "each links entry must be an object"
          end
        permitted.to_h.symbolize_keys.slice(:platform_id, :value)
      end
    end

    def strict_positive_id(value)
      id = Integer(value.to_s, 10)
      id.positive? ? id : nil
    rescue ArgumentError, TypeError
      nil
    end

    def platform_payloads
      values = Link.where(user_id: current_user.id).pluck(:platform_id, :value).to_h
      Platform.enabled.ordered.includes(:icon_image_upload, :icon_mask_upload).map do |platform|
        value = values[platform.id].to_s
        result = value.present? ? LinkBuilder.call(platform, value) : nil
        {
          id: platform.id,
          key: platform.key,
          label: platform.label,
          instructions: platform.user_instructions,
          placeholder: platform.placeholder,
          input_type: platform.input_type,
          icon_name: platform.icon_name.presence || "globe",
          icon_image_url: platform.image_url,
          icon_mask_url: platform.mask_url,
          value: value,
          valid: result.nil? || result.ok?,
          preview_href: result&.ok? ? result.href : nil,
          error_code: result&.ok? == false ? result.error_code : nil,
        }
      end
    end
  end
end
