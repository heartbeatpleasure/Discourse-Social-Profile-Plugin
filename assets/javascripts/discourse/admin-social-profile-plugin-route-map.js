export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("discourse-social-profile-overview", { path: "overview" });
    this.route("discourse-social-profile-platforms", { path: "platforms" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });
    this.route("discourse-social-profile-statistics", { path: "statistics" });
  },
};
