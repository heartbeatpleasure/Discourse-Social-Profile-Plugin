import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SocialProfilePlatformsList from "discourse/plugins/Discourse-Social-Profile-Plugin/discourse/components/social-profile-platforms-list";
import { i18n } from "discourse-i18n";

const overviewUrl = getURL("/admin/plugins/social-profile");
const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=discourse_social_profile"
);
const addPlatformUrl = getURL(
  "/admin/plugins/Discourse-Social-Profile-Plugin/platforms/new"
);

export default <template>
  <style>
    .sp-platforms-page {
      display: grid;
      gap: 1rem;
      min-width: 0;
    }
    .sp-platforms-page h1,
    .sp-platforms-page p { margin: 0; }
    .sp-platforms-page__hero {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 1rem;
      padding: 1.2rem 1.35rem;
      border: 1px solid var(--primary-low);
      border-radius: 18px;
      background: var(--secondary);
      box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
    }
    .sp-platforms-page__copy {
      display: grid;
      gap: .35rem;
      min-width: 0;
    }
    .sp-platforms-page__copy p {
      color: var(--primary-medium);
      line-height: 1.45;
    }
    .sp-platforms-page__actions {
      display: flex;
      flex: 0 0 auto;
      flex-wrap: wrap;
      align-items: center;
      justify-content: flex-end;
      gap: .55rem;
      margin-left: auto;
    }
    .sp-platforms-page__actions .btn,
    .sp-platforms-page__primary-action .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: .45rem;
      min-height: 2.5rem;
      margin: 0;
      padding-inline: 1rem;
      white-space: nowrap;
      box-sizing: border-box;
    }
    .sp-platforms-page__primary-action {
      display: flex;
      justify-content: flex-start;
    }
    .sp-platforms-page__table-shell {
      min-width: 0;
      max-width: 100%;
      overflow-x: hidden;
      padding: .25rem 0 0;
    }
    .sp-platforms-page__table-shell .social-profile-platforms-table {
      width: 100%;
      max-width: 100%;
      min-width: 0;
    }
    @media (max-width: 760px) {
      .sp-platforms-page__hero { flex-direction: column; }
      .sp-platforms-page__actions { justify-content: flex-start; margin-left: 0; }
    }
    @media (max-width: 520px) {
      .sp-platforms-page__hero { padding: 1rem; }
      .sp-platforms-page__actions,
      .sp-platforms-page__primary-action { width: 100%; }
      .sp-platforms-page__actions .btn,
      .sp-platforms-page__primary-action .btn { flex: 1 1 auto; }
    }
  </style>

  <section class="admin-detail sp-platforms-page">
    <section class="sp-platforms-page__hero">
      <div class="sp-platforms-page__copy">
        <h1>{{i18n "discourse_social_profile.admin.platforms.title"}}</h1>
        <p>{{i18n "discourse_social_profile.admin.platforms.description"}}</p>
      </div>
      <div class="sp-platforms-page__actions">
        <a class="btn btn-default" href={{overviewUrl}}>
          {{i18n "discourse_social_profile.admin.common.back_to_overview"}}
        </a>
        <a class="btn btn-default" href={{settingsUrl}}>
          {{i18n "discourse_social_profile.admin.common.open_settings"}}
        </a>
      </div>
    </section>

    <div class="sp-platforms-page__primary-action">
      <a class="btn btn-primary" href={{addPlatformUrl}}>
        {{dIcon "plus"}}
        <span>{{i18n "discourse_social_profile.admin.platforms.add"}}</span>
      </a>
    </div>

    <div class="sp-platforms-page__table-shell">
      <SocialProfilePlatformsList @platforms={{@model.platforms}} />
    </div>
  </section>
</template>
