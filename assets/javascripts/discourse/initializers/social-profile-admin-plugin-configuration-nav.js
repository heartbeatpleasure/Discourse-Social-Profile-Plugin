// Social Profile uses the same standalone admin landing pattern as the working
// HIBP, Link Safety, Heartrate and Disify plugins. Do not register modern
// adminPlugins.show configuration navigation here: the admin sidebar must point
// at adminPlugins.socialProfile, while Installed Plugins -> Settings stays a
// direct Site Settings link.
export default {
  name: "social-profile-admin-plugin-configuration-nav-disabled",
  initialize() {},
};
