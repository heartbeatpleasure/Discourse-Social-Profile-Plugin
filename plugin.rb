# frozen_string_literal: true

# name: Discourse-Social-Profile-Plugin
# about: Native social profile links for Discourse with plugin-owned data, secure validation, admin management and statistics.
# version: 0.1.17
# authors: Chris
# url: https://github.com/heartbeatpleasure/Discourse-Social-Profile-Plugin
# required_version: 2026.7.2

# Match the proven standalone admin-route pattern used by HIBP, Link Safety,
# Heartrate and Disify on this installation. The admin sidebar opens the
# Social Profile dashboard; Installed Plugins -> Settings remains a direct
# Site Settings destination.
add_admin_route "discourse_social_profile.admin.title", "socialProfile"

enabled_site_setting :discourse_social_profile_enabled

register_asset "stylesheets/common/social-profile.scss"
register_asset "stylesheets/mobile/social-profile.scss", :mobile

module ::DiscourseSocialProfile
  PLUGIN_NAME = "Discourse-Social-Profile-Plugin"
  VERSION = "0.1.16"
  BUNDLED_MASKS = %w[
    onlyfans fansly fetlife fancentro linktree pornhub tumblr discord-mask
    kick kofi buymeacoffee beacons chaturbate manyvids loyalfans clips4sale
    iwantclips redgifs xvideos
  ].freeze
  PUBLIC_ASSET_BASE = "/plugins/#{PLUGIN_NAME}/images/social-profile".freeze
  BASE_SVG_ICONS = %w[
    address-card user globe link envelope fab-twitter fab-x-twitter fab-facebook fab-linkedin-in
    fab-instagram fab-threads fab-youtube fab-discord fab-steam fab-twitch
    fab-bandcamp fab-spotify fab-soundcloud fab-tiktok fab-telegram fab-mastodon
    fab-bluesky fab-github fab-strava fab-tumblr fab-amazon fab-reddit-alien
    fab-snapchat fab-pinterest-p fab-patreon fab-medium fab-deviantart fab-vimeo-v
    fab-flickr image arrow-up arrow-down pencil trash-can plus check flask
  ].freeze
end

DiscourseSocialProfile::BASE_SVG_ICONS.each { |icon| register_svg_icon icon }

# Discourse 2026.7 stable does not yet provide the newer dynamic
# `register_svg_icon_source` API. Baseline icons are registered above; custom
# platform icon names are added to `discourse_social_profile_extra_svg_icons`
# when a platform is saved. Stable Discourse includes SiteSettings containing
# `_icon` in the SVG sprite and expires that sprite when such settings change.
after_initialize do
  # Social-profile values can contain email addresses, usernames and adult-profile
  # destinations. Click tokens are opaque analytics capabilities. Use plugin-specific
  # parameter names so this data stays out of normal Rails request parameter logs
  # without globally filtering generic Discourse keys such as `links` or `token`.
  Rails.application.config.filter_parameters += %i[
    social_profile_links
    social_profile_click_token
    social_profile_test_value
  ]

  require_relative "lib/discourse_social_profile/default_platforms"
  require_relative "lib/discourse_social_profile/url_safety"
  require_relative "lib/discourse_social_profile/link_builder"
  require_relative "lib/discourse_social_profile/platform_validator"
  require_relative "lib/discourse_social_profile/profile_presenter"
  require_relative "lib/discourse_social_profile/statistics"
  require_relative "lib/discourse_social_profile/user_data_cleanup"
  require_relative "lib/discourse_social_profile/user_data_merger"

  require_dependency File.expand_path("app/models/discourse_social_profile/platform.rb", __dir__)
  require_dependency File.expand_path("app/models/discourse_social_profile/link.rb", __dir__)
  require_dependency File.expand_path("app/models/discourse_social_profile/click_stat.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/preferences_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/clicks_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/overview_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/platforms_controller.rb", __dir__)
  require_dependency File.expand_path("app/controllers/discourse_social_profile/admin/statistics_controller.rb", __dir__)
  require_dependency File.expand_path("app/jobs/scheduled/discourse_social_profile/cleanup_click_stats.rb", __dir__)
  require_dependency File.expand_path("app/jobs/regular/discourse_social_profile/cleanup_user_data.rb", __dir__)

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
  # Never let plugin cleanup failures break Discourse's core destroy/anonymize flow:
  # attempt synchronously for privacy, then enqueue a retry if the database is
  # temporarily unavailable.
  cleanup_user_data = lambda do |user_id|
    begin
      ::DiscourseSocialProfile::UserDataCleanup.call(user_id)
    rescue StandardError => e
      Rails.logger.error(
        "[discourse-social-profile] user data cleanup failed; scheduling retry: #{e.class}",
      )
      begin
        Jobs.enqueue(:discourse_social_profile_cleanup_user_data, user_id: user_id)
      rescue StandardError => enqueue_error
        Rails.logger.error(
          "[discourse-social-profile] user data cleanup retry enqueue failed: #{enqueue_error.class}",
        )
      end
    end
  end

  DiscourseEvent.on(:user_destroyed) { |user| cleanup_user_data.call(user.id) }
  DiscourseEvent.on(:user_anonymized) { |user:, **_opts| cleanup_user_data.call(user.id) }

  # Core UserMerger fires this immediately before deleting the source account.
  # Handle it even when the feature SiteSetting is disabled so source-only plugin
  # data is not lost to the users foreign-key cascade. Target values win conflicts.
  # Unlike post-destroy cleanup, merge errors deliberately propagate: aborting the
  # merge before source deletion is safer than silently discarding private data.
  DiscourseEvent.on(:merging_users) do |source_user, target_user|
    ::DiscourseSocialProfile::UserDataMerger.call(source_user.id, target_user.id)
  end

  Discourse::Application.routes.append do
    # Ember-only frontend routes need matching Rails shell routes for direct
    # browser reloads. Without these, in-app navigation works but F5 reaches
    # Rails first and returns a 404 instead of booting the Discourse app.
    get "/admin/plugins/social-profile" => "admin/plugins#index", constraints: AdminConstraint.new
    get "/admin/plugins/Discourse-Social-Profile-Plugin/overview" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/Discourse-Social-Profile-Plugin/platforms" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/Discourse-Social-Profile-Plugin/platforms/new" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/Discourse-Social-Profile-Plugin/platforms/:id/edit" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/Discourse-Social-Profile-Plugin/statistics" => "admin/plugins#index",
        constraints: AdminConstraint.new

    get "/u/:username/preferences/social-profiles" => "users#preferences",
        constraints: { username: RouteFormat.username }

    get "/social-profile/preferences.json" => "discourse_social_profile/preferences#index"
    put "/social-profile/preferences.json" => "discourse_social_profile/preferences#update"
    # Click analytics deliberately uses one fixed POST endpoint. The opaque token
    # is carried in the CSRF-protected request body, never in a redirect URL or
    # normal request path, so the plugin cannot become a trusted-domain open
    # redirect and web-server access logs do not collect analytics tokens.
    post "/social-profile/click.json" => "discourse_social_profile/clicks#create"

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
