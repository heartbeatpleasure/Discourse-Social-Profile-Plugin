import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SocialProfilePlatformIcon from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="social-profile-preferences" {{didInsert @controller.setupValues}}>
    <div class="social-profile-preferences__hero">
      <div class="social-profile-preferences__intro">
        <h2>{{i18n "discourse_social_profile.preferences.title"}}</h2>
        <p>{{i18n "discourse_social_profile.preferences.description"}}</p>
      </div>

      <div class="social-profile-preferences__tip-card">
        <div class="social-profile-preferences__tip-icon">{{dIcon "wand-magic-sparkles"}}</div>
        <div>
          <div class="social-profile-preferences__tip-title">
            {{i18n "discourse_social_profile.preferences.tip_title"}}
          </div>
          <p>{{i18n "discourse_social_profile.preferences.tip_body"}}</p>
        </div>
      </div>
    </div>

    <div class="social-profile-preferences__grid">
      {{#each @controller.platforms as |platform|}}
        <section class="social-profile-preferences__card">
          <div class="social-profile-preferences__card-header">
            <div class="social-profile-preferences__icon-badge">
              <SocialProfilePlatformIcon
                @iconName={{platform.icon_name}}
                @imageUrl={{platform.icon_image_url}}
                @maskUrl={{platform.icon_mask_url}}
              />
            </div>

            <div class="social-profile-preferences__title-wrap">
              <div class="social-profile-preferences__label">{{platform.label}}</div>
              <div class="social-profile-preferences__help">
                {{platform.display_description}}
              </div>
            </div>

            {{#if (get @controller.values platform.id)}}
              <span class="social-profile-preferences__status-pill">
                {{i18n "discourse_social_profile.preferences.configured"}}
              </span>
            {{/if}}
          </div>

          <div class="social-profile-preferences__field-wrap">
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
              inputmode={{if (eq platform.input_type "numeric_id") "numeric"}}
              value={{get @controller.values platform.id}}
              placeholder={{platform.display_placeholder}}
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
                <span class="social-profile-preferences__preview-label">
                  {{i18n "discourse_social_profile.preferences.preview"}}
                </span>
                <a href={{platform.preview_href}} target="_blank" rel="nofollow noopener noreferrer" referrerpolicy="no-referrer">
                  {{platform.preview_href}}
                </a>
              </div>
            {{/if}}
          </div>
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
        <span class="social-profile-preferences__flash">{{@controller.flash}}</span>
      {{/if}}
    </div>
  </div>
</template>
