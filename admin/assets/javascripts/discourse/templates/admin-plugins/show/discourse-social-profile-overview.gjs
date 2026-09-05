import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const settingsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/settings"
);
const platformsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/platforms"
);
const statisticsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/statistics"
);

export default <template>
  <style>
    .social-profile-admin-dashboard {
      --sp-admin-surface: var(--secondary);
      --sp-admin-border: var(--primary-low);
      --sp-admin-muted: var(--primary-medium);
      display: flex;
      flex-direction: column;
      gap: 1.25rem;
      min-width: 0;
    }
    .social-profile-admin-dashboard h2,
    .social-profile-admin-dashboard h3,
    .social-profile-admin-dashboard p {
      margin: 0;
    }
    .social-profile-admin-dashboard__metric,
    .social-profile-admin-dashboard__card {
      border: 1px solid var(--sp-admin-border);
      border-radius: 18px;
      background: var(--sp-admin-surface);
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }
    .social-profile-admin-dashboard__section {
      display: grid;
      gap: .7rem;
    }
    .social-profile-admin-dashboard__muted,
    .social-profile-admin-dashboard__card p {
      color: var(--sp-admin-muted);
    }
    .social-profile-admin-dashboard__status-row {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: .8rem;
    }
    .social-profile-admin-dashboard__metric {
      min-width: 0;
      padding: .85rem 1rem;
    }
    .social-profile-admin-dashboard__metric-label {
      color: var(--sp-admin-muted);
      font-size: var(--font-down-1);
      font-weight: 700;
    }
    .social-profile-admin-dashboard__metric-value {
      margin-top: .25rem;
      font-size: var(--font-up-2);
      font-weight: 700;
      overflow-wrap: anywhere;
    }
    .social-profile-admin-dashboard__grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1rem;
    }
    .social-profile-admin-dashboard__card {
      display: flex;
      min-height: 165px;
      flex-direction: column;
      gap: .8rem;
      padding: 1rem 1.1rem;
      color: var(--primary);
      text-decoration: none;
      transition: border-color .12s ease, box-shadow .12s ease, transform .12s ease;
    }
    .social-profile-admin-dashboard__card:hover,
    .social-profile-admin-dashboard__card:focus {
      border-color: var(--tertiary-medium);
      box-shadow: 0 6px 18px rgb(0 0 0 / 6%);
      color: var(--primary);
      text-decoration: none;
      transform: translateY(-1px);
    }
    .social-profile-admin-dashboard__card.is-primary {
      border-color: var(--tertiary-low);
      background: linear-gradient(180deg, var(--secondary), var(--tertiary-very-low));
    }
    .social-profile-admin-dashboard__badge {
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
    .social-profile-admin-dashboard__badge.is-primary {
      border-color: var(--tertiary-low);
      background: var(--tertiary-low);
      color: var(--tertiary);
    }
    .social-profile-admin-dashboard__action {
      margin-top: auto;
      color: var(--tertiary);
      font-weight: 600;
    }
    @media (max-width: 850px) {
      .social-profile-admin-dashboard__status-row {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }
    @media (max-width: 600px) {
      .social-profile-admin-dashboard__status-row {
        grid-template-columns: 1fr;
      }
    }
  </style>

  <div class="social-profile-admin-dashboard">
    <section class="social-profile-admin-dashboard__section">
      <div>
        <h2>{{i18n "discourse_social_profile.admin.dashboard.current_status"}}</h2>
        <p class="social-profile-admin-dashboard__muted">
          {{i18n "discourse_social_profile.admin.dashboard.current_status_description"}}
        </p>
      </div>
      <div class="social-profile-admin-dashboard__status-row">
        <div class="social-profile-admin-dashboard__metric">
          <div class="social-profile-admin-dashboard__metric-label">
            {{i18n "discourse_social_profile.admin.dashboard.status"}}
          </div>
          <div class="social-profile-admin-dashboard__metric-value">
            {{if @model.enabled
              (i18n "discourse_social_profile.admin.dashboard.enabled")
              (i18n "discourse_social_profile.admin.dashboard.disabled")}}
          </div>
        </div>
        <div class="social-profile-admin-dashboard__metric">
          <div class="social-profile-admin-dashboard__metric-label">
            {{i18n "discourse_social_profile.admin.dashboard.platforms"}}
          </div>
          <div class="social-profile-admin-dashboard__metric-value">
            {{@model.platform_count}}
          </div>
        </div>
        <div class="social-profile-admin-dashboard__metric">
          <div class="social-profile-admin-dashboard__metric-label">
            {{i18n "discourse_social_profile.admin.dashboard.enabled_platforms"}}
          </div>
          <div class="social-profile-admin-dashboard__metric-value">
            {{@model.enabled_platform_count}}
          </div>
        </div>
        <div class="social-profile-admin-dashboard__metric">
          <div class="social-profile-admin-dashboard__metric-label">
            {{i18n "discourse_social_profile.admin.dashboard.social_links"}}
          </div>
          <div class="social-profile-admin-dashboard__metric-value">
            {{@model.total_links}}
          </div>
        </div>
      </div>
    </section>

    <section class="social-profile-admin-dashboard__section">
      <div>
        <h2>{{i18n "discourse_social_profile.admin.dashboard.overview_title"}}</h2>
        <p class="social-profile-admin-dashboard__muted">
          {{i18n "discourse_social_profile.admin.dashboard.overview_description"}}
        </p>
      </div>
      <div class="social-profile-admin-dashboard__grid">
        <a class="social-profile-admin-dashboard__card is-primary" href={{settingsUrl}}>
          <span class="social-profile-admin-dashboard__badge is-primary">
            {{i18n "discourse_social_profile.admin.dashboard.category_configuration"}}
          </span>
          <h3>{{i18n "discourse_social_profile.admin.dashboard.settings_title"}}</h3>
          <p>{{i18n "discourse_social_profile.admin.dashboard.settings_description"}}</p>
          <span class="social-profile-admin-dashboard__action">
            {{i18n "discourse_social_profile.admin.dashboard.open_tool"}}
          </span>
        </a>

        <a class="social-profile-admin-dashboard__card" href={{platformsUrl}}>
          <span class="social-profile-admin-dashboard__badge">
            {{i18n "discourse_social_profile.admin.dashboard.category_management"}}
          </span>
          <h3>{{i18n "discourse_social_profile.admin.dashboard.platforms_title"}}</h3>
          <p>{{i18n "discourse_social_profile.admin.dashboard.platforms_description"}}</p>
          <span class="social-profile-admin-dashboard__action">
            {{i18n "discourse_social_profile.admin.dashboard.open_tool"}}
          </span>
        </a>

        <a class="social-profile-admin-dashboard__card" href={{statisticsUrl}}>
          <span class="social-profile-admin-dashboard__badge">
            {{i18n "discourse_social_profile.admin.dashboard.category_reporting"}}
          </span>
          <h3>{{i18n "discourse_social_profile.admin.dashboard.statistics_title"}}</h3>
          <p>{{i18n "discourse_social_profile.admin.dashboard.statistics_description"}}</p>
          <span class="social-profile-admin-dashboard__action">
            {{i18n "discourse_social_profile.admin.dashboard.open_tool"}}
          </span>
        </a>
      </div>
    </section>
  </div>
</template>
