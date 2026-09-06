import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class PreferencesSocialProfilesController extends Controller {
  @tracked saving = false;
  @tracked platforms = [];
  @tracked values = {};
  @tracked errors = {};
  @tracked flash = null;

  setPlatforms(platforms) {
    this.platforms = Array.isArray(platforms) ? platforms : [];
    this.values = Object.fromEntries(
      this.platforms.map((platform) => [platform.id, platform.value || ""])
    );
    this.errors = Object.fromEntries(
      this.platforms
        .filter((platform) => platform.error_code)
        .map((platform) => [platform.id, platform.error_code])
    );
  }

  @action
  setupValues() {
    this.setPlatforms(this.model?.platforms);
  }

  @action
  setValue(platformId, event) {
    this.flash = null;
    this.values = { ...this.values, [platformId]: event.target.value };
    const nextErrors = { ...this.errors };
    delete nextErrors[platformId];
    this.errors = nextErrors;
  }

  @action
  async save() {
    this.saving = true;
    try {
      const response = await ajax("/social-profile/preferences.json", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          links: this.platforms.map((platform) => ({
            platform_id: platform.id,
            value: this.values[platform.id] || "",
          })),
        }),
      });

      // Keep the route's model object untouched. Preferences controllers are
      // cached by Ember, and replacing `model` after a save can leak stale
      // route state into later preference transitions. Only the plugin-owned
      // tracked state is refreshed from the response.
      this.setPlatforms(response?.platforms);
      this.flash = i18n("discourse_social_profile.preferences.saved");
    } catch (error) {
      const responseErrors = error?.jqXHR?.responseJSON?.errors;
      if (responseErrors && !Array.isArray(responseErrors)) {
        this.errors = responseErrors;
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.saving = false;
    }
  }
}
