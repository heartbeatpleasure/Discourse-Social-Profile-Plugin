import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.overview.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.overview.description"}}
    />

    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard>
          <:content>
            <div class="social-profile-stat-cards">
              <div class="social-profile-stat-card"><strong>{{@model.platform_count}}</strong>Platforms</div>
              <div class="social-profile-stat-card"><strong>{{@model.enabled_platform_count}}</strong>Enabled platforms</div>
              <div class="social-profile-stat-card"><strong>{{@model.total_links}}</strong>Social links</div>
              <div class="social-profile-stat-card"><strong>{{@model.used_platform_count}}</strong>Platforms in use</div>
            </div>
            <table class="d-table">
              <tbody>
                <tr class="d-table__row"><th class="d-table__cell">Plugin enabled</th><td class="d-table__cell">{{@model.enabled}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Profile rendering</th><td class="d-table__cell">{{@model.show_on_profile}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">User-card rendering</th><td class="d-table__cell">{{@model.show_on_user_card}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Click tracking</th><td class="d-table__cell">{{@model.click_tracking_enabled}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">External icon URLs</th><td class="d-table__cell">{{@model.external_icon_urls_enabled}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Native image uploads</th><td class="d-table__cell">{{@model.native_image_uploads}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Native mask uploads</th><td class="d-table__cell">{{@model.native_mask_uploads}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Bundled icons</th><td class="d-table__cell">{{@model.bundled_icon_count}}</td></tr>
                <tr class="d-table__row"><th class="d-table__cell">Minimum Discourse</th><td class="d-table__cell">{{@model.required_version}}</td></tr>
              </tbody>
            </table>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </section>
</template>
