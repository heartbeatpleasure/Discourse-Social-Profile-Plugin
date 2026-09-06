# frozen_string_literal: true

require "openssl"

module ::DiscourseSocialProfile
  class ClicksController < ::ApplicationController
    requires_plugin ::DiscourseSocialProfile::PLUGIN_NAME

    ACTOR_RATE_LIMIT = 120
    ACTOR_LINK_RATE_LIMIT = 30
    LINK_RATE_LIMIT = 300
    RATE_LIMIT_WINDOW = 1.minute

    # Background analytics endpoint. It never returns the external destination.
    # Invalid/hidden-profile replay attempts do not increment analytics and do not
    # reveal additional profile data to the caller. Analytics failures are always
    # fail-open for navigation because the browser follows the external href directly.
    def create
      ensure_tracking_enabled!
      token = validated_token!
      no_store_headers!

      # Apply the actor/IP limiter before any database lookup so random-token scans
      # cannot turn this optional analytics endpoint into an unbounded query surface.
      return head :no_content unless request_rate_limit_allowed?

      link = find_link(token)
      return head :no_content unless link&.platform&.enabled?
      return head :no_content unless guardian.can_see_profile?(link.user)
      return head :no_content unless valid_destination(link)
      return head :no_content unless actor_link_rate_limit_allowed?(link)

      record_click(link)
      head :no_content
    end

    private

    def ensure_tracking_enabled!
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_enabled
      raise Discourse::NotFound unless SiteSetting.discourse_social_profile_track_clicks
    end

    def validated_token!
      token = params[:token].to_s
      raise Discourse::NotFound unless token.match?(Link::CLICK_TOKEN_PATTERN)
      token
    end

    def find_link(token)
      Link.includes(:platform, :user).find_by(click_token: token)
    end

    def valid_destination(link)
      result = LinkBuilder.call(link.platform, link.value)
      result.ok? && result.href.start_with?("https://") ? result : nil
    end

    def record_click(link)
      return unless link_rate_limit_allowed?(link)

      ClickStat.increment_for!(link.platform_id)
    rescue StandardError => e
      Rails.logger.warn("[discourse-social-profile] click aggregation failed: #{e.class}")
    end

    def request_rate_limit_allowed?
      if current_user
        return RateLimiter
                 .new(
                   current_user,
                   "social-profile-click-request",
                   ACTOR_RATE_LIMIT,
                   RATE_LIMIT_WINDOW,
                   apply_limit_to_staff: true,
                 )
                 .performed!(raise_error: false)
      end

      # Public sites can have anonymous viewers. Use a keyed HMAC rather than a
      # reversible/raw address in the short-lived Redis rate-limit key.
      RateLimiter
        .new(nil, "social-profile-click-anon-#{anonymous_ip_key}", ACTOR_RATE_LIMIT, RATE_LIMIT_WINDOW)
        .performed!(raise_error: false)
    rescue StandardError => e
      # Analytics must not become an availability dependency. If Redis/rate
      # limiting is unavailable, skip the statistic rather than breaking links.
      Rails.logger.warn("[discourse-social-profile] click request limiter failed: #{e.class}")
      false
    end


    def actor_link_rate_limit_allowed?(link)
      if current_user
        return RateLimiter
                 .new(
                   current_user,
                   "social-profile-click-link-#{link.id}",
                   ACTOR_LINK_RATE_LIMIT,
                   RATE_LIMIT_WINDOW,
                   apply_limit_to_staff: true,
                 )
                 .performed!(raise_error: false)
      end

      ip_key = anonymous_ip_key
      RateLimiter
        .new(
          nil,
          "social-profile-click-anon-link-#{ip_key}-#{link.id}",
          ACTOR_LINK_RATE_LIMIT,
          RATE_LIMIT_WINDOW,
        )
        .performed!(raise_error: false)
    rescue StandardError => e
      Rails.logger.warn("[discourse-social-profile] click actor-link limiter failed: #{e.class}")
      false
    end

    def anonymous_ip_key
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        Rails.application.secret_key_base.to_s,
        request.remote_ip.to_s,
      )[0, 24]
    end

    def link_rate_limit_allowed?(link)
      RateLimiter
        .new(nil, "social-profile-click-link-#{link.id}", LINK_RATE_LIMIT, RATE_LIMIT_WINDOW)
        .performed!(raise_error: false)
    rescue StandardError => e
      Rails.logger.warn("[discourse-social-profile] click link limiter failed: #{e.class}")
      false
    end

    def no_store_headers!
      response.headers["Referrer-Policy"] = "no-referrer"
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
  end
end
