# frozen_string_literal: true

module ::DiscourseSocialProfile
  module Admin
    class PlatformsController < ::Admin::AdminController
      requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME
      before_action :find_platform, only: %i[show update destroy test_value]

      VALIDATION_CONTRACT_ATTRIBUTES = %i[input_type base_url allowed_hosts path_regex].freeze
      UPLOAD_ATTRIBUTES = %i[icon_image_upload_id icon_mask_upload_id].freeze

      def index
        response.headers["Cache-Control"] = "no-store"
        usage = Link.group(:platform_id).count
        render_json_dump(
          platforms:
            Platform.ordered.includes(:icon_image_upload, :icon_mask_upload).map do |platform|
              payload(platform).merge(usage_count: usage[platform.id].to_i)
            end,
          bundled_icons: DiscourseSocialProfile::BUNDLED_MASKS,
        )
      end

      def show
        response.headers["Cache-Control"] = "no-store"
        render_json_dump(
          platform: payload(@platform).merge(usage_count: @platform.usage_count),
          bundled_icons: DiscourseSocialProfile::BUNDLED_MASKS,
        )
      end

      def create
        attributes = platform_params
        return unless uploads_authorized?(attributes)

        platform = Platform.new(attributes)
        platform.position = Platform.maximum(:position).to_i + 1
        if platform.save
          log_action("social_profile_platform_created", platform, platform.attributes.keys)
          Statistics.clear!
          render_json_dump(platform: payload(platform), status: :created)
        else
          render_errors(platform)
        end
      end

      def update
        attributes = platform_params
        return unless uploads_authorized?(attributes, existing: @platform)

        # Load a separate persisted record instead of `dup`: uniqueness validators
        # must see this as the existing row, while the real instance remains untouched
        # until the candidate is known-valid.
        candidate = Platform.find(@platform.id)
        candidate.assign_attributes(attributes)
        return render_errors(candidate) unless candidate.valid?

        if validation_contract_changed?(candidate) && invalidates_existing_links?(candidate)
          return render_json_dump(
            { success: false, errors: { base: [I18n.t("discourse_social_profile.errors.platform_change_invalidates_links")] } },
            status: :unprocessable_entity,
          )
        end

        changed = attributes.keys.select { |key| @platform.public_send(key).to_s != attributes[key].to_s }
        @platform.assign_attributes(attributes)
        if @platform.save
          log_action("social_profile_platform_updated", @platform, changed)
          Statistics.clear!
          render_json_dump(platform: payload(@platform))
        else
          render_errors(@platform)
        end
      end

      def destroy
        if @platform.links.exists?
          return render_json_error(I18n.t("discourse_social_profile.errors.platform_in_use"), status: :conflict)
        end

        key = @platform.key
        @platform.destroy!
        StaffActionLogger.new(current_user).log_custom("social_profile_platform_deleted", platform_key: key)
        Statistics.clear!
        render_json_dump(success: true)
      end

      def reorder
        ids = Array(params[:ids]).map { |value| strict_positive_id(value) }
        expected = Platform.order(:id).pluck(:id)
        unless ids.none?(&:nil?) && ids.length == expected.length && ids.uniq.length == ids.length && ids.sort == expected.sort
          return render_json_error(I18n.t("discourse_social_profile.errors.invalid_reorder"), status: :unprocessable_entity)
        end

        Platform.transaction do
          ids.each_with_index { |id, index| Platform.where(id: id).update_all(position: index) }
        end
        StaffActionLogger.new(current_user).log_custom("social_profile_platforms_reordered", count: ids.length)
        Statistics.clear!
        render_json_dump(success: true)
      end

      def test_value
        response.headers["Cache-Control"] = "no-store"
        attributes = params.key?(:platform) ? platform_params : {}
        return unless uploads_authorized?(attributes, existing: @platform)

        candidate = Platform.find(@platform.id)
        candidate.assign_attributes(attributes)
        unless candidate.valid?
          return render_json_dump(
            { accepted: false, error_code: "invalid_platform_configuration", errors: candidate.errors.to_hash },
            status: :unprocessable_entity,
          )
        end

        result = LinkBuilder.call(candidate, params[:value])
        render_json_dump(
          accepted: result.ok?,
          href: result.href,
          canonical_value: result.canonical_value,
          error_code: result.error_code,
          matched_host: result.matched_host,
          matched_path: result.matched_path,
        )
      end

      private

      def find_platform
        @platform = Platform.find(params[:id])
      end

      def strict_positive_id(value)
        id = Integer(value.to_s, 10)
        id.positive? ? id : nil
      rescue ArgumentError, TypeError
        nil
      end

      def platform_params
        raw = params[:platform]
        permitted =
          case raw
          when ActionController::Parameters
            raw
          when Hash
            ActionController::Parameters.new(raw)
          else
            raise ActionController::BadRequest, "platform must be an object"
          end

        permitted
          .permit(
            :key,
            :enabled,
            :label,
            :user_instructions,
            :placeholder,
            :input_type,
            :base_url,
            :allowed_hosts,
            :path_regex,
            :icon_name,
            :builtin_icon,
            :icon_image_upload_id,
            :icon_image_url,
            :icon_mask_upload_id,
            :icon_mask_url,
            :badge_background,
            :badge_background_dark,
            :badge_radius,
            :color,
            :color_dark,
            :legacy_user_field_name,
          )
          .to_h
          .symbolize_keys
      end

      def uploads_authorized?(attributes, existing: nil)
        errors = {}
        UPLOAD_ATTRIBUTES.each do |attribute|
          raw_id = attributes[attribute]
          next if raw_id.blank?

          upload_id = strict_positive_id(raw_id)
          existing_id = existing&.public_send(attribute)
          next if upload_id.present? && existing_id.present? && upload_id == existing_id

          upload = upload_id ? Upload.find_by(id: upload_id) : nil
          if upload.blank? || upload.secure? || !UserUpload.exists?(user_id: current_user.id, upload_id: upload_id)
            errors[attribute] = [I18n.t("discourse_social_profile.errors.invalid_icon_upload")]
          end
        end
        return true if errors.empty?

        render_json_dump({ success: false, errors: errors }, status: :unprocessable_entity)
        false
      end

      def validation_contract_changed?(candidate)
        VALIDATION_CONTRACT_ATTRIBUTES.any? do |attribute|
          @platform.public_send(attribute).to_s != candidate.public_send(attribute).to_s
        end
      end

      def invalidates_existing_links?(candidate)
        @platform.links.select(:id, :value).find_each(batch_size: 1000) do |link|
          return true unless LinkBuilder.call(candidate, link.value).ok?
        end
        false
      end

      def payload(platform)
        {
          id: platform.id,
          key: platform.key,
          position: platform.position,
          enabled: platform.enabled,
          label: platform.label,
          user_instructions: platform.user_instructions,
          placeholder: platform.placeholder,
          input_type: platform.input_type,
          base_url: platform.base_url,
          allowed_hosts: platform.allowed_hosts,
          path_regex: platform.path_regex,
          icon_name: platform.icon_name,
          builtin_icon: platform.builtin_icon,
          icon_image_upload_id: platform.icon_image_upload_id,
          icon_image_url: platform.icon_image_url,
          resolved_icon_image_url: platform.image_url,
          icon_mask_upload_id: platform.icon_mask_upload_id,
          icon_mask_url: platform.icon_mask_url,
          resolved_icon_mask_url: platform.mask_url,
          badge_background: platform.badge_background,
          badge_background_dark: platform.badge_background_dark,
          badge_radius: platform.badge_radius,
          color: platform.color,
          color_dark: platform.color_dark,
          legacy_user_field_name: platform.legacy_user_field_name,
          builtin: platform.builtin,
        }
      end

      def render_errors(platform)
        render_json_dump({ success: false, errors: platform.errors.to_hash }, status: :unprocessable_entity)
      end

      def log_action(action, platform, changed)
        StaffActionLogger.new(current_user).log_custom(
          action,
          platform_id: platform.id,
          platform_key: platform.key,
          changed_attributes: changed,
        )
      end
    end
  end
end
