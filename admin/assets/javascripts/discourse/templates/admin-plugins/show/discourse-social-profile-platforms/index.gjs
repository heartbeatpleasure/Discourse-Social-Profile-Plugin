import getURL from "discourse/lib/get-url";
import SocialProfilePlatformsList from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platforms-list";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/social-profile");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);

export default <template>
  <section class="admin-detail social-profile-platforms-page">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.platforms.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.platforms.description"}}
    >
      <:actions as |actions|>
        <a class="btn" href={{overviewUrl}}>
          {{i18n "discourse_social_profile.admin.back_to_overview"}}
        </a>
        <a class="btn" href={{settingsUrl}}>
          {{i18n "discourse_social_profile.admin.dashboard.open_settings"}}
        </a>
        <actions.Primary
          @route="adminPlugins.show.discourse-social-profile-platforms.new"
          @icon="plus"
          @label="discourse_social_profile.admin.platforms.add"
        />
      </:actions>
    </DPageSubheader>

    <div class="social-profile-platforms-page__table-wrap">
      <SocialProfilePlatformsList @platforms={{@model.platforms}} />
    </div>
  </section>
</template>
