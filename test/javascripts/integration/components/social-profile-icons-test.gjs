import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SocialProfileIcons from "discourse/plugins/discourse-social-profile/discourse/components/social-profile-icons";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | social-profile-icons", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.discourse_social_profile_icon_color = "black";
    siteSettings.discourse_social_profile_icon_color_dark = "";
    siteSettings.discourse_social_profile_use_platform_colors = false;
  });

  test("renders an accessible external social link with the parity container", async function (assert) {
    const outletArgs = { user: { social_profiles: [{ key: "example", label: "Example Social", href: "https://example.com/user", icon_name: "globe" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    assert.dom(".iconic-user-fields").exists();
    assert.dom(".iconic-user-fields a").hasAttribute("href", "https://example.com/user");
    assert.dom(".iconic-user-fields a").hasAttribute("target", "_blank");
    assert.dom(".iconic-user-fields a").hasAttribute("rel", "nofollow noopener noreferrer");
    assert.dom(".iconic-user-fields a").hasAttribute("aria-label", "Example Social");
  });

  test("keeps tracked links external and marks them for background analytics", async function (assert) {
    const outletArgs = { user: { social_profiles: [{ key: "tracked", label: "Tracked", href: "https://example.com/tracked", click_token: "abcdefghijklmnopqrstuvwxyzABCDEF", icon_name: "globe" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    assert.dom('.social-profile-icons a[data-social-platform="tracked"]').hasAttribute("href", "https://example.com/tracked");
    assert.dom('.social-profile-icons a[data-social-platform="tracked"]').hasAttribute("data-click-tracking", "true");
  });

  test("keeps full-color image priority above mask and FontAwesome", async function (assert) {
    const outletArgs = { user: { social_profiles: [{ key: "image", label: "Image", href: "https://example.com/image", icon_name: "globe", icon_image_url: "/uploads/default/original/1X/icon.png", icon_mask_url: "/uploads/default/original/1X/mask.svg" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    assert.dom(".slc-image-icon").exists();
    assert.dom(".slc-custom-icon").doesNotExist();
  });

  test("uses a monochrome mask when no full-color image is configured", async function (assert) {
    const outletArgs = { user: { social_profiles: [{ key: "mask", label: "Mask", href: "https://example.com/mask", icon_name: "globe", icon_mask_url: "/plugins/discourse-social-profile/images/social-profile/onlyfans.svg" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    assert.dom(".slc-custom-icon").exists();
    assert.dom(".slc-image-icon").doesNotExist();
    const style = document.querySelector(".iconic-user-fields a").getAttribute("style") || "";
    assert.ok(style.includes("--slc-icon-mask:url('/plugins/discourse-social-profile/images/social-profile/onlyfans.svg')"));
    const maskStyle = document.querySelector(".slc-custom-icon").getAttribute("style") || "";
    assert.ok(maskStyle.includes("opacity:0.45"));
  });

  test("uses dark platform, badge and global color values with light fallbacks", async function (assert) {
    const siteSettings = this.owner.lookup("service:site-settings");
    const interfaceColor = this.owner.lookup("service:interface-color");
    siteSettings.discourse_social_profile_icon_color = "black";
    siteSettings.discourse_social_profile_icon_color_dark = "white";
    siteSettings.discourse_social_profile_use_platform_colors = true;
    interfaceColor.colorMode = "dark";
    const outletArgs = { user: { social_profiles: [
      { key: "dark", label: "Dark", href: "https://example.com/dark", icon_name: "globe", color: "blue", color_dark: "cyan", badge_background: "#111111", badge_background_dark: "#222222" },
      { key: "fallback", label: "Fallback", href: "https://example.com/fallback", icon_name: "globe", color: "green", color_dark: "", badge_background: "#333333", badge_background_dark: "" },
    ] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    const containerStyle = document.querySelector(".iconic-user-fields").getAttribute("style") || "";
    const links = document.querySelectorAll(".iconic-user-fields a");
    assert.ok(containerStyle.includes("--slc-global-icon-color:white"));
    assert.ok((links[0].getAttribute("style") || "").includes("--slc-icon-color:cyan"));
    assert.ok((links[0].getAttribute("style") || "").includes("--slc-badge-bg:#222222"));
    assert.ok((links[1].getAttribute("style") || "").includes("--slc-icon-color:green"));
  });

  test("does not enable a dark-only badge while light mode is active", async function (assert) {
    const interfaceColor = this.owner.lookup("service:interface-color");
    interfaceColor.colorMode = "light";
    const outletArgs = { user: { social_profiles: [{ key: "dark-only-badge", label: "Dark-only badge", href: "https://example.com/dark-only", icon_name: "globe", badge_background: "", badge_background_dark: "#222222" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    assert.dom(".slc-icon-frame.slc-badge").doesNotExist();
    assert.dom(".slc-icon-frame").exists();
  });

  test("rejects unsafe client-side style values", async function (assert) {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.discourse_social_profile_icon_color = "red;display:none";
    siteSettings.discourse_social_profile_use_platform_colors = true;
    const outletArgs = { user: { social_profiles: [{ key: "safe-style", label: "Safe style", href: "https://example.com/style", icon_name: "globe", color: "blue;position:fixed", badge_background: "#112233", badge_radius: "4px" }] } };
    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);
    const containerStyle = document.querySelector(".iconic-user-fields").getAttribute("style") || "";
    const linkStyle = document.querySelector(".iconic-user-fields a").getAttribute("style") || "";
    assert.notOk(containerStyle.includes("display:none"));
    assert.notOk(linkStyle.includes("position:fixed"));
    assert.ok(linkStyle.includes("--slc-badge-bg:#112233"));
    assert.ok(linkStyle.includes("--slc-badge-radius:4px"));
  });

  test("renders FontAwesome and bundled-mask profiles together without dropping a platform", async function (assert) {
    const outletArgs = { user: { social_profiles: [
      { key: "instagram", label: "Instagram", href: "https://instagram.com/example", icon_name: "fab-instagram" },
      { key: "youtube", label: "YouTube", href: "https://youtube.com/@example", icon_name: "fab-youtube" },
      { key: "discord_profile", label: "Discord", href: "https://discord.com/users/123", icon_name: "fab-discord" },
      { key: "pornhub", label: "Pornhub", href: "https://www.pornhub.com/users/example", icon_name: "globe", icon_mask_url: "/plugins/Discourse-Social-Profile-Plugin/images/social-profile/pornhub.svg" },
    ] } };

    await render(<template><SocialProfileIcons @outletArgs={{outletArgs}} /></template>);

    assert.dom(".social-profile-icons").hasAttribute("data-social-profile-count", "4");
    assert.dom('.social-profile-icons a[data-social-platform="instagram"]').exists();
    assert.dom('.social-profile-icons a[data-social-platform="youtube"]').exists();
    assert.dom('.social-profile-icons a[data-social-platform="discord_profile"]').exists();
    assert.dom('.social-profile-icons a[data-social-platform="pornhub"]').exists();
    assert.dom('.social-profile-icons a[data-social-platform="pornhub"] .slc-custom-icon').exists();

    const containerStyle = document.querySelector(".social-profile-icons").getAttribute("style") || "";
    const pornhubMaskStyle = document.querySelector('.social-profile-icons a[data-social-platform="pornhub"] .slc-custom-icon').getAttribute("style") || "";
    assert.ok(containerStyle.includes("display:flex"));
    assert.ok(containerStyle.includes("flex-direction:row"));
    assert.ok(pornhubMaskStyle.includes("mask:url('/plugins/Discourse-Social-Profile-Plugin/images/social-profile/pornhub.svg')"));
  });

});
