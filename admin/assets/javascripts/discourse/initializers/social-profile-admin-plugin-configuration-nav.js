import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "Discourse-Social-Profile-Plugin";

export default {
  name: "social-profile-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "address-card");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_social_profile.admin.overview.title",
          route: "adminPlugins.show.discourse-social-profile-overview",
          description: "discourse_social_profile.admin.overview.description",
        },
        {
          label: "discourse_social_profile.admin.platforms.title",
          route: "adminPlugins.show.discourse-social-profile-platforms",
          description: "discourse_social_profile.admin.platforms.description",
        },
        {
          label: "discourse_social_profile.admin.statistics.title",
          route: "adminPlugins.show.discourse-social-profile-statistics",
          description: "discourse_social_profile.admin.statistics.description",
        },
      ]);
    });
  },
};
