import RouteTemplate from "ember-route-template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);
const platformsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/platforms"
);
const statisticsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/statistics"
);

export default RouteTemplate(
  <template>
    <style>
      .sp-admin {
        --sp-surface: var(--secondary);
        --sp-border: var(--primary-low);
        --sp-muted: var(--primary-medium);
        display: flex;
        flex-direction: column;
        gap: 1rem;
        min-width: 0;
      }
      .sp-admin h1, .sp-admin h2, .sp-admin h3, .sp-admin p { margin: 0; }
      .sp-admin__hero, .sp-admin__card, .sp-admin__metric {
        border: 1px solid var(--sp-border);
        border-radius: 18px;
        background: var(--sp-surface);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      }
      .sp-admin__hero {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1rem;
        padding: 1.25rem 1.35rem;
      }
      .sp-admin__hero-copy {
        display: grid;
        min-width: 0;
        flex: 1 1 auto;
        gap: .45rem;
        max-width: 760px;
      }
      .sp-admin__hero > .btn {
        flex: 0 0 auto;
        margin-left: auto;
        white-space: nowrap;
      }
      .sp-admin__hero-copy p, .sp-admin__muted, .sp-admin__card p {
        color: var(--sp-muted);
      }
      .sp-admin__section { display: grid; gap: .7rem; }
      .sp-admin__status-row {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: .8rem;
      }
      .sp-admin__metric { min-width: 0; padding: .85rem 1rem; }
      .sp-admin__metric-label {
        color: var(--sp-muted);
        font-size: var(--font-down-1);
        font-weight: 700;
      }
      .sp-admin__metric-value {
        margin-top: .25rem;
        font-size: var(--font-up-2);
        font-weight: 700;
        overflow-wrap: anywhere;
      }
      .sp-admin__grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
        gap: 1rem;
      }
      .sp-admin__card {
        display: flex;
        min-height: 165px;
        flex-direction: column;
        gap: .8rem;
        padding: 1rem 1.1rem;
        color: var(--primary);
        text-decoration: none;
        transition: border-color .12s ease, box-shadow .12s ease, transform .12s ease;
      }
      .sp-admin__card:hover, .sp-admin__card:focus {
        border-color: var(--tertiary-medium);
        box-shadow: 0 6px 18px rgb(0 0 0 / 6%);
        color: var(--primary);
        text-decoration: none;
        transform: translateY(-1px);
      }
      .sp-admin__card.is-primary {
        border-color: var(--tertiary-low);
        background: linear-gradient(180deg, var(--secondary), var(--tertiary-very-low));
      }
      .sp-admin__badge {
        display: inline-flex;
        width: max-content;
        padding: .35rem .55rem;
        border: 1px solid var(--primary-low);
        border-radius: 999px;
        background: var(--primary-very-low);
        color: var(--primary-medium);
        font-size: var(--font-down-1);
        line-height: 1;
      }
      .sp-admin__badge.is-primary {
        border-color: var(--tertiary-low);
        background: var(--tertiary-low);
        color: var(--tertiary);
      }
      .sp-admin__action {
        margin-top: auto;
        color: var(--tertiary);
        font-weight: 600;
      }
      @media (max-width: 850px) {
        .sp-admin__status-row { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      }
      @media (max-width: 700px) {
        .sp-admin__hero { flex-direction: column; }
        .sp-admin__hero > .btn { align-self: flex-end; margin-left: 0; }
      }
      @media (max-width: 600px) {
        .sp-admin__status-row { grid-template-columns: 1fr; }
      }
    </style>

    <div class="sp-admin">
      <section class="sp-admin__hero">
        <div class="sp-admin__hero-copy">
          <h1>{{i18n "discourse_social_profile.admin.title"}}</h1>
          <p>{{i18n "discourse_social_profile.admin.dashboard.description"}}</p>
        </div>
        <a class="btn btn-primary" href={{settingsUrl}}>
          {{i18n "discourse_social_profile.admin.dashboard.open_settings"}}
        </a>
      </section>

      <section class="sp-admin__section">
        <div>
          <h2>{{i18n "discourse_social_profile.admin.dashboard.current_status"}}</h2>
          <p class="sp-admin__muted">{{i18n "discourse_social_profile.admin.dashboard.current_status_description"}}</p>
        </div>
        <div class="sp-admin__status-row">
          <div class="sp-admin__metric">
            <div class="sp-admin__metric-label">{{i18n "discourse_social_profile.admin.dashboard.status"}}</div>
            <div class="sp-admin__metric-value">
              {{if @model.enabled (i18n "discourse_social_profile.admin.dashboard.enabled") (i18n "discourse_social_profile.admin.dashboard.disabled")}}
            </div>
          </div>
          <div class="sp-admin__metric">
            <div class="sp-admin__metric-label">{{i18n "discourse_social_profile.admin.dashboard.platforms"}}</div>
            <div class="sp-admin__metric-value">{{@model.platform_count}}</div>
          </div>
          <div class="sp-admin__metric">
            <div class="sp-admin__metric-label">{{i18n "discourse_social_profile.admin.dashboard.enabled_platforms"}}</div>
            <div class="sp-admin__metric-value">{{@model.enabled_platform_count}}</div>
          </div>
          <div class="sp-admin__metric">
            <div class="sp-admin__metric-label">{{i18n "discourse_social_profile.admin.dashboard.social_links"}}</div>
            <div class="sp-admin__metric-value">{{@model.total_links}}</div>
          </div>
        </div>
      </section>

      <section class="sp-admin__section">
        <div>
          <h2>{{i18n "discourse_social_profile.admin.dashboard.overview_title"}}</h2>
          <p class="sp-admin__muted">{{i18n "discourse_social_profile.admin.dashboard.overview_description"}}</p>
        </div>
        <div class="sp-admin__grid">
          <a class="sp-admin__card is-primary" href={{settingsUrl}}>
            <span class="sp-admin__badge is-primary">{{i18n "discourse_social_profile.admin.dashboard.category_configuration"}}</span>
            <h3>{{i18n "discourse_social_profile.admin.dashboard.open_settings"}}</h3>
            <p>{{i18n "discourse_social_profile.admin.dashboard.settings_description"}}</p>
            <span class="sp-admin__action">{{i18n "discourse_social_profile.admin.dashboard.open_tool"}}</span>
          </a>
          <a class="sp-admin__card" href={{platformsUrl}}>
            <span class="sp-admin__badge">{{i18n "discourse_social_profile.admin.dashboard.category_management"}}</span>
            <h3>{{i18n "discourse_social_profile.admin.platforms.title"}}</h3>
            <p>{{i18n "discourse_social_profile.admin.platforms.description"}}</p>
            <span class="sp-admin__action">{{i18n "discourse_social_profile.admin.dashboard.open_tool"}}</span>
          </a>
          <a class="sp-admin__card" href={{statisticsUrl}}>
            <span class="sp-admin__badge">{{i18n "discourse_social_profile.admin.dashboard.category_reporting"}}</span>
            <h3>{{i18n "discourse_social_profile.admin.statistics.title"}}</h3>
            <p>{{i18n "discourse_social_profile.admin.statistics.description"}}</p>
            <span class="sp-admin__action">{{i18n "discourse_social_profile.admin.dashboard.open_tool"}}</span>
          </a>
        </div>
      </section>
    </div>
  </template>
);
