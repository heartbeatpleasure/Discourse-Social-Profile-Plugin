import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import SocialProfilePlatformIcon from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-icon";
import DButton from "discourse/ui-kit/d-button";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SocialProfilePlatformsList extends Component {
  @service dialog;
  @service router;

  @tracked togglingPlatformId = null;

  @action
  async move(index, delta) {
    const ids = this.args.platforms.map((platform) => platform.id);
    const target = index + delta;
    if (target < 0 || target >= ids.length) {
      return;
    }
    [ids[index], ids[target]] = [ids[target], ids[index]];
    try {
      await ajax("/admin/plugins/discourse-social-profile/platforms/reorder.json", {
        type: "POST",
        data: { ids },
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async toggleEnabled(platform) {
    if (this.togglingPlatformId) {
      return;
    }

    this.togglingPlatformId = platform.id;
    try {
      await ajax(
        `/admin/plugins/discourse-social-profile/platforms/${platform.id}.json`,
        {
          type: "PUT",
          data: { platform: { enabled: !platform.enabled } },
        }
      );
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.togglingPlatformId = null;
    }
  }

  @action
  async remove(platform) {
    if (platform.usage_count) {
      return;
    }

    const confirmed = await this.dialog.yesNoConfirm({
      message: i18n("discourse_social_profile.admin.platforms.delete_confirm", {
        label: platform.label,
      }),
    });
    if (!confirmed) {
      return;
    }

    try {
      await ajax(
        `/admin/plugins/discourse-social-profile/platforms/${platform.id}.json`,
        { type: "DELETE" }
      );
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <table class="d-table social-profile-platforms-table">
      <thead>
        <tr class="d-table__row">
          <th class="d-table__cell --icon">Icon</th>
          <th class="d-table__cell --platform">Platform</th>
          <th class="d-table__cell --key">Key</th>
          <th class="d-table__cell --input">Input</th>
          <th class="d-table__cell --status">Status</th>
          <th class="d-table__cell --users">Users</th>
          <th class="d-table__cell --toggle">
            {{i18n "discourse_social_profile.admin.platforms.quick_toggle"}}
          </th>
          <th class="d-table__cell --controls"></th>
        </tr>
      </thead>
      <tbody>
        {{#each @platforms as |platform index|}}
          <tr class="d-table__row">
            <td class="d-table__cell --icon">
              <SocialProfilePlatformIcon
                @imageUrl={{platform.resolved_icon_image_url}}
                @maskUrl={{platform.resolved_icon_mask_url}}
                @iconName={{or platform.icon_name "globe"}}
              />
            </td>
            <td class="d-table__cell --platform">
              <LinkTo
                @route="adminPlugins.show.discourse-social-profile-platforms.edit"
                @model={{platform.id}}
              >{{platform.label}}</LinkTo>
            </td>
            <td class="d-table__cell --key"><code>{{platform.key}}</code></td>
            <td class="d-table__cell --input">{{platform.input_type}}</td>
            <td class="d-table__cell --status">
              <span class={{if platform.enabled "sp-platform-status is-enabled" "sp-platform-status is-disabled"}}>
                {{if
                  platform.enabled
                  (i18n "discourse_social_profile.admin.platforms.enabled")
                  (i18n "discourse_social_profile.admin.platforms.disabled")
                }}
              </span>
            </td>
            <td class="d-table__cell --users">{{platform.usage_count}}</td>
            <td class="d-table__cell --toggle">
              <DButton
                @action={{fn this.toggleEnabled platform}}
                @icon={{if platform.enabled "eye" "eye-slash"}}
                @title={{if
                  platform.enabled
                  "discourse_social_profile.admin.platforms.disable_platform"
                  "discourse_social_profile.admin.platforms.enable_platform"
                }}
                @isLoading={{eq this.togglingPlatformId platform.id}}
                @disabled={{this.togglingPlatformId}}
                class={{if platform.enabled "btn-small btn-flat sp-platform-toggle is-enabled" "btn-small btn-flat sp-platform-toggle is-disabled"}}
              />
            </td>
            <td class="d-table__cell --controls">
              <div class="d-table__cell-actions social-profile-platform-actions">
                <DButton
                  @action={{fn this.move index -1}}
                  @icon="arrow-up"
                  @title="discourse_social_profile.admin.platforms.move_up"
                  class="btn-small btn-flat"
                />
                <DButton
                  @action={{fn this.move index 1}}
                  @icon="arrow-down"
                  @title="discourse_social_profile.admin.platforms.move_down"
                  class="btn-small btn-flat"
                />
                <DButton
                  @route="adminPlugins.show.discourse-social-profile-platforms.edit"
                  @routeModels={{array platform.id}}
                  @icon="pencil"
                  @title="discourse_social_profile.admin.platforms.edit"
                  class="btn-small btn-default"
                />
                <DButton
                  @action={{fn this.remove platform}}
                  @icon="trash-can"
                  @title={{if
                    platform.usage_count
                    "discourse_social_profile.admin.platforms.delete_in_use"
                    "discourse_social_profile.admin.platforms.delete_platform"
                  }}
                  @disabled={{platform.usage_count}}
                  class={{if platform.usage_count "btn-small btn-default sp-delete-disabled" "btn-small btn-danger"}}
                />
              </div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
