import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import getURL from "discourse/lib/get-url";

/**
 * Keep Installed Plugins -> Settings separate from the plugin dashboard.
 *
 * This mirrors the working HIBP, Link Safety and Disify plugins: the admin
 * sidebar opens the plugin-owned dashboard, while the Settings control on
 * /admin/plugins opens the generated Site Settings page through the stable
 * setting-key prefix.
 */
export default apiInitializer("0.11.1", (api) => {
  const PLUGIN_DISPLAY_NAME = "Discourse-Social-Profile-Plugin";
  const ADMIN_PLUGINS_PATH = getURL("/admin/plugins");
  const FIXED_SETTINGS_URL = getURL(
    "/admin/site_settings/category/all_results?filter=discourse_social_profile"
  );
  const SETTINGS_BUTTON_SELECTOR =
    `[data-plugin-setting-button="${PLUGIN_DISPLAY_NAME}"]`;

  let observer = null;
  let clickHandlerInstalled = false;

  function normalizedPath(url) {
    return (url || "").split("?")[0].replace(/\/+$/, "");
  }

  function isInstalledPluginsPage(url) {
    return normalizedPath(url) === normalizedPath(ADMIN_PLUGINS_PATH);
  }

  function findPluginCards() {
    return Array.from(document.querySelectorAll("[data-plugin-name]")).concat(
      Array.from(
        document.querySelectorAll(
          ".admin-plugins-list .admin-plugin, .admin-plugin"
        )
      )
    );
  }

  function cardLooksLikeOurPlugin(card) {
    if (!card) {
      return false;
    }

    const dataName = card.getAttribute?.("data-plugin-name");
    if (
      dataName &&
      dataName.toLowerCase() === PLUGIN_DISPLAY_NAME.toLowerCase()
    ) {
      return true;
    }

    const text = (card.textContent || "").toLowerCase();
    if (text.includes(PLUGIN_DISPLAY_NAME.toLowerCase())) {
      return true;
    }

    return Boolean(
      card.querySelector?.('a[href*="Discourse-Social-Profile-Plugin"]')
    );
  }

  function rewriteExactSettingsButtons() {
    for (const button of document.querySelectorAll(SETTINGS_BUTTON_SELECTOR)) {
      if (button.dataset.socialProfileSettingsFixed === "1") {
        continue;
      }

      button.setAttribute("href", FIXED_SETTINGS_URL);
      button.dataset.socialProfileSettingsFixed = "1";
    }
  }

  function rewriteSettingsLinkInCard(card) {
    if (!cardLooksLikeOurPlugin(card)) {
      return;
    }

    const anchors = Array.from(
      card.querySelectorAll('a[href*="/admin/site_settings"]')
    );

    for (const anchor of anchors) {
      if (anchor.dataset.socialProfileSettingsFixed === "1") {
        continue;
      }

      anchor.setAttribute("href", FIXED_SETTINGS_URL);
      anchor.dataset.socialProfileSettingsFixed = "1";
    }
  }

  function rewriteAll() {
    schedule("afterRender", () => {
      rewriteExactSettingsButtons();
      findPluginCards().forEach((card) => rewriteSettingsLinkInCard(card));
    });
  }

  function installClickInterceptOnce() {
    if (clickHandlerInstalled) {
      return;
    }

    clickHandlerInstalled = true;

    document.addEventListener(
      "click",
      (event) => {
        if (!isInstalledPluginsPage(window.location?.pathname)) {
          return;
        }

        const target = event.target;
        if (!target) {
          return;
        }

        const exactControl = target.closest?.(SETTINGS_BUTTON_SELECTOR);
        if (exactControl) {
          event.preventDefault();
          event.stopPropagation();
          window.location.assign(FIXED_SETTINGS_URL);
          return;
        }

        const control =
          target.closest?.(
            'a[href*="/admin/site_settings"], button, .btn, .d-button'
          ) || target;
        const label = `${control.getAttribute?.("aria-label") || ""} ${
          control.getAttribute?.("title") || ""
        }`;
        const href = control.getAttribute?.("href") || "";
        const isSettingsControl =
          label.toLowerCase().includes("settings") ||
          href.includes("/admin/site_settings");

        if (!isSettingsControl) {
          return;
        }

        const card = control.closest?.("[data-plugin-name], .admin-plugin");
        if (!cardLooksLikeOurPlugin(card)) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();
        window.location.assign(FIXED_SETTINGS_URL);
      },
      true
    );
  }

  function start() {
    rewriteAll();
    installClickInterceptOnce();

    observer?.disconnect();
    observer = new MutationObserver(() => rewriteAll());
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function stop() {
    observer?.disconnect();
    observer = null;
  }

  api.onPageChange((url) => {
    if (isInstalledPluginsPage(url)) {
      start();
    } else {
      stop();
    }
  });

  if (isInstalledPluginsPage(window.location?.pathname)) {
    start();
  }
});
