import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { defaultHomepage } from "discourse/lib/utilities";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesSocialProfilesRoute extends RestrictedUserRoute {
  @service siteSettings;
  @service router;
  @service currentUser;

  showFooter = true;

  async model() {
    const profileUser = this.modelFor("user");
    if (
      !this.siteSettings.discourse_social_profile_enabled ||
      profileUser?.id !== this.currentUser?.id
    ) {
      this.router.transitionTo(`discovery.${defaultHomepage()}`);
      return null;
    }
    return await ajax("/social-profile/preferences.json");
  }
}
