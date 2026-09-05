import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SocialProfilePreferencesNav extends Component {
  static shouldRender({ model }, { currentUser, siteSettings }) {
    return (
      siteSettings.discourse_social_profile_enabled &&
      currentUser &&
      model?.id === currentUser.id
    );
  }

  <template>
    <li class="user-nav__preferences-social-profiles">
      <LinkTo @route="preferences.social-profiles">
        {{dIcon "address-card"}}
        <span>{{i18n "discourse_social_profile.preferences.title"}}</span>
      </LinkTo>
    </li>
  </template>
}
