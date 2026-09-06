import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SocialProfilePlatformIcon from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <style>
    .sp-prefs {
      --sp-prefs-border: var(--primary-low);
      --sp-prefs-muted: var(--primary-medium);
      --sp-prefs-surface: var(--secondary);
      --sp-prefs-alt: var(--primary-very-low);
      display: grid;
      gap: 1rem;
      width: 100%;
      max-width: 1120px;
      min-width: 0;
      margin: 0 auto;
    }
    .sp-prefs h2, .sp-prefs h3, .sp-prefs p { margin: 0; }
    .sp-prefs__hero {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1.25rem;
      padding: 1.2rem 1.3rem;
      border: 1px solid var(--sp-prefs-border);
      border-radius: 18px;
      background: linear-gradient(180deg, var(--sp-prefs-surface), var(--sp-prefs-alt));
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }
    .sp-prefs__hero-copy {
      display: grid;
      gap: .4rem;
      min-width: 0;
      max-width: 50rem;
    }
    .sp-prefs__hero-copy h2 {
      font-size: clamp(1.65rem, 1.25rem + 1.25vw, 2.25rem);
      line-height: 1.1;
    }
    .sp-prefs__hero-copy p {
      color: var(--sp-prefs-muted);
      line-height: 1.5;
    }
    .sp-prefs__tip {
      display: inline-flex;
      flex: 0 0 auto;
      align-items: center;
      gap: .45rem;
      max-width: 23rem;
      padding: .65rem .8rem;
      border: 1px solid var(--tertiary-low);
      border-radius: 12px;
      background: var(--tertiary-very-low);
      color: var(--primary);
      font-size: var(--font-down-1);
      line-height: 1.35;
    }
    .sp-prefs__tip .svg-icon {
      flex: 0 0 auto;
      color: var(--tertiary);
    }
    .sp-prefs__grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1rem;
    }
    .sp-prefs__card {
      display: grid;
      gap: .9rem;
      min-width: 0;
      padding: 1rem 1.05rem 1.05rem;
      border: 1px solid var(--sp-prefs-border);
      border-radius: 16px;
      background: var(--sp-prefs-surface);
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      transition: border-color .12s ease, box-shadow .12s ease, transform .12s ease;
    }
    .sp-prefs__card:hover,
    .sp-prefs__card:focus-within {
      border-color: var(--tertiary-low);
      box-shadow: 0 6px 18px rgb(0 0 0 / 6%);
      transform: translateY(-1px);
    }
    .sp-prefs__card-header {
      display: grid;
      grid-template-columns: auto minmax(0, 1fr) auto;
      gap: .8rem;
      align-items: center;
    }
    .sp-prefs__icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 2.8rem;
      height: 2.8rem;
      border-radius: 13px;
      background: var(--sp-prefs-alt);
      color: var(--tertiary);
    }
    .sp-prefs__icon .social-profile-platform-icon,
    .sp-prefs__icon .social-profile-platform-icon__image,
    .sp-prefs__icon .social-profile-platform-icon__mask,
    .sp-prefs__icon .svg-icon {
      display: block;
      width: 1.35rem !important;
      height: 1.35rem !important;
    }
    .sp-prefs__name {
      font-size: var(--font-up-1);
      font-weight: 700;
      line-height: 1.2;
    }
    .sp-prefs__help {
      margin-top: .18rem;
      color: var(--sp-prefs-muted);
      font-size: var(--font-down-1);
      line-height: 1.4;
    }
    .sp-prefs__configured {
      display: inline-flex;
      align-items: center;
      align-self: start;
      padding: .28rem .58rem;
      border-radius: 999px;
      background: var(--success-low);
      color: var(--success);
      font-size: var(--font-down-1);
      font-weight: 700;
      white-space: nowrap;
    }
    .sp-prefs__field {
      display: grid;
      gap: .4rem;
    }
    .sp-prefs__input {
      box-sizing: border-box;
      width: 100%;
      min-height: 2.8rem;
      margin: 0;
    }
    .sp-prefs__error {
      color: var(--danger);
      font-size: var(--font-down-1);
      line-height: 1.35;
    }
    .sp-prefs__preview {
      display: grid;
      gap: .18rem;
      min-width: 0;
      color: var(--sp-prefs-muted);
      font-size: var(--font-down-1);
      line-height: 1.35;
    }
    .sp-prefs__preview strong { color: var(--primary); }
    .sp-prefs__preview a { overflow-wrap: anywhere; }
    .sp-prefs__actions {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: .75rem;
      padding-top: .25rem;
    }
    .sp-prefs__flash {
      color: var(--success);
      font-weight: 600;
    }
    @media (max-width: 900px) {
      .sp-prefs__hero { flex-direction: column; }
      .sp-prefs__tip { max-width: none; }
    }
    @media (max-width: 720px) {
      .sp-prefs__grid { grid-template-columns: 1fr; }
    }
    @media (max-width: 480px) {
      .sp-prefs__hero, .sp-prefs__card { padding: .9rem; }
      .sp-prefs__card-header { grid-template-columns: auto minmax(0, 1fr); align-items: start; }
      .sp-prefs__configured { grid-column: 2; justify-self: start; }
    }
  </style>

  <div class="sp-prefs" {{didInsert @controller.setupValues}}>
    <section class="sp-prefs__hero">
      <div class="sp-prefs__hero-copy">
        <h2>{{i18n "discourse_social_profile.preferences.title"}}</h2>
        <p>{{i18n "discourse_social_profile.preferences.description"}}</p>
      </div>
      <div class="sp-prefs__tip">
        {{dIcon "link"}}
        <span>{{i18n "discourse_social_profile.preferences.tip_body"}}</span>
      </div>
    </section>

    <div class="sp-prefs__grid">
      {{#each @controller.platforms as |platform|}}
        <section class="sp-prefs__card">
          <div class="sp-prefs__card-header">
            <div class="sp-prefs__icon">
              <SocialProfilePlatformIcon
                @iconName={{platform.icon_name}}
                @imageUrl={{platform.icon_image_url}}
                @maskUrl={{platform.icon_mask_url}}
              />
            </div>

            <div>
              <div class="sp-prefs__name">{{platform.label}}</div>
              <div class="sp-prefs__help">{{platform.display_description}}</div>
            </div>

            {{#if (get @controller.values platform.id)}}
              <span class="sp-prefs__configured">
                {{i18n "discourse_social_profile.preferences.configured"}}
              </span>
            {{/if}}
          </div>

          <div class="sp-prefs__field">
            <input
              class="sp-prefs__input"
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
              <div class="sp-prefs__error">
                {{i18n "discourse_social_profile.preferences.invalid"}}
                ({{get @controller.errors platform.id}})
              </div>
            {{else if platform.preview_href}}
              <div class="sp-prefs__preview">
                <strong>{{i18n "discourse_social_profile.preferences.preview"}}</strong>
                <a href={{platform.preview_href}} target="_blank" rel="nofollow noopener noreferrer" referrerpolicy="no-referrer">
                  {{platform.preview_href}}
                </a>
              </div>
            {{/if}}
          </div>
        </section>
      {{/each}}
    </div>

    <div class="sp-prefs__actions">
      <DButton
        @action={{@controller.save}}
        @label="discourse_social_profile.preferences.save"
        @icon="check"
        @isLoading={{@controller.saving}}
        class="btn-primary"
      />
      {{#if @controller.flash}}
        <span class="sp-prefs__flash">{{@controller.flash}}</span>
      {{/if}}
    </div>
  </div>
</template>
