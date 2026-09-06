# frozen_string_literal: true

module ::DiscourseSocialProfile
  class ClicksController < ::ApplicationController
    requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME

    # Backward-compatible redirect for pages serialized by older plugin builds.
    # New builds keep the actual external href in the frontend and only POST an
    # aggregate click event in the background.
    def show
      ensure_tracking_enabled!
      link = find_link!
      raise Discourse::NotFound unless guardian.can_see_profile?(link.user)

      result = valid_destination!(link)
      record_click(link)
      no_store_headers!
      redirect_to result.href, allow_other_host: true
    end

    # Background analytics endpoint. It deliberately never returns the external
    # destination, so a copied token cannot be used to discover a hidden profile
    # URL. The browser follows the real external href independently of this call.
    def create
      ensure_tracking_enabled!
      link = find_link!
      valid_destination!(link)
      record_click(link)
      no_store_headers!
      head :no_content
    end

    private

    def ensure_tracking_enabled!
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_enabled
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_track_clicks
    end

    def find_link!
      token = params[:token].to_s
      raise Discourse::NotFound unless token.match?(Link::CLICK_TOKEN_PATTERN)

      link = Link.includes(:platform, :user).find_by(click_token: token)
      raise Discourse::NotFound unless link&.platform&.enabled?
      link
    end

    def valid_destination!(link)
      result = LinkBuilder.call(link.platform, link.value)
      raise Discourse::NotFound unless result.ok? && result.href.start_with?("https://")
      result
    end

    def record_click(link)
      begin
        # Do not use clicker identity or IP for analytics. Rate limiting is per
        # destination link and only controls whether the aggregate increment occurs.
        RateLimiter.new(nil, "social-profile-click-link-#{link.id}", 300, 1.minute).performed!
        ClickStat.increment_for!(link.platform_id)
      rescue RateLimiter::LimitExceeded
        # Navigation/UX must never depend on analytics.
      rescue => e
        Rails.logger.warn("[discourse-social-profile] click aggregation failed: #{e.class}")
      end
    end

    def no_store_headers!
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["Cache-Control"] = "no-store"
    end
  end
end
