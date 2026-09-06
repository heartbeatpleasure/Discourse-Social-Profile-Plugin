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
    this.platforms = (Array.isArray(platforms) ? platforms : []).map((platform) => ({
      ...platform,
      display_description: this.descriptionFor(platform),
      display_placeholder: this.placeholderFor(platform),
    }));
    this.values = Object.fromEntries(
      this.platforms.map((platform) => [platform.id, platform.value || ""])
    );
    this.errors = Object.fromEntries(
      this.platforms
        .filter((platform) => platform.error_code)
        .map((platform) => [platform.id, platform.error_code])
    );
  }

  descriptionFor(platform) {
    const label = platform?.label || i18n("discourse_social_profile.preferences.profile_link");

    switch (platform?.input_type) {
      case "email":
        return i18n("discourse_social_profile.preferences.card_help_email");
      case "numeric_id":
        return i18n(
          "discourse_social_profile.preferences.card_help_numeric_id",
          { label }
        );
      case "url_locked":
        return i18n(
          "discourse_social_profile.preferences.card_help_url_locked",
          { label }
        );
      case "url_any_https":
        return i18n(
          "discourse_social_profile.preferences.card_help_url_any_https",
          { label }
        );
      default:
        return i18n(
          "discourse_social_profile.preferences.card_help_handle",
          { label }
        );
    }
  }

  placeholderFor(platform) {
    switch (platform?.input_type) {
      case "email":
        return i18n("discourse_social_profile.preferences.placeholder_email");
      case "numeric_id":
        return i18n("discourse_social_profile.preferences.placeholder_numeric_id");
      case "url_locked":
      case "url_any_https":
        return i18n("discourse_social_profile.preferences.placeholder_profile_link");
      default:
        return i18n("discourse_social_profile.preferences.placeholder_handle_or_link");
    }
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
