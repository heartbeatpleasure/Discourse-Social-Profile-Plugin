import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import SocialProfilePlatformsList from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platforms-list";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="admin-detail">
    <DPageSubheader
      @titleLabel={{i18n "discourse_social_profile.admin.platforms.title"}}
      @descriptionLabel={{i18n "discourse_social_profile.admin.platforms.description"}}
    >
      <:actions as |actions|>
        <actions.Primary
          @route="adminPlugins.show.discourse-social-profile-platforms.new"
          @icon="plus"
          @label="discourse_social_profile.admin.platforms.add"
        />
      </:actions>
    </DPageSubheader>
    <div class="admin-config-area"><div class="admin-config-area__primary-content">
      <SocialProfilePlatformsList @platforms={{@model.platforms}} />
    </div></div>
  </section>
</template>
