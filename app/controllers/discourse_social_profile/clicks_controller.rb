# frozen_string_literal: true

module ::DiscourseSocialProfile
  class ClicksController < ::ApplicationController
    requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME

    def show
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_enabled
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_track_clicks

      token = params[:token].to_s
      raise Discourse::NotFound unless token.match?(Link::CLICK_TOKEN_PATTERN)

      link = Link.includes(:platform, :user).find_by(click_token: token)
      raise Discourse::NotFound unless link&.platform&.enabled?
      raise Discourse::NotFound unless guardian.can_see_profile?(link.user)

      result = LinkBuilder.call(link.platform, link.value)
      raise Discourse::NotFound unless result.ok?

      begin
        # Do not use clicker identity or IP for analytics. Rate limiting is per
        # destination link and only controls whether the aggregate increment occurs.
        RateLimiter.new(nil, "social-profile-click-link-#{link.id}", 300, 1.minute).performed!
        ClickStat.increment_for!(link.platform_id)
      rescue RateLimiter::LimitExceeded
        # Navigation is more important than analytics; still redirect.
      rescue => e
        Rails.logger.warn("[discourse-social-profile] click aggregation failed: #{e.class}")
      end

      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["Cache-Control"] = "no-store"
      redirect_to result.href, allow_other_host: true
    end
  end
end
