import getURL from "discourse/lib/get-url";
import SocialProfilePlatformEditor from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platform-editor";
import { i18n } from "discourse-i18n";

const platformsUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/platforms"
);

export default <template>
  <style>
    .sp-platform-edit-page {
      display: grid;
      gap: 1rem;
      min-width: 0;
      width: 100%;
    }
    .sp-platform-edit-page h1,
    .sp-platform-edit-page p { margin: 0; }
    .sp-platform-edit-page__hero {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1rem;
      padding: 1.1rem 1.25rem;
      border: 1px solid var(--primary-low);
      border-radius: 18px;
      background: var(--secondary);
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }
    .sp-platform-edit-page__copy {
      display: grid;
      gap: .3rem;
      min-width: 0;
    }
    .sp-platform-edit-page__copy p {
      color: var(--primary-medium);
      line-height: 1.45;
    }
    .sp-platform-edit-page__hero .btn {
      flex: 0 0 auto;
      min-height: 2.5rem;
      margin: 0;
      white-space: nowrap;
    }
    @media (max-width: 700px) {
      .sp-platform-edit-page__hero { flex-direction: column; }
    }
  </style>

  <section class="admin-detail sp-platform-edit-page">
    <section class="sp-platform-edit-page__hero">
      <div class="sp-platform-edit-page__copy">
        <h1>{{i18n "discourse_social_profile.admin.platforms.create"}}</h1>
        <p>{{i18n "discourse_social_profile.admin.platforms.create_description"}}</p>
      </div>
      <a class="btn btn-default" href={{platformsUrl}}>
        {{i18n "discourse_social_profile.admin.platforms.back"}}
      </a>
    </section>

    <SocialProfilePlatformEditor @model={{@model}} />
  </section>
</template>
