export default {
  resource: "user.preferences",
  map() {
    this.route("social-profiles", { path: "social-profiles" });
  },
};
