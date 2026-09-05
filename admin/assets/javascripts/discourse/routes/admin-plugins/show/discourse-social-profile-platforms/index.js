import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseSocialProfilePlatformsIndexRoute extends DiscourseRoute {
  async model() {
    return await ajax("/admin/plugins/discourse-social-profile/platforms.json");
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.platforms.title");
  }
}
