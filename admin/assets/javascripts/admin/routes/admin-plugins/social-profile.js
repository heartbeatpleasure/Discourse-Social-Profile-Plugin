import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsSocialProfileRoute extends DiscourseRoute {
  async model() {
    try {
      return await ajax("/admin/plugins/discourse-social-profile/overview.json");
    } catch {
      // The dashboard is primarily a navigation page. Keep Settings, Platforms
      // and Statistics reachable even when the optional live overview payload
      // cannot be loaded.
      return null;
    }
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.title");
  }
}
