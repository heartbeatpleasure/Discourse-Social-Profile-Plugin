# frozen_string_literal: true

module ::DiscourseSocialProfile
  module ProfilePresenter
    PRESENTATION_BUDGET = 0.5.seconds

    module_function

    def for_user(user, tracking: false)
      return [] unless user

      links =
        Link
          .where(user_id: user.id)
          .includes(platform: %i[icon_image_upload icon_mask_upload])
          .joins(:platform)
          .merge(Platform.enabled.ordered)
          .to_a

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + PRESENTATION_BUDGET.to_f
      presented = []
      links.each do |link|
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        item = present(link, tracking: tracking)
        presented << item if item
      end
      presented
    rescue StandardError => e
      log_presenter_error(e, user_id: user&.id)
      []
    end

    def present(link, tracking: false)
      platform = link.platform
      result = LinkBuilder.call(platform, link.value)
      return nil unless result.ok?

      trackable = tracking && result.href.start_with?("https://")

      {
        key: platform.key,
        label: platform.label,
        href: result.href,
        click_token: trackable ? link.click_token : nil,
        icon_name: platform.icon_name.presence || "globe",
        icon_image_url: safe_icon_value(platform, :image_url),
        icon_mask_url: safe_icon_value(platform, :mask_url),
        badge_background: platform.badge_background,
        badge_background_dark: platform.badge_background_dark,
        badge_radius: normalized_radius(platform.badge_radius),
        color: platform.color,
        color_dark: platform.color_dark,
      }
    rescue StandardError => e
      log_presenter_error(e, user_id: link&.user_id, platform_id: link&.platform_id)
      nil
    end

    def safe_icon_value(platform, method_name)
      platform.public_send(method_name)
    rescue StandardError => e
      log_presenter_error(e, platform_id: platform&.id, field: method_name)
      nil
    end

    def normalized_radius(value)
      radius = value.to_s.strip
      return nil if radius.blank?
      radius.match?(/\A\d+(?:\.\d+)?\z/) ? "#{radius}px" : radius
    end

    def log_presenter_error(error, user_id: nil, platform_id: nil, field: nil)
      details = []
      details << "user_id=#{user_id}" if user_id
      details << "platform_id=#{platform_id}" if platform_id
      details << "field=#{field}" if field
      suffix = details.present? ? " (#{details.join(', ')})" : ""
      Rails.logger.warn(
        "[discourse-social-profile] profile presentation skipped#{suffix}: #{error.class}",
      )
    end
  end
end
