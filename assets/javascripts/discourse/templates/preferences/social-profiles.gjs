import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq, or } from "discourse/truth-helpers";
import SocialProfilePlatformIcon from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-icon";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="social-profile-preferences" {{didInsert @controller.setupValues}}>
    <div class="social-profile-preferences__intro">
      <h2>{{i18n "discourse_social_profile.preferences.title"}}</h2>
      <p>{{i18n "discourse_social_profile.preferences.description"}}</p>
    </div>

    <div class="social-profile-preferences__list">
      {{#each @model.platforms as |platform|}}
        <section class="social-profile-preferences__card">
          <div class="social-profile-preferences__card-header">
            <div class="social-profile-preferences__icon-frame">
              <SocialProfilePlatformIcon
                @imageUrl={{platform.icon_image_url}}
                @maskUrl={{platform.icon_mask_url}}
                @iconName={{platform.icon_name}}
              />
            </div>

            <div class="social-profile-preferences__heading">
              <div class="social-profile-preferences__label">{{platform.label}}</div>
              {{#if platform.instructions}}
                <div class="social-profile-preferences__help">{{platform.instructions}}</div>
              {{/if}}
            </div>
          </div>

          <input
            class="social-profile-preferences__input"
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
            value={{get @controller.values platform.id}}
            placeholder={{platform.placeholder}}
            aria-label={{platform.label}}
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
              <a
                href={{platform.preview_href}}
                target="_blank"
                rel="nofollow noopener noreferrer"
                referrerpolicy="no-referrer"
              >{{platform.preview_href}}</a>
            </div>
          {{/if}}
        </section>
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
        <span class="social-profile-preferences__saved">{{@controller.flash}}</span>
      {{/if}}
    </div>
  </div>
</template>
