import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="social-profile-preferences" {{didInsert @controller.setupValues}}>
    <div class="social-profile-preferences__intro">
      <h2>{{i18n "discourse_social_profile.preferences.title"}}</h2>
      <p>{{i18n "discourse_social_profile.preferences.description"}}</p>
    </div>

    <div class="social-profile-preferences__list">
      {{#each @model.platforms as |platform|}}
        <div class="social-profile-preferences__row">
          <div class="social-profile-preferences__icon">
            {{#if platform.icon_image_url}}
              <img src={{platform.icon_image_url}} alt="" aria-hidden="true" referrerpolicy="no-referrer" />
            {{else if platform.icon_mask_url}}
              <img src={{platform.icon_mask_url}} alt="" aria-hidden="true" referrerpolicy="no-referrer" />
            {{else}}
              {{dIcon platform.icon_name}}
            {{/if}}
          </div>
          <div>
            <div class="social-profile-preferences__label">{{platform.label}}</div>
            {{#if platform.instructions}}
              <div class="social-profile-preferences__help">{{platform.instructions}}</div>
            {{/if}}
            <input
              type={{if
                (eq platform.input_type "email")
                "email"
                (if
                  (or
                    (eq platform.input_type "url_locked")
                    (eq platform.input_type "url_any_https")
                  )
                  "url"
                  "text"
                )
              }}
              inputmode={{if (eq platform.input_type "numeric_id") "numeric"}}
              value={{get @controller.values platform.id}}
              placeholder={{platform.placeholder}}
              autocomplete="off"
              {{on "input" (fn @controller.setValue platform.id)}}
            />
            {{#if (get @controller.errors platform.id)}}
              <div class="social-profile-preferences__error">
                {{i18n "discourse_social_profile.preferences.invalid"}}
                ({{get @controller.errors platform.id}})
              </div>
            {{else if platform.preview_href}}
              <div class="social-profile-preferences__preview">
                {{i18n "discourse_social_profile.preferences.preview"}}:
                <a href={{platform.preview_href}} target="_blank" rel="nofollow noopener noreferrer" referrerpolicy="no-referrer">{{platform.preview_href}}</a>
              </div>
            {{/if}}
          </div>
        </div>
      {{/each}}
    </div>

    <div class="social-profile-preferences__actions">
      <DButton
        @action={{@controller.save}}
        @label="discourse_social_profile.preferences.save"
        @icon="check"
        @isLoading={{@controller.saving}}
        class="btn-primary"
      />
      {{#if @controller.flash}}
        <span>{{@controller.flash}}</span>
      {{/if}}
    </div>
  </div>
</template>
