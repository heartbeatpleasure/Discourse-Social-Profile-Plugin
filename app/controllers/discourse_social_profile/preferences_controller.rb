# frozen_string_literal: true

module ::DiscourseSocialProfile
  class PreferencesController < ::ApplicationController
    requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_plugin_enabled

    MAX_PREFERENCES_ENTRIES = Platform::MAX_PLATFORMS
    VALIDATION_BUDGET = 1.second

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

      errors = {}
      normalized = {}

      # Serialize concurrent saves for one account, then lock the referenced
      # platform rows while validating and writing. Admin validation changes use
      # the same row locks, preventing a value from being accepted against stale
      # platform rules during a concurrent configuration update.
      DistributedMutex.synchronize("social-profile-preferences-#{current_user.id}") do
        Link.transaction do
          platforms =
            Platform.where(id: platform_ids).order(:id).lock.to_a.index_by(&:id)
          existing_links =
            Link
              .where(user_id: current_user.id, platform_id: platform_ids)
              .order(:platform_id)
              .lock
              .to_a
              .index_by(&:platform_id)

          validation_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + VALIDATION_BUDGET.to_f

          entries.each do |entry|
            platform_id = strict_positive_id(entry[:platform_id])
            platform = platforms[platform_id]
            if platform.nil?
              errors[platform_id] = "invalid_platform"
              next
            end

            value = entry[:value].to_s.strip

            # Disabled platforms are hidden from public rendering, but an owner must
            # still be able to erase an identifier stored before an administrator
            # disabled that platform. Never permit creating/updating a nonblank value
            # while disabled; blank is deletion-only and therefore safe.
            unless platform.enabled?
              if value.blank?
                normalized[platform_id] = nil
              elsif existing_links[platform_id]&.value.to_s == value
                # Preserve an unchanged value as a no-op so a disabled platform
                # does not block saving unrelated enabled profiles. Any attempt to
                # create or alter a nonblank value while disabled still fails.
              else
                errors[platform_id] = "platform_disabled"
              end
              next
            end

            next normalized[platform_id] = nil if value.blank?

            if Process.clock_gettime(Process::CLOCK_MONOTONIC) > validation_deadline
              errors[:base] = "validation_timed_out"
              break
            end

            result = LinkBuilder.call(platform, value)
            if result.ok?
              normalized[platform_id] = result.canonical_value
            else
              errors[platform_id] = result.error_code
            end
          end

          if errors.empty?
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
        end
      end

      if errors.present?
        return render_json_dump({ success: false, errors: errors }, status: :unprocessable_entity)
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
      raw = params[:social_profile_links]
      return raw if raw.is_a?(Array)

      # Form-encoded API clients can serialize an array of objects as numeric
      # keys. Keep this shape under the plugin-specific, log-filtered outer
      # parameter; generic legacy aliases are deliberately not accepted.
      if raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
        keys = raw.keys.map(&:to_s)
        if keys.all? { |key| key.match?(/\A\d+\z/) }
          return keys.sort_by(&:to_i).map { |key| raw[key] || raw[key.to_sym] }
        end
      end

      raise ActionController::BadRequest, "social profile links must be an array"
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
      raw = value.to_s
      return nil unless raw.match?(/\A[1-9]\d{0,18}\z/)

      id = raw.to_i
      id <= 9_223_372_036_854_775_807 ? id : nil
    end

    def platform_payloads
      values = Link.where(user_id: current_user.id).pluck(:platform_id, :value).to_h
      platforms =
        Platform
          .where(enabled: true)
          .or(Platform.where(id: values.keys))
          .ordered
          .includes(:icon_image_upload, :icon_mask_upload)

      platforms.map do |platform|
        value = values[platform.id].to_s
        result = value.present? ? LinkBuilder.call(platform, value) : nil
        {
          id: platform.id,
          key: platform.key,
          enabled: platform.enabled?,
          label: platform.label,
          instructions: platform.user_instructions,
          placeholder: platform.placeholder,
          input_type: platform.input_type,
          icon_name: platform.icon_name.presence || "globe",
          icon_image_url: platform.image_url,
          icon_mask_url: platform.mask_url,
          value: value,
          valid: result.nil? || result.ok?,
          preview_href: platform.enabled? && result&.ok? ? result.href : nil,
          error_code: result&.ok? == false ? result.error_code : nil,
        }
      end
    end
  end
end
