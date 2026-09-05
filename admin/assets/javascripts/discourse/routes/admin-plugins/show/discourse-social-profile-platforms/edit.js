import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseSocialProfilePlatformsEditRoute extends DiscourseRoute {
  @service router;

  async model(params) {
    try {
      return await ajax(`/admin/plugins/discourse-social-profile/platforms/${params.id}.json`);
    } catch {
      this.router.replaceWith("adminPlugins.show.discourse-social-profile-platforms");
      return null;
    }
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.platforms.edit");
  }
}
