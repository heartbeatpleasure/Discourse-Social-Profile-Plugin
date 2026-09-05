import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import getURL from "discourse/lib/get-url";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/social-profile");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);

export default <template>
  <section class="admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.statistics.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.statistics.description"}}
    >
      <:actions>
        <a class="btn" href={{overviewUrl}}>
          {{i18n "discourse_social_profile.admin.back_to_overview"}}
        </a>
        <a class="btn" href={{settingsUrl}}>
          {{i18n "discourse_social_profile.admin.dashboard.open_settings"}}
        </a>
      </:actions>
    </DPageSubheader>

    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard>
          <:content>
            <div class="social-profile-stat-cards">
              <div class="social-profile-stat-card"><strong>{{@model.total_users}}</strong>Total users</div>
              <div class="social-profile-stat-card"><strong>{{@model.users_with_profiles}}</strong>Users with social profiles</div>
              <div class="social-profile-stat-card"><strong>{{@model.adoption_percentage}}%</strong>Adoption</div>
              <div class="social-profile-stat-card"><strong>{{@model.total_links}}</strong>Total links</div>
              <div class="social-profile-stat-card"><strong>{{@model.average_links_per_linked_user}}</strong>Avg. per linked user</div>
              <div class="social-profile-stat-card"><strong>{{@model.average_links_per_all_users}}</strong>Avg. per all users</div>
            </div>

            <h3>Link distribution</h3>
            <table class="d-table">
              <tbody>
                <tr class="d-table__row"><th class="d-table__cell">1 link</th><td class="d-table__cell">{{@model.distribution.one}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">2 links</th><td class="d-table__cell">{{@model.distribution.two}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">3 links</th><td class="d-table__cell">{{@model.distribution.three}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">4 links</th><td class="d-table__cell">{{@model.distribution.four}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">5+ links</th><td class="d-table__cell">{{@model.distribution.five_plus}}</td></tr>
              </tbody>
            </table>

            <h3>Platforms</h3>
            <table class="d-table">
              <thead><tr class="d-table__row"><th class="d-table__cell">Platform</th><th class="d-table__cell">Users</th><th class="d-table__cell">Share of linked users</th></tr></thead>
              <tbody>
                {{#each @model.platforms as |platform|}}
                  <tr class="d-table__row"><td class="d-table__cell">{{platform.label}}</td><td class="d-table__cell">{{platform.users}}</td><td class="d-table__cell">{{platform.percentage_of_linked_users}}%</td></tr>
                {{/each}}
              </tbody>
            </table>

            <h3>Recent changes</h3>
            <table class="d-table"><tbody>
              <tr class="d-table__row"><th class="d-table__cell">New links (7 days)</th><td class="d-table__cell">{{@model.new_links_7d}}</td></tr>
              <tr class="d-table__row"><th class="d-table__cell">New links (30 days)</th><td class="d-table__cell">{{@model.new_links_30d}}</td></tr>
              <tr class="d-table__row"><th class="d-table__cell">Changed links (7 days)</th><td class="d-table__cell">{{@model.changed_links_7d}}</td></tr>
              <tr class="d-table__row"><th class="d-table__cell">Changed links (30 days)</th><td class="d-table__cell">{{@model.changed_links_30d}}</td></tr>
              <tr class="d-table__row"><th class="d-table__cell">Invalid values detected</th><td class="d-table__cell">{{@model.invalid_values_detected}} / {{@model.invalid_values_audited}} audited</td></tr>
            </tbody></table>

            {{#if @model.click_tracking_enabled}}
              <h3>Clicks — last 30 days</h3>
              <p>Total: {{@model.clicks_30d_total}}</p>
              <table class="d-table">
                <thead><tr class="d-table__row"><th class="d-table__cell">Platform</th><th class="d-table__cell">Clicks</th><th class="d-table__cell">Share</th></tr></thead>
                <tbody>
                  {{#each @model.clicks as |row|}}
                    <tr class="d-table__row"><td class="d-table__cell">{{row.label}}</td><td class="d-table__cell">{{row.clicks_30d}}</td><td class="d-table__cell">{{row.click_share_percentage}}%</td></tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <p>Click tracking is disabled. Links point directly to their provider and no click events are stored.</p>
            {{/if}}
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </section>
</template>
