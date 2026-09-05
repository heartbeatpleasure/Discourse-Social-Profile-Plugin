import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseSocialProfileStatisticsRoute extends DiscourseRoute {
  @service router;

  async model() {
    return await ajax("/admin/plugins/discourse-social-profile/statistics.json");
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.statistics.title");
  }
}
