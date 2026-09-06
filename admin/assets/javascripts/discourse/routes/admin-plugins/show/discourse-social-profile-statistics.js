import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseSocialProfileStatisticsRoute extends DiscourseRoute {
  queryParams = {
    refresh: { refreshModel: true },
  };

  async model(params) {
    const suffix = params?.refresh ? "?refresh=true" : "";
    return await ajax(
      `/admin/plugins/discourse-social-profile/statistics.json${suffix}`
    );
  }

  titleToken() {
    return i18n("discourse_social_profile.admin.statistics.title");
  }
}
