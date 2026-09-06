import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SocialProfilePlatformEditor extends Component {
  @service router;
  @service toasts;

  @tracked formData = { ...(this.args.model?.platform || {}) };
  @tracked iconImageUploadId = this.args.model?.platform?.icon_image_upload_id || null;
  @tracked iconMaskUploadId = this.args.model?.platform?.icon_mask_upload_id || null;
  // UppyImageUploader renders previews with CSS background-image, which cannot
  // attach an element-level Referrer-Policy. Only feed it native Discourse uploads;
  // administrator-configured external URLs are shown safely in the platform list
  // after save, where the shared icon component uses referrerpolicy="no-referrer".
  @tracked iconImagePreview = this.args.model?.platform?.icon_image_upload_id
    ? this.args.model?.platform?.resolved_icon_image_url || null
    : null;
  @tracked iconMaskPreview = this.args.model?.platform?.icon_mask_upload_id
    ? this.args.model?.platform?.resolved_icon_mask_url || null
    : null;
  @tracked testValue = "";
  @tracked testResult = null;
  @tracked testing = false;

  get isNew() {
    return !this.args.model?.platform?.id;
  }

  get formattedTestResult() {
    return this.testResult ? JSON.stringify(this.testResult, null, 2) : "";
  }

  @action
  imageUploaded(upload) {
    this.iconImageUploadId = upload.id;
    this.iconImagePreview = getURL(upload.url);
  }

  @action
  imageDeleted() {
    this.iconImageUploadId = null;
    this.iconImagePreview = null;
  }

  @action
  maskUploaded(upload) {
    this.iconMaskUploadId = upload.id;
    this.iconMaskPreview = getURL(upload.url);
  }

  @action
  maskDeleted() {
    this.iconMaskUploadId = null;
    this.iconMaskPreview = null;
  }

  cleanPayload(data) {
    const allowed = [
      "key", "enabled", "label", "user_instructions", "placeholder", "input_type",
      "base_url", "allowed_hosts", "path_regex", "icon_name", "builtin_icon",
      "icon_image_url", "icon_mask_url", "badge_background", "badge_background_dark",
      "badge_radius", "color", "color_dark", "legacy_user_field_name"
    ];
    const payload = Object.fromEntries(allowed.map((key) => [key, data[key] ?? ""]));
    payload.icon_image_upload_id = this.iconImageUploadId;
    payload.icon_mask_upload_id = this.iconMaskUploadId;
    return payload;
  }

  @action
  async save(data) {
    try {
      const payload = this.cleanPayload(data);
      const id = this.args.model?.platform?.id;
      const result = await ajax(
        id
          ? `/admin/plugins/discourse-social-profile/platforms/${id}.json`
          : "/admin/plugins/discourse-social-profile/platforms.json",
        {
          type: id ? "PUT" : "POST",
          data: { platform: payload },
        }
      );
      this.toasts.success({ data: { message: i18n("discourse_social_profile.admin.platforms.saved") } });
      if (id) {
        this.router.refresh();
      } else {
        this.router.transitionTo(
          "adminPlugins.show.discourse-social-profile-platforms.edit",
          result.platform.id
        );
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateTestValue(event) {
    this.testValue = event.target.value;
  }

  @action
  async test(data) {
    const id = this.args.model?.platform?.id;
    if (!id) {
      return;
    }
    this.testing = true;
    try {
      this.testResult = await ajax(
        `/admin/plugins/discourse-social-profile/platforms/${id}/test.json`,
        {
          type: "POST",
          data: { social_profile_test_value: this.testValue, platform: this.cleanPayload(data) },
        }
      );
    } catch (error) {
      this.testResult = error?.jqXHR?.responseJSON || { accepted: false, error_code: "request_failed" };
    } finally {
      this.testing = false;
    }
  }

  <template>
    <style>
      .sp-platform-editor {
        --sp-editor-border: var(--primary-low);
        --sp-editor-muted: var(--primary-medium);
        width: 100%;
        min-width: 0;
      }
      .sp-platform-editor .form-kit {
        width: 100%;
        align-items: stretch;
        --form-kit-medium-input: 100%;
        --form-kit-large-input: 100%;
        --form-kit-max-input: 100%;
      }
      .sp-platform-editor__grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 1rem;
        width: 100%;
      }
      .sp-platform-editor__card {
        min-width: 0;
        padding: 1rem 1.1rem;
        border: 1px solid var(--sp-editor-border);
        border-radius: 16px;
        background: var(--secondary);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      }
      .sp-platform-editor__card.is-wide {
        grid-column: 1 / -1;
      }
      .sp-platform-editor .form-kit__section,
      .sp-platform-editor .form-kit__field,
      .sp-platform-editor .form-kit__container,
      .sp-platform-editor .form-kit__container-content {
        width: 100%;
        max-width: 100%;
        box-sizing: border-box;
      }
      .sp-platform-editor input:not([type="checkbox"]):not([type="radio"]),
      .sp-platform-editor textarea,
      .sp-platform-editor select {
        width: 100%;
        max-width: 100%;
        box-sizing: border-box;
      }
      .sp-platform-editor textarea {
        min-height: 7rem;
      }
      .sp-platform-editor .control-group {
        margin-bottom: 1rem;
      }
      .sp-platform-editor__test-row {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        gap: .65rem;
        align-items: end;
      }
      .sp-platform-editor__test-row .btn {
        min-height: 2.5rem;
        margin: 0;
      }
      .sp-platform-editor pre {
        max-height: 20rem;
        overflow: auto;
        margin: .75rem 0 0;
        padding: .8rem;
        border-radius: 10px;
        background: var(--primary-very-low);
      }
      .sp-platform-editor .form-kit__actions {
        margin-top: 1rem;
      }
      @media (max-width: 920px) {
        .sp-platform-editor__grid { grid-template-columns: 1fr; }
        .sp-platform-editor__card.is-wide { grid-column: auto; }
      }
      @media (max-width: 560px) {
        .sp-platform-editor__card { padding: .85rem; }
        .sp-platform-editor__test-row { grid-template-columns: 1fr; }
        .sp-platform-editor__test-row .btn { width: 100%; }
      }
    </style>

    <div class="sp-platform-editor">
      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form transientData|>
        <div class="sp-platform-editor__grid">
          <div class="sp-platform-editor__card">
            <form.Section @title="General">
              <form.Field @name="enabled" @title="Enabled" @type="toggle" as |field|><field.Control /></form.Field>
              <form.Field @name="key" @title="Stable key" @description="Lowercase internal identifier. It becomes immutable after user data exists." @type="input" @validation="required" as |field|><field.Control /></form.Field>
              <form.Field @name="label" @title="Label" @type="input" @validation="required" as |field|><field.Control /></form.Field>
              <form.Field @name="user_instructions" @title="User instructions" @type="textarea" as |field|><field.Control /></form.Field>
              <form.Field @name="placeholder" @title="Placeholder" @type="input" as |field|><field.Control /></form.Field>
            </form.Section>
          </div>

          <div class="sp-platform-editor__card">
            <form.Section @title="Input and validation">
              <form.Field @name="input_type" @title="Input type" @type="select" as |field|>
                <field.Control as |select|>
                  <select.Option @value="handle">handle</select.Option>
                  <select.Option @value="numeric_id">numeric_id</select.Option>
                  <select.Option @value="email">email</select.Option>
                  <select.Option @value="url_locked">url_locked</select.Option>
                  <select.Option @value="url_any_https">url_any_https</select.Option>
                </field.Control>
              </form.Field>
              <form.Field @name="base_url" @title="Base URL" @description="HTTPS base URL for handle/numeric_id values." @type="input-url" as |field|><field.Control /></form.Field>
              <form.Field @name="allowed_hosts" @title="Allowed hosts" @description="Comma or whitespace-separated exact hosts. Prefix an entry with a dot to allow subdomains." @type="textarea" as |field|><field.Control /></form.Field>
              <form.Field @name="path_regex" @title="Path regex" @description="Optional regular expression applied to the URL pathname." @type="input" as |field|><field.Control /></form.Field>
            </form.Section>
          </div>

          <div class="sp-platform-editor__card">
            <form.Section @title="Icons">
              <form.Field
                @name="icon_name"
                @title="Discourse / FontAwesome icon"
                @description="Saved icon names are automatically added to the plugin SVG preload setting for Discourse 2026.7 stable compatibility."
                @type="input"
                as |field|
              ><field.Control /></form.Field>
              <form.Field @name="builtin_icon" @title="Bundled monochrome icon" @type="select" as |field|>
                <field.Control as |select|>
                  <select.Option @value="">None</select.Option>
                  {{#each @model.bundled_icons as |name|}}<select.Option @value={{name}}>{{name}}</select.Option>{{/each}}
                </field.Control>
              </form.Field>
              <div class="control-group">
                <label class="control-label">Full-color icon upload (PNG/JPG/SVG/WebP)</label>
                <UppyImageUploader
                  @imageUrl={{this.iconImagePreview}}
                  @onUploadDone={{this.imageUploaded}}
                  @onUploadDeleted={{this.imageDeleted}}
                  @type="group_flair"
                  @id="social-profile-image-uploader"
                />
              </div>
              <form.Field @name="icon_image_url" @title="External full-color icon URL" @description="Optional HTTPS compatibility URL. Native upload is preferred. External URLs are not fetched in this editor preview for privacy." @type="input-url" as |field|><field.Control /></form.Field>
              <div class="control-group">
                <label class="control-label">Monochrome mask upload (SVG)</label>
                <UppyImageUploader
                  @imageUrl={{this.iconMaskPreview}}
                  @onUploadDone={{this.maskUploaded}}
                  @onUploadDeleted={{this.maskDeleted}}
                  @type="group_flair"
                  @id="social-profile-mask-uploader"
                />
              </div>
              <form.Field @name="icon_mask_url" @title="External monochrome mask URL" @description="Optional HTTPS compatibility URL. For privacy, external masks render as no-referrer images and are not fetched in this editor preview; native uploads are preferred." @type="input-url" as |field|><field.Control /></form.Field>
            </form.Section>
          </div>

          <div class="sp-platform-editor__card">
            <form.Section @title="Colors and presentation">
              <form.Field @name="color" @title="Icon color (light)" @type="input" as |field|><field.Control /></form.Field>
              <form.Field @name="color_dark" @title="Icon color (dark)" @type="input" as |field|><field.Control /></form.Field>
              <form.Field @name="badge_background" @title="Badge background (light)" @type="input" as |field|><field.Control /></form.Field>
              <form.Field @name="badge_background_dark" @title="Badge background (dark)" @type="input" as |field|><field.Control /></form.Field>
              <form.Field @name="badge_radius" @title="Badge radius" @description="A plain number is rendered as pixels." @type="input" as |field|><field.Control /></form.Field>
            </form.Section>
          </div>

          <div class="sp-platform-editor__card is-wide">
            <form.Section @title="Future migration metadata">
              <form.Field @name="legacy_user_field_name" @title="Legacy Custom User Field name" @description="Metadata only. This release does not import or read Custom User Field values at runtime." @type="input" as |field|><field.Control /></form.Field>
            </form.Section>
          </div>

          {{#unless this.isNew}}
            <div class="sp-platform-editor__card is-wide">
              <form.Section @title={{i18n "discourse_social_profile.admin.platforms.test_value"}}>
                <div class="sp-platform-editor__test-row">
                  <input type="text" value={{this.testValue}} {{on "input" this.updateTestValue}} placeholder="Example profile value" />
                  <DButton @action={{fn this.test transientData}} @label="discourse_social_profile.admin.platforms.test_value" @icon="flask" @isLoading={{this.testing}} class="btn-default" />
                </div>
                {{#if this.testResult}}<pre>{{this.formattedTestResult}}</pre>{{/if}}
              </form.Section>
            </div>
          {{/unless}}
        </div>

        <form.Actions><form.Submit /></form.Actions>
      </Form>
    </div>
  </template>
}
