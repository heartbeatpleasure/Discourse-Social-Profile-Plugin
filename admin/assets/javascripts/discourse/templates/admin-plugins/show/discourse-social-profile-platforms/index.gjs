import dIcon from "discourse/ui-kit/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import SocialProfilePlatformsList from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platforms-list";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/social-profile");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);
const addPlatformUrl = getURL(
  "/admin/plugins/social-profile/platforms/new"
);

export default <template>
  <section class="admin-detail social-profile-admin-page">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.platforms.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.platforms.description"}}
    />

    <div class="social-profile-admin-toolbar">
      <a class="btn btn-default" href={{overviewUrl}}>
        {{i18n "discourse_social_profile.admin.common.back_to_overview"}}
      </a>
      <a class="btn btn-default" href={{settingsUrl}}>
        {{i18n "discourse_social_profile.admin.common.open_settings"}}
      </a>
      <a class="btn btn-primary" href={{addPlatformUrl}}>
        {{dIcon "plus"}}
        <span>{{i18n "discourse_social_profile.admin.platforms.add"}}</span>
      </a>
    </div>

    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <SocialProfilePlatformsList @platforms={{@model.platforms}} />
      </div>
    </div>
  </section>
</template>
