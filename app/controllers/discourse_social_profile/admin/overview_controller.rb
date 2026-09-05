# frozen_string_literal: true

module ::DiscourseSocialProfile
  module Admin
    class OverviewController < ::Admin::AdminController
      requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME

      def index
        response.headers["Cache-Control"] = "no-store"
        platform_count = Platform.count
        enabled_count = Platform.enabled.count
        used_platform_count = Link.distinct.count(:platform_id)
        native_image_count = Platform.where.not(icon_image_upload_id: nil).count
        native_mask_count = Platform.where.not(icon_mask_upload_id: nil).count

        render_json_dump(
          enabled: SiteSetting.discourse_social_profile_enabled,
          show_on_profile: SiteSetting.discourse_social_profile_show_on_profile,
          show_on_user_card: SiteSetting.discourse_social_profile_show_on_user_card,
          click_tracking_enabled: SiteSetting.discourse_social_profile_track_clicks,
          external_icon_urls_enabled: SiteSetting.discourse_social_profile_allow_external_icon_urls,
          platform_count: platform_count,
          enabled_platform_count: enabled_count,
          disabled_platform_count: platform_count - enabled_count,
          used_platform_count: used_platform_count,
          total_links: Link.count,
          native_image_uploads: native_image_count,
          native_mask_uploads: native_mask_count,
          bundled_icon_count: DiscourseSocialProfile::BUNDLED_MASKS.length,
          required_version: "2026.7.2",
        )
      end
    end
  end
end
