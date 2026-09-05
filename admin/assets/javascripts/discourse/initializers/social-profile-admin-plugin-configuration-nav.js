// Compatibility stub.
//
// Discourse discovers plugin configuration-navigation initializers from
// assets/javascripts/discourse/initializers. The active initializer was moved
// there so the new admin plugin show route can resolve Overview/Platforms/
// Statistics before choosing its default child route.
export default {
  name: "social-profile-admin-plugin-configuration-nav-legacy-stub",
  initialize() {},
};
