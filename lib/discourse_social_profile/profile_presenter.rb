# frozen_string_literal: true

module ::DiscourseSocialProfile
  module ProfilePresenter
    module_function

    def for_user(user, tracking: false)
      return [] unless user

      Link
        .where(user_id: user.id)
        .includes(platform: %i[icon_image_upload icon_mask_upload])
        .joins(:platform)
        .merge(Platform.enabled.ordered)
        .map { |link| present(link, tracking: tracking) }
        .compact
    end

    def present(link, tracking: false)
      platform = link.platform
      result = LinkBuilder.call(platform, link.value)
      return nil unless result.ok?

      href =
        tracking && result.href.start_with?("https://") ?
          "#{Discourse.base_path}/social-profile/click/#{link.click_token}" : result.href

      {
        key: platform.key,
        label: platform.label,
        href: href,
        icon_name: platform.icon_name.presence || "globe",
        icon_image_url: platform.image_url,
        icon_mask_url: platform.mask_url,
        badge_background: platform.badge_background,
        badge_background_dark: platform.badge_background_dark,
        badge_radius: normalized_radius(platform.badge_radius),
        color: platform.color,
        color_dark: platform.color_dark,
      }
    end

    def normalized_radius(value)
      radius = value.to_s.strip
      return nil if radius.blank?
      radius.match?(/\A\d+(?:\.\d+)?\z/) ? "#{radius}px" : radius
    end
  end
end
