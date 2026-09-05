import BackButton from "discourse/components/back-button";
import SocialProfilePlatformEditor from "discourse/plugins/discourse-social-profile/discourse/components/social-profile-platform-editor";

export default <template>
  <BackButton
    @route="adminPlugins.show.discourse-social-profile-platforms"
    @label="discourse_social_profile.admin.platforms.back"
  />
  {{#if @model}}
    <SocialProfilePlatformEditor @model={{@model}} />
  {{/if}}
</template>
