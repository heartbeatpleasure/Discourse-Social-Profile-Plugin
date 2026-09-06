import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import SocialProfilePlatformIcon from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <style>
    /* Discourse intentionally keeps normal preference forms narrow. This page
       is a card-based profile picker, so widen only the form that contains it. */
    .user-preferences .form-vertical:has(.sp-prefs) {
      width: 100%;
      max-width: none;
    }

    .sp-prefs {
      --sp-prefs-border: var(--primary-low);
      --sp-prefs-muted: var(--primary-medium);
      --sp-prefs-surface: var(--secondary);
      --sp-prefs-alt: var(--primary-very-low);
      display: grid;
      gap: 1rem;
      width: 100%;
      max-width: none;
      min-width: 0;
      margin: 0;
    }

    .sp-prefs h2,
    .sp-prefs p {
      margin: 0;
    }

    .sp-prefs__hero {
      width: 100%;
      box-sizing: border-box;
      padding: 1.25rem 1.35rem;
      border: 1px solid var(--sp-prefs-border);
      border-radius: 18px;
      background: linear-gradient(180deg, var(--sp-prefs-surface), var(--sp-prefs-alt));
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }

    .sp-prefs__hero-copy {
      display: grid;
      gap: .45rem;
      width: 100%;
      min-width: 0;
    }

    .sp-prefs__hero-copy h2 {
      font-size: clamp(1.7rem, 1.3rem + 1.15vw, 2.3rem);
      line-height: 1.1;
    }

    .sp-prefs__hero-copy p {
      max-width: 62rem;
      color: var(--sp-prefs-muted);
      font-size: var(--font-up-1);
      line-height: 1.5;
    }

    .sp-prefs__grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1rem;
      width: 100%;
      min-width: 0;
    }

    .sp-prefs__card {
      display: grid;
      grid-template-rows: auto auto;
      align-content: start;
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
      position: relative;
      display: grid;
      grid-template-columns: 3rem minmax(0, 1fr);
      gap: .9rem;
      align-items: start;
      height: 6.1rem;
      min-width: 0;
      padding-right: 6.9rem;
      box-sizing: border-box;
    }

    .sp-prefs__icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 3rem;
      height: 3rem;
      border-radius: 14px;
      background: var(--sp-prefs-alt);
      color: var(--tertiary);
    }

    .sp-prefs__icon .social-profile-platform-icon,
    .sp-prefs__icon .social-profile-platform-icon__image,
    .sp-prefs__icon .social-profile-platform-icon__mask,
    .sp-prefs__icon .svg-icon {
      display: block;
      width: 1.45rem !important;
      height: 1.45rem !important;
    }

    .sp-prefs__text {
      min-width: 0;
    }

    .sp-prefs__name {
      display: -webkit-box;
      overflow: hidden;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
      font-size: var(--font-up-1);
      font-weight: 700;
      line-height: 1.25;
    }

    .sp-prefs__help {
      display: -webkit-box;
      overflow: hidden;
      margin-top: .25rem;
      color: var(--sp-prefs-muted);
      font-size: var(--font-down-1);
      line-height: 1.4;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 3;
    }

    .sp-prefs__configured,
    .sp-prefs__unavailable {
      position: absolute;
      top: 0;
      right: 0;
      display: inline-flex;
      align-items: center;
      padding: .28rem .58rem;
      border-radius: 999px;
      font-size: var(--font-down-1);
      font-weight: 700;
      white-space: nowrap;
    }

    .sp-prefs__configured {
      background: var(--success-low);
      color: var(--success);
    }

    .sp-prefs__unavailable {
      background: var(--primary-very-low);
      color: var(--primary-medium);
    }

    .sp-prefs__field {
      display: grid;
      align-content: start;
      gap: .45rem;
      min-width: 0;
    }

    .sp-prefs__input {
      display: block;
      align-self: start;
      box-sizing: border-box;
      width: 100% !important;
      height: 3rem !important;
      min-height: 3rem !important;
      max-height: 3rem !important;
      margin: 0 !important;
      padding: .65rem .75rem;
    }

    .sp-prefs__disabled-actions {
      display: flex;
      align-items: center;
      gap: .5rem;
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

    .sp-prefs__preview strong {
      color: var(--primary);
    }

    .sp-prefs__preview a {
      overflow-wrap: anywhere;
    }

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

    @media (max-width: 820px) {
      .sp-prefs__grid {
        grid-template-columns: 1fr;
      }

      .sp-prefs__card-header {
        height: auto;
        min-height: 5.5rem;
      }
    }

    @media (max-width: 520px) {
      .sp-prefs__hero,
      .sp-prefs__card {
        padding: .9rem;
        border-radius: 14px;
      }

      .sp-prefs__hero-copy p {
        font-size: var(--font-0);
      }

      .sp-prefs__card-header {
        grid-template-columns: 2.7rem minmax(0, 1fr);
        min-height: 0;
        height: auto;
        padding-right: 0;
      }

      .sp-prefs__icon {
        width: 2.7rem;
        height: 2.7rem;
      }

      .sp-prefs__configured,
      .sp-prefs__unavailable {
        position: static;
        grid-column: 2;
        justify-self: start;
        margin-top: .35rem;
      }

      .sp-prefs__name,
      .sp-prefs__help {
        display: block;
        overflow: visible;
      }
    }
  </style>

  <div class="sp-prefs" {{didInsert @controller.setupValues}}>
    <section class="sp-prefs__hero">
      <div class="sp-prefs__hero-copy">
        <h2>{{i18n "discourse_social_profile.preferences.title"}}</h2>
        <p>{{i18n "discourse_social_profile.preferences.description"}}</p>
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

            <div class="sp-prefs__text">
              <div class="sp-prefs__name">{{platform.label}}</div>
              <div class="sp-prefs__help">{{platform.display_description}}</div>
            </div>

            {{#if platform.enabled}}
              {{#if (get @controller.values platform.id)}}
                <span class="sp-prefs__configured">
                  {{i18n "discourse_social_profile.preferences.configured"}}
                </span>
              {{/if}}
            {{else}}
              <span class="sp-prefs__unavailable">
                {{i18n "discourse_social_profile.preferences.unavailable"}}
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
              readonly={{if platform.enabled null true}}
              {{on "input" (fn @controller.setValue platform.id)}}
            />

            {{#unless platform.enabled}}
              <div class="sp-prefs__disabled-actions">
                <DButton
                  @action={{fn @controller.clearValue platform.id}}
                  @label="discourse_social_profile.preferences.remove"
                  @icon="trash-can"
                  class="btn-default"
                />
              </div>
            {{/unless}}

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
