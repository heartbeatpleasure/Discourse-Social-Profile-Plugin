import getURL from "discourse/lib/get-url";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/Discourse-Social-Profile-Plugin");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);
const statisticsRefreshUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/statistics?refresh=true"
);

export default <template>
  <section class="admin-detail social-profile-admin-page">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.statistics.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.statistics.description"}}
    />

    <div class="social-profile-admin-toolbar">
      <a class="btn btn-default" href={{overviewUrl}}>
        {{i18n "discourse_social_profile.admin.common.back_to_overview"}}
      </a>
      <a class="btn btn-default" href={{settingsUrl}}>
        {{i18n "discourse_social_profile.admin.common.open_settings"}}
      </a>
      <a class="btn btn-primary" href={{statisticsRefreshUrl}}>
        {{i18n "discourse_social_profile.admin.statistics.refresh"}}
      </a>
    </div>

    <div class="social-profile-stats-page">
      <section class="social-profile-stats-page__hero-card">
        <div>
          <div class="social-profile-stats-page__eyebrow">
            {{i18n "discourse_social_profile.admin.statistics.snapshot"}}
          </div>
          <h3>{{i18n "discourse_social_profile.admin.statistics.overview_title"}}</h3>
          <p>{{i18n "discourse_social_profile.admin.statistics.overview_blurb"}}</p>
        </div>
        <div class="social-profile-stats-page__generated-at">
          {{i18n "discourse_social_profile.admin.statistics.generated_at"}}
          <strong>{{@model.generated_at}}</strong>
        </div>
      </section>

      <section class="social-profile-stats-page__metric-grid">
        <article class="social-profile-stats-page__metric-card">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.total_users"}}</span>
          <strong>{{@model.total_users}}</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.total_users_help"}}</p>
        </article>
        <article class="social-profile-stats-page__metric-card">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.users_with_profiles"}}</span>
          <strong>{{@model.users_with_profiles}}</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.users_with_profiles_help"}}</p>
        </article>
        <article class="social-profile-stats-page__metric-card is-highlight">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.adoption"}}</span>
          <strong>{{@model.adoption_percentage}}%</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.adoption_help"}}</p>
        </article>
        <article class="social-profile-stats-page__metric-card">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.total_links"}}</span>
          <strong>{{@model.total_links}}</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.total_links_help"}}</p>
        </article>
        <article class="social-profile-stats-page__metric-card">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.avg_linked_user"}}</span>
          <strong>{{@model.average_links_per_linked_user}}</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.avg_linked_user_help"}}</p>
        </article>
        <article class="social-profile-stats-page__metric-card">
          <span class="social-profile-stats-page__metric-label">{{i18n "discourse_social_profile.admin.statistics.avg_all_users"}}</span>
          <strong>{{@model.average_links_per_all_users}}</strong>
          <p>{{i18n "discourse_social_profile.admin.statistics.avg_all_users_help"}}</p>
        </article>
      </section>

      <section class="social-profile-stats-page__panel-grid">
        <article class="social-profile-stats-page__panel-card">
          <div class="social-profile-stats-page__panel-header">
            <div>
              <div class="social-profile-stats-page__eyebrow">{{i18n "discourse_social_profile.admin.statistics.distribution"}}</div>
              <h3>{{i18n "discourse_social_profile.admin.statistics.link_distribution_title"}}</h3>
            </div>
          </div>

          <div class="social-profile-stats-page__distribution-grid">
            <div class="social-profile-stats-page__distribution-item">
              <span>1</span>
              <strong>{{@model.distribution.one}}</strong>
              <small>{{i18n "discourse_social_profile.admin.statistics.links_suffix"}}</small>
            </div>
            <div class="social-profile-stats-page__distribution-item">
              <span>2</span>
              <strong>{{@model.distribution.two}}</strong>
              <small>{{i18n "discourse_social_profile.admin.statistics.links_suffix"}}</small>
            </div>
            <div class="social-profile-stats-page__distribution-item">
              <span>3</span>
              <strong>{{@model.distribution.three}}</strong>
              <small>{{i18n "discourse_social_profile.admin.statistics.links_suffix"}}</small>
            </div>
            <div class="social-profile-stats-page__distribution-item">
              <span>4</span>
              <strong>{{@model.distribution.four}}</strong>
              <small>{{i18n "discourse_social_profile.admin.statistics.links_suffix"}}</small>
            </div>
            <div class="social-profile-stats-page__distribution-item">
              <span>5+</span>
              <strong>{{@model.distribution.five_plus}}</strong>
              <small>{{i18n "discourse_social_profile.admin.statistics.links_suffix"}}</small>
            </div>
          </div>
        </article>

        <article class="social-profile-stats-page__panel-card">
          <div class="social-profile-stats-page__panel-header">
            <div>
              <div class="social-profile-stats-page__eyebrow">{{i18n "discourse_social_profile.admin.statistics.activity"}}</div>
              <h3>{{i18n "discourse_social_profile.admin.statistics.recent_changes_title"}}</h3>
            </div>
          </div>

          <div class="social-profile-stats-page__key-value-list">
            <div><span>{{i18n "discourse_social_profile.admin.statistics.new_links_7d"}}</span><strong>{{@model.new_links_7d}}</strong></div>
            <div><span>{{i18n "discourse_social_profile.admin.statistics.new_links_30d"}}</span><strong>{{@model.new_links_30d}}</strong></div>
            <div><span>{{i18n "discourse_social_profile.admin.statistics.changed_links_7d"}}</span><strong>{{@model.changed_links_7d}}</strong></div>
            <div><span>{{i18n "discourse_social_profile.admin.statistics.changed_links_30d"}}</span><strong>{{@model.changed_links_30d}}</strong></div>
            <div><span>{{i18n "discourse_social_profile.admin.statistics.invalid_values"}}</span><strong>{{@model.invalid_values_detected}}</strong></div>
            <div><span>{{i18n "discourse_social_profile.admin.statistics.audited_values"}}</span><strong>{{@model.invalid_values_audited}}</strong></div>
          </div>

          {{#if @model.invalid_values_scan_truncated}}
            <p class="social-profile-stats-page__note">
              {{i18n "discourse_social_profile.admin.statistics.audit_limit_note" limit=@model.invalid_values_audit_limit}}
            </p>
          {{/if}}
        </article>
      </section>

      <section class="social-profile-stats-page__panel-card social-profile-stats-page__panel-card--full">
        <div class="social-profile-stats-page__panel-header">
          <div>
            <div class="social-profile-stats-page__eyebrow">{{i18n "discourse_social_profile.admin.statistics.platform_usage"}}</div>
            <h3>{{i18n "discourse_social_profile.admin.statistics.platforms_title"}}</h3>
            <p>{{i18n "discourse_social_profile.admin.statistics.platforms_help"}}</p>
          </div>
        </div>

        <div class="social-profile-stats-page__table-wrap">
          <table class="d-table social-profile-stats-page__table">
            <thead>
              <tr class="d-table__row">
                <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.platform_column"}}</th>
                <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.users_column"}}</th>
                <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.share_column"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @model.platforms as |platform|}}
                <tr class="d-table__row">
                  <td class="d-table__cell">{{platform.label}}</td>
                  <td class="d-table__cell">{{platform.users}}</td>
                  <td class="d-table__cell">{{platform.percentage_of_linked_users}}%</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      </section>

      <section class="social-profile-stats-page__panel-grid">
        <article class="social-profile-stats-page__panel-card">
          <div class="social-profile-stats-page__panel-header">
            <div>
              <div class="social-profile-stats-page__eyebrow">{{i18n "discourse_social_profile.admin.statistics.engagement"}}</div>
              <h3>{{i18n "discourse_social_profile.admin.statistics.clicks_title"}}</h3>
            </div>
          </div>

          {{#if @model.click_tracking_enabled}}
            <div class="social-profile-stats-page__click-total">
              <span>{{i18n "discourse_social_profile.admin.statistics.clicks_last_30d"}}</span>
              <strong>{{@model.clicks_30d_total}}</strong>
            </div>
            <div class="social-profile-stats-page__table-wrap">
              <table class="d-table social-profile-stats-page__table">
                <thead>
                  <tr class="d-table__row">
                    <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.platform_column"}}</th>
                    <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.clicks_column"}}</th>
                    <th class="d-table__cell">{{i18n "discourse_social_profile.admin.statistics.share_column"}}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each @model.clicks as |row|}}
                    <tr class="d-table__row">
                      <td class="d-table__cell">{{row.label}}</td>
                      <td class="d-table__cell">{{row.clicks_30d}}</td>
                      <td class="d-table__cell">{{row.click_share_percentage}}%</td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          {{else}}
            <div class="social-profile-stats-page__empty-state">
              <strong>{{i18n "discourse_social_profile.admin.statistics.click_tracking_disabled_title"}}</strong>
              <p>{{i18n "discourse_social_profile.admin.statistics.click_tracking_disabled_body"}}</p>
            </div>
          {{/if}}
        </article>

        <article class="social-profile-stats-page__panel-card">
          <div class="social-profile-stats-page__panel-header">
            <div>
              <div class="social-profile-stats-page__eyebrow">{{i18n "discourse_social_profile.admin.statistics.interpretation"}}</div>
              <h3>{{i18n "discourse_social_profile.admin.statistics.reading_guide_title"}}</h3>
            </div>
          </div>

          <div class="social-profile-stats-page__reading-guide">
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
    </div>
  </section>
</template>
