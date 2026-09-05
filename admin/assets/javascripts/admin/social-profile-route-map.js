export default {
  resource: "admin.adminPlugins",
  path: "/plugins",

  map() {
    this.route("socialProfile", { path: "/social-profile" });
  },
};
