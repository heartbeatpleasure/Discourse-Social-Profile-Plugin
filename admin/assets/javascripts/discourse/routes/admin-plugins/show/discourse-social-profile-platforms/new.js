import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseSocialProfilePlatformsNewRoute extends DiscourseRoute {
  model() {
    return {
      platform: {
        key: "",
        enabled: true,
        label: "",
        user_instructions: "",
        placeholder: "",
        input_type: "handle",
        base_url: "https://",
        allowed_hosts: "",
        path_regex: "",
        icon_name: "globe",
        builtin_icon: "",
        icon_image_upload_id: null,
        icon_image_url: "",
        icon_mask_upload_id: null,
        icon_mask_url: "",
        badge_background: "",
        badge_background_dark: "",
        badge_radius: "",
        color: "",
        color_dark: "",
        legacy_user_field_name: "",
      },
      bundled_icons: ["onlyfans", "fansly", "fetlife", "fancentro", "linktree", "pornhub", "tumblr", "discord-mask"],
    };
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.platforms.create");
  }
}
