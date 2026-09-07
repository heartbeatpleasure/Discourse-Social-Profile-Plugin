import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/social-profile");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);
const statisticsRefreshUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/statistics?refresh=true"
);
const retentionSettingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile_click_stats_retention_days"
);

export default <template>
  <style>
    .sp-stats {
      --sp-border: var(--primary-low);
      --sp-muted: var(--primary-medium);
      --sp-surface: var(--secondary);
      --sp-alt: var(--primary-very-low);
      display: grid;
      gap: 1rem;
      width: 100%;
      min-width: 0;
    }

    .sp-stats h1,
    .sp-stats h2,
    .sp-stats h3,
    .sp-stats p {
      margin: 0;
    }

    .sp-stats__header,
    .sp-stats__metric,
    .sp-stats__panel {
      box-sizing: border-box;
      border: 1px solid var(--sp-border);
      border-radius: 18px;
      background: var(--sp-surface);
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }

    .sp-stats__header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1.25rem;
      padding: 1.25rem 1.35rem;
    }

    .sp-stats__header-copy {
      display: grid;
      gap: .4rem;
      min-width: 0;
      max-width: 58rem;
    }

    .sp-stats__header-copy h1 {
      font-size: clamp(1.7rem, 1.35rem + 1vw, 2.2rem);
      line-height: 1.1;
    }

    .sp-stats__header-copy p,
    .sp-stats__panel-header p,
    .sp-stats__metric p,
    .sp-stats__empty p,
    .sp-stats__guide p {
      color: var(--sp-muted);
      line-height: 1.45;
    }

    .sp-stats__header-actions {
      display: flex;
      flex: 0 0 auto;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: .6rem;
    }

    .sp-stats__header-actions .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 2.55rem;
      margin: 0;
      padding-inline: 1rem;
      white-space: nowrap;
    }

    .sp-stats__section-heading {
      display: grid;
      gap: .25rem;
      margin: .15rem 0 -.15rem;
    }

    .sp-stats__section-heading p {
      color: var(--sp-muted);
    }

    .sp-stats__metrics {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 1rem;
    }

    .sp-stats__metric {
      display: grid;
      align-content: start;
      gap: .45rem;
      min-width: 0;
      min-height: 9.5rem;
      padding: 1rem 1.05rem;
    }

    .sp-stats__metric-label,
    .sp-stats__eyebrow {
      color: var(--sp-muted);
      font-size: var(--font-down-1);
      font-weight: 700;
    }

    .sp-stats__metric strong {
      font-size: clamp(1.75rem, 1.3rem + 1.2vw, 2.35rem);
      line-height: 1.05;
      overflow-wrap: anywhere;
    }

    .sp-stats__panel-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 1rem;
      align-items: start;
      min-width: 0;
    }

    .sp-stats__panel {
      min-width: 0;
      padding: 1rem 1.05rem 1.05rem;
    }

    .sp-stats__panel.is-wide {
      grid-column: 1 / -1;
    }

    .sp-stats__panel-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1rem;
      margin-bottom: .9rem;
    }

    .sp-stats__eyebrow {
      display: inline-flex;
      width: max-content;
      margin-bottom: .35rem;
      padding: .28rem .58rem;
      border-radius: 999px;
      background: var(--sp-alt);
      line-height: 1;
    }

    .sp-stats__panel-header h2 {
      font-size: var(--font-up-2);
    }

    .sp-stats__rows {
      display: grid;
      gap: 0;
    }

    .sp-stats__row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
      min-width: 0;
      padding: .78rem 0;
      border-bottom: 1px solid var(--sp-border);
    }

    .sp-stats__row:first-child {
      padding-top: 0;
    }

    .sp-stats__row:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }

    .sp-stats__row-label {
      min-width: 0;
      color: var(--sp-muted);
      line-height: 1.35;
    }

    .sp-stats__row-value {
      display: inline-flex;
      flex: 0 0 auto;
      align-items: baseline;
      gap: .35rem;
      white-space: nowrap;
    }

    .sp-stats__row-value strong {
      min-width: 3ch;
      text-align: right;
      font-size: var(--font-up-2);
      line-height: 1;
    }

    .sp-stats__row-value small {
      color: var(--sp-muted);
      font-size: var(--font-down-1);
    }

    .sp-stats__note {
      margin-top: .8rem !important;
      padding: .7rem .8rem;
      border-radius: 10px;
      background: var(--sp-alt);
      color: var(--sp-muted);
      font-size: var(--font-down-1);
      line-height: 1.4;
    }

    .sp-stats__table-wrap {
      width: 100%;
      overflow-x: auto;
    }

    .sp-stats__table {
      width: 100%;
      min-width: 42rem;
    }

    .sp-stats__table .d-table__cell {
      vertical-align: middle;
    }

    .sp-stats__table thead .d-table__cell {
      color: var(--sp-muted);
      font-size: var(--font-down-1);
      font-weight: 700;
    }

    .sp-stats__share-pill {
      display: inline-flex;
      min-width: 3.2rem;
      justify-content: center;
      padding: .2rem .48rem;
      border-radius: 999px;
      background: var(--sp-alt);
      font-size: var(--font-down-1);
      font-weight: 700;
    }

    .sp-stats__click-total {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 1rem;
      margin-bottom: .8rem;
      padding: .85rem 1rem;
      border-radius: 14px;
      background: var(--sp-alt);
    }

    .sp-stats__click-total span {
      color: var(--sp-muted);
    }

    .sp-stats__click-total strong {
      font-size: var(--font-up-3);
    }

    .sp-stats__retention-link {
      display: inline-flex;
      align-items: center;
      gap: .35rem;
      padding: .35rem .65rem;
      border-radius: 999px;
      background: var(--sp-alt);
      color: var(--primary-medium);
      font-size: var(--font-down-1);
      text-decoration: none;
      white-space: nowrap;
    }

    .sp-stats__retention-link:hover {
      color: var(--tertiary);
    }

    .sp-stats__click-totals {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: .65rem;
      margin-bottom: .9rem;
    }

    .sp-stats__click-total-card {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 1rem;
      padding: .8rem .9rem;
      border-radius: 14px;
      background: var(--sp-alt);
    }

    .sp-stats__click-total-card span {
      color: var(--sp-muted);
    }

    .sp-stats__click-total-card strong {
      font-size: var(--font-up-2);
    }

    .sp-stats__click-list {
      display: grid;
      gap: 0;
    }

    .sp-stats__click-row {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(5rem, auto) minmax(6.5rem, auto);
      gap: .8rem;
      align-items: center;
      padding: .72rem 0;
      border-bottom: 1px solid var(--sp-border);
    }

    .sp-stats__click-row:last-child {
      border-bottom: 0;
      padding-bottom: 0;
    }

    .sp-stats__click-row--header {
      padding-top: 0;
      color: var(--sp-muted);
      font-size: var(--font-down-1);
      font-weight: 700;
    }

    .sp-stats__click-row > :nth-child(2),
    .sp-stats__click-row > :nth-child(3) {
      text-align: right;
    }

    .sp-stats__empty {
      display: grid;
      gap: .35rem;
      padding: 1rem;
      border-radius: 14px;
      background: var(--sp-alt);
    }

    .sp-stats__guide {
      display: grid;
      gap: .8rem;
    }

    .sp-stats__guide > div {
      padding-bottom: .8rem;
      border-bottom: 1px solid var(--sp-border);
    }

    .sp-stats__guide > div:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }

    .sp-stats__guide strong {
      display: block;
      margin-bottom: .2rem;
    }

    @media (max-width: 980px) {
      .sp-stats__metrics {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }

    @media (max-width: 760px) {
      .sp-stats__header {
        flex-direction: column;
      }

      .sp-stats__header-actions {
        width: 100%;
        justify-content: flex-start;
      }

      .sp-stats__panel-grid {
        grid-template-columns: 1fr;
      }

      .sp-stats__panel.is-wide {
        grid-column: auto;
      }
    }

    @media (max-width: 560px) {
      .sp-stats__header,
      .sp-stats__metric,
      .sp-stats__panel {
        padding: .9rem;
        border-radius: 14px;
      }

      .sp-stats__metrics {
        grid-template-columns: 1fr;
      }

      .sp-stats__header-actions .btn {
        width: 100%;
      }

      .sp-stats__metric {
        min-height: 0;
      }

      .sp-stats__row,
      .sp-stats__click-total {
        align-items: flex-start;
      }

      .sp-stats__click-row {
        grid-template-columns: minmax(0, 1fr) auto;
      }

      .sp-stats__click-row > :nth-child(3) {
        grid-column: 1 / -1;
        text-align: left;
      }

      .sp-stats__click-row--header > :nth-child(3) {
        display: none;
      }
    }

    @media (max-width: 700px) {
      .sp-stats__click-totals {
        grid-template-columns: 1fr;
      }

      .sp-stats__panel-header {
        flex-wrap: wrap;
      }
    }
  </style>

  <section class="admin-detail sp-stats">
    <section class="sp-stats__header">
      <div class="sp-stats__header-copy">
        <h1>{{i18n "discourse_social_profile.admin.statistics.title"}}</h1>
        <p>{{i18n "discourse_social_profile.admin.statistics.description"}}</p>
      </div>

      <div class="sp-stats__header-actions">
        <a class="btn btn-primary" href={{statisticsRefreshUrl}}>
          {{i18n "discourse_social_profile.admin.statistics.refresh"}}
        </a>
        <a class="btn btn-default" href={{settingsUrl}}>
          {{i18n "discourse_social_profile.admin.common.open_settings"}}
        </a>
        <a class="btn btn-default" href={{overviewUrl}}>
          {{i18n "discourse_social_profile.admin.common.back_to_overview"}}
        </a>
      </div>
    </section>

    <div class="sp-stats__section-heading">
      <h2>{{i18n "discourse_social_profile.admin.statistics.overview_title"}}</h2>
      <p>{{i18n "discourse_social_profile.admin.statistics.overview_blurb"}}</p>
    </div>

    <section class="sp-stats__metrics">
      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.total_users"}}</span>
        <strong>{{@model.total_users}}</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.total_users_help"}}</p>
      </article>

      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.users_with_profiles"}}</span>
        <strong>{{@model.users_with_profiles}}</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.users_with_profiles_help"}}</p>
      </article>

      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.adoption"}}</span>
        <strong>{{@model.adoption_percentage}}%</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.adoption_help"}}</p>
      </article>

      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.total_links"}}</span>
        <strong>{{@model.total_links}}</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.total_links_help"}}</p>
      </article>

      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.avg_linked_user"}}</span>
        <strong>{{@model.average_links_per_linked_user}}</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.avg_linked_user_help"}}</p>
      </article>

      <article class="sp-stats__metric">
        <span class="sp-stats__metric-label">{{i18n "discourse_social_profile.admin.statistics.avg_all_users"}}</span>
        <strong>{{@model.average_links_per_all_users}}</strong>
        <p>{{i18n "discourse_social_profile.admin.statistics.avg_all_users_help"}}</p>
      </article>
    </section>

    <section class="sp-stats__panel-grid">
      <article class="sp-stats__panel">
        <div class="sp-stats__panel-header">
          <div>
            <div class="sp-stats__eyebrow">{{i18n "discourse_social_profile.admin.statistics.distribution"}}</div>
            <h2>{{i18n "discourse_social_profile.admin.statistics.link_distribution_title"}}</h2>
          </div>
        </div>

        <div class="sp-stats__rows">
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">1 link</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.one}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">2 links</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.two}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">3 links</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.three}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">4 links</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.four}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">5 links</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.five}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
          <div class="sp-stats__row">
            <span class="sp-stats__row-label">6+ links</span>
            <span class="sp-stats__row-value"><strong>{{@model.distribution.six_plus}}</strong><small>{{i18n "discourse_social_profile.admin.statistics.users_column"}}</small></span>
          </div>
        </div>
      </article>

      <article class="sp-stats__panel">
        <div class="sp-stats__panel-header">
          <div>
            <div class="sp-stats__eyebrow">{{i18n "discourse_social_profile.admin.statistics.activity"}}</div>
            <h2>{{i18n "discourse_social_profile.admin.statistics.recent_changes_title"}}</h2>
          </div>
        </div>

        <div class="sp-stats__rows">
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.new_links_7d"}}</span><span class="sp-stats__row-value"><strong>{{@model.new_links_7d}}</strong></span></div>
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.new_links_30d"}}</span><span class="sp-stats__row-value"><strong>{{@model.new_links_30d}}</strong></span></div>
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.changed_links_7d"}}</span><span class="sp-stats__row-value"><strong>{{@model.changed_links_7d}}</strong></span></div>
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.changed_links_30d"}}</span><span class="sp-stats__row-value"><strong>{{@model.changed_links_30d}}</strong></span></div>
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.invalid_values"}}</span><span class="sp-stats__row-value"><strong>{{@model.invalid_values_detected}}</strong></span></div>
          <div class="sp-stats__row"><span class="sp-stats__row-label">{{i18n "discourse_social_profile.admin.statistics.audited_values"}}</span><span class="sp-stats__row-value"><strong>{{@model.invalid_values_audited}}</strong></span></div>
        </div>

        {{#if @model.invalid_values_scan_timed_out}}
          <p class="sp-stats__note">
            {{i18n "discourse_social_profile.admin.statistics.audit_timeout_note"}}
          </p>
        {{else if @model.invalid_values_scan_truncated}}
          <p class="sp-stats__note">
            {{i18n "discourse_social_profile.admin.statistics.audit_limit_note" limit=@model.invalid_values_audit_limit}}
          </p>
        {{/if}}
      </article>
    </section>

    <section class="sp-stats__panel is-wide">
      <div class="sp-stats__panel-header">
        <div>
          <div class="sp-stats__eyebrow">{{i18n "discourse_social_profile.admin.statistics.platform_usage"}}</div>
          <h2>{{i18n "discourse_social_profile.admin.statistics.platforms_title"}}</h2>
          <p>{{i18n "discourse_social_profile.admin.statistics.platforms_help"}}</p>
        </div>
        {{#if @model.click_tracking_enabled}}
          <a class="sp-stats__retention-link" href={{retentionSettingsUrl}}>
            {{i18n "discourse_social_profile.admin.statistics.retention_link" period=@model.click_retention_label}}
          </a>
        {{/if}}
      </div>

      <div class="sp-stats__table-wrap">
        <table class="d-table sp-stats__table">
          <thead>
            <tr class="d-table__row">
              <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.platform_column"}}</th>
              <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.users_column"}}</th>
              <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.share_column"}}</th>
              {{#if @model.click_tracking_enabled}}
                <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.clicks_30d_column"}}</th>
                {{#if @model.show_retention_clicks}}
                  <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.clicks_retained_column" period=@model.click_retention_label}}</th>
                {{/if}}
              {{/if}}
            </tr>
          </thead>
          <tbody>
            {{#each @model.platforms as |platform|}}
              <tr class="d-table__row">
                <td class="d-table__cell"><strong>{{platform.label}}</strong></td>
                <td class="d-table__cell">{{platform.users}}</td>
                <td class="d-table__cell"><span class="sp-stats__share-pill">{{platform.percentage_of_linked_users}}%</span></td>
                {{#if @model.click_tracking_enabled}}
                  <td class="d-table__cell">{{platform.clicks_30d}}</td>
                  {{#if @model.show_retention_clicks}}
                    <td class="d-table__cell">{{platform.clicks_retained}}</td>
                  {{/if}}
                {{/if}}
              </tr>
            {{/each}}
          </tbody>
        </table>
      </div>
    </section>

    <section class="sp-stats__panel-grid">
      <article class="sp-stats__panel">
        <div class="sp-stats__panel-header">
          <div>
            <div class="sp-stats__eyebrow">{{i18n "discourse_social_profile.admin.statistics.engagement"}}</div>
            <h2>{{i18n "discourse_social_profile.admin.statistics.clicks_title"}}</h2>
          </div>
        </div>

        {{#if @model.click_tracking_enabled}}
          <div class="sp-stats__click-totals">
            <div class="sp-stats__click-total-card">
              <span>{{i18n "discourse_social_profile.admin.statistics.clicks_last_30d"}}</span>
              <strong>{{@model.clicks_30d_total}}</strong>
            </div>
            {{#if @model.show_retention_clicks}}
              <div class="sp-stats__click-total-card">
                <span>{{i18n "discourse_social_profile.admin.statistics.clicks_retained_total" period=@model.click_retention_label}}</span>
                <strong>{{@model.clicks_retained_total}}</strong>
              </div>
            {{/if}}
          </div>

          {{#if @model.clicks.length}}
            <div class="sp-stats__click-list">
              <div class="sp-stats__click-row sp-stats__click-row--header">
                <span>{{i18n "discourse_social_profile.admin.statistics.platform_column"}}</span>
                <span>{{i18n "discourse_social_profile.admin.statistics.clicks_column"}}</span>
                <span>{{i18n "discourse_social_profile.admin.statistics.click_share_column"}}</span>
              </div>
              {{#each @model.clicks as |row|}}
                <div class="sp-stats__click-row">
                  <strong>{{row.label}}</strong>
                  <span>{{row.clicks_30d}}</span>
                  <span><span class="sp-stats__share-pill">{{row.click_share_percentage}}%</span></span>
                </div>
              {{/each}}
            </div>
          {{else}}
            <div class="sp-stats__empty">
              <strong>{{i18n "discourse_social_profile.admin.statistics.no_clicks_title"}}</strong>
              <p>{{i18n "discourse_social_profile.admin.statistics.no_clicks_body"}}</p>
            </div>
          {{/if}}
        {{else}}
          <div class="sp-stats__empty">
            <strong>{{i18n "discourse_social_profile.admin.statistics.click_tracking_disabled_title"}}</strong>
            <p>{{i18n "discourse_social_profile.admin.statistics.click_tracking_disabled_body"}}</p>
          </div>
        {{/if}}
      </article>

      <article class="sp-stats__panel">
        <div class="sp-stats__panel-header">
          <div>
            <div class="sp-stats__eyebrow">{{i18n "discourse_social_profile.admin.statistics.interpretation"}}</div>
            <h2>{{i18n "discourse_social_profile.admin.statistics.reading_guide_title"}}</h2>
          </div>
        </div>

        <div class="sp-stats__guide">
          <div>
            <strong>{{i18n "discourse_social_profile.admin.statistics.reading_adoption_title"}}</strong>
            <p>{{i18n "discourse_social_profile.admin.statistics.reading_adoption_body"}}</p>
          </div>
          <div>
            <strong>{{i18n "discourse_social_profile.admin.statistics.reading_distribution_title"}}</strong>
            <p>{{i18n "discourse_social_profile.admin.statistics.reading_distribution_body"}}</p>
          </div>
          <div>
            <strong>{{i18n "discourse_social_profile.admin.statistics.reading_clicks_title"}}</strong>
            <p>{{i18n "discourse_social_profile.admin.statistics.reading_clicks_body"}}</p>
          </div>
        </div>
      </article>
    </section>
  </section>
</template>
