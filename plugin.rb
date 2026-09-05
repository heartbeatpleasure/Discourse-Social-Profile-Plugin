# frozen_string_literal: true

# name: discourse-social-profile
# about: Native social profile links for Discourse with plugin-owned data, secure validation, admin management and statistics.
# version: 0.1.0
# authors: Chris
# url: https://github.com/heartbeatpleasure/Discourse-Social-Profile-Plugin
# required_version: 2026.7.2

enabled_site_setting :discourse_social_profile_enabled

register_asset "stylesheets/common/social-profile.scss"
register_asset "stylesheets/mobile/social-profile.scss", :mobile

add_admin_route(
  "discourse_social_profile.admin.title",
  "discourse-social-profile",
  use_new_show_route: true,
)

module ::DiscourseSocialProfile
  PLUGIN_NAME = "discourse-social-profile"
  VERSION = "0.1.0"
  BUNDLED_MASKS = %w[onlyfans fansly fetlife fancentro linktree pornhub tumblr discord-mask].freeze
  PUBLIC_ASSET_BASE = "/plugins/#{PLUGIN_NAME}/images/social-profile".freeze
end

%w[
  address-card user globe link envelope fab-twitter fab-facebook fab-linkedin-in
  fab-instagram fab-threads fab-youtube fab-discord fab-steam fab-twitch
  fab-bandcamp fab-spotify fab-soundcloud fab-tiktok fab-telegram fab-mastodon
  fab-bluesky fab-github fab-strava fab-tumblr fab-amazon image arrow-up
  arrow-down pencil trash-can plus check flask
].each { |icon| register_svg_icon icon }

# Discourse 2026.7 stable does not yet provide the newer dynamic
# `register_svg_icon_source` API. Baseline icons are registered above; custom
# platform icon names are added to `discourse_social_profile_extra_svg_icons`
# when a platform is saved. Stable Discourse includes SiteSettings containing
# `_icon` in the SVG sprite and expires that sprite when such settings change.
after_initialize do
  require_relative "lib/discourse_social_profile/default_platforms"
  require_relative "lib/discourse_social_profile/link_builder"
  require_relative "lib/discourse_social_profile/platform_validator"
  require_relative "lib/discourse_social_profile/profile_presenter"
  require_relative "lib/discourse_social_profile/statistics"

  require_dependency File.expand_path("app/models/discourse_social_profile/platform.rb", __dir__)
  require_dependency File.expand_path("app/models/discourse_social_profile/link.rb", __dir__)
  require_dependency File.expand_path("app/models/discourse_social_profile/click_stat.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/preferences_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/clicks_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/overview_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/platforms_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/statistics_controller.rb", __dir__)
  require_dependency File.expand_path("app/jobs/scheduled/discourse_social_profile/cleanup_click_stats.rb", __dir__)

  # UserSerializer inherits from UserCardSerializer. Register the card attribute first,
  # then the full-profile attribute so descendant-aware serializer registration leaves
  # each serializer with its own visibility SiteSetting.
  add_to_serializer(
    :user_card,
    :social_profiles,
    include_condition: -> do
      SiteSetting.discourse_social_profile_enabled &&
        SiteSetting.discourse_social_profile_show_on_user_card &&
        scope&.can_see_profile?(object)
    end,
  ) do
    ::DiscourseSocialProfile::ProfilePresenter.for_user(
      object,
      tracking: SiteSetting.discourse_social_profile_track_clicks,
    )
  end

  add_to_serializer(
    :user,
    :social_profiles,
    include_condition: -> do
      SiteSetting.discourse_social_profile_enabled &&
        SiteSetting.discourse_social_profile_show_on_profile &&
        scope&.can_see_profile?(object)
    end,
  ) do
    ::DiscourseSocialProfile::ProfilePresenter.for_user(
      object,
      tracking: SiteSetting.discourse_social_profile_track_clicks,
    )
  end

  # Self-only raw values. Current Discourse user archives use UserSerializer for
  # preferences_export, so this also places the owner's plugin data in that export.
  add_to_serializer(
    :user,
    :social_profile_values,
    respect_plugin_enabled: false,
    include_condition: -> { scope&.user&.id == object&.id },
  ) do
    ::DiscourseSocialProfile::Link
      .where(user_id: object.id)
      .includes(:platform)
      .order(:platform_id)
      .map do |link|
        {
          platform_key: link.platform.key,
          platform_label: link.platform.label,
          value: link.value,
        }
      end
  end

  # Cleanup must also run when the UI SiteSetting is disabled; plugin `on(...)`
  # callbacks are intentionally suppressed in that state, so register directly.
  DiscourseEvent.on(:user_destroyed) do |user|
    ::DiscourseSocialProfile::Link.where(user_id: user.id).delete_all
    ::DiscourseSocialProfile::Statistics.clear!
  end

  DiscourseEvent.on(:user_anonymized) do |user:, **_opts|
    ::DiscourseSocialProfile::Link.where(user_id: user.id).delete_all
    ::DiscourseSocialProfile::Statistics.clear!
  end

  Discourse::Application.routes.append do
    get "/social-profile/preferences.json" => "discourse_social_profile/preferences#index"
    put "/social-profile/preferences.json" => "discourse_social_profile/preferences#update"
    get "/social-profile/click/:token" => "discourse_social_profile/clicks#show", as: :discourse_social_profile_click

    get "/admin/plugins/discourse-social-profile/overview.json" =>
          "discourse_social_profile/admin/overview#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/discourse-social-profile/platforms.json" =>
          "discourse_social_profile/admin/platforms#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/discourse-social-profile/platforms/:id.json" =>
          "discourse_social_profile/admin/platforms#show",
        constraints: AdminConstraint.new
    post "/admin/plugins/discourse-social-profile/platforms.json" =>
           "discourse_social_profile/admin/platforms#create",
         constraints: AdminConstraint.new
    put "/admin/plugins/discourse-social-profile/platforms/:id.json" =>
          "discourse_social_profile/admin/platforms#update",
        constraints: AdminConstraint.new
    delete "/admin/plugins/discourse-social-profile/platforms/:id.json" =>
             "discourse_social_profile/admin/platforms#destroy",
           constraints: AdminConstraint.new
    post "/admin/plugins/discourse-social-profile/platforms/reorder.json" =>
           "discourse_social_profile/admin/platforms#reorder",
         constraints: AdminConstraint.new
    post "/admin/plugins/discourse-social-profile/platforms/:id/test.json" =>
           "discourse_social_profile/admin/platforms#test_value",
         constraints: AdminConstraint.new
    get "/admin/plugins/discourse-social-profile/statistics.json" =>
          "discourse_social_profile/admin/statistics#index",
        constraints: AdminConstraint.new
  end
end
