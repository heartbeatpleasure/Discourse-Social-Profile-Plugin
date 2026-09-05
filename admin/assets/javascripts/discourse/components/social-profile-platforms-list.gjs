import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SocialProfilePlatformsList extends Component {
  @service dialog;
  @service router;

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
  async remove(platform) {
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
          <th class="d-table__cell">#</th><th class="d-table__cell">Icon</th>
          <th class="d-table__cell">Platform</th><th class="d-table__cell">Key</th>
          <th class="d-table__cell">Input</th><th class="d-table__cell">Status</th>
          <th class="d-table__cell">Users</th><th class="d-table__cell"></th>
        </tr>
      </thead>
      <tbody>
        {{#each @platforms as |platform index|}}
          <tr class="d-table__row">
            <td class="d-table__cell">{{platform.position}}</td>
            <td class="d-table__cell">
              {{#if platform.resolved_icon_image_url}}
                <img src={{platform.resolved_icon_image_url}} alt="" width="20" height="20" referrerpolicy="no-referrer" />
              {{else if platform.resolved_icon_mask_url}}
                <span title="Custom mask">{{dIcon "image"}}</span>
              {{else}}
                {{dIcon (or platform.icon_name "globe")}}
              {{/if}}
            </td>
            <td class="d-table__cell">
              <LinkTo @route="adminPlugins.show.discourse-social-profile-platforms.edit" @model={{platform.id}}>{{platform.label}}</LinkTo>
            </td>
            <td class="d-table__cell"><code>{{platform.key}}</code></td>
            <td class="d-table__cell">{{platform.input_type}}</td>
            <td class="d-table__cell">
              {{if platform.enabled (i18n "discourse_social_profile.admin.platforms.enabled") (i18n "discourse_social_profile.admin.platforms.disabled")}}
            </td>
            <td class="d-table__cell">{{platform.usage_count}}</td>
            <td class="d-table__cell --controls">
              <div class="d-table__cell-actions">
                <DButton @action={{fn this.move index -1}} @icon="arrow-up" @title="discourse_social_profile.admin.platforms.move_up" class="btn-small btn-flat" />
                <DButton @action={{fn this.move index 1}} @icon="arrow-down" @title="discourse_social_profile.admin.platforms.move_down" class="btn-small btn-flat" />
                <DButton @route="adminPlugins.show.discourse-social-profile-platforms.edit" @routeModels={{array platform.id}} @icon="pencil" class="btn-small btn-default" />
                {{#unless platform.usage_count}}
                  <DButton @action={{fn this.remove platform}} @icon="trash-can" class="btn-small btn-danger" />
                {{/unless}}
              </div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
