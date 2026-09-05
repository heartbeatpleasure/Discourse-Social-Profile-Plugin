import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import getURL from "discourse/lib/get-url";

/**
 * The Social Profile plugin deliberately uses a dashboard as its admin entry
 * point. On the Installed Plugins page, route this plugin's Settings control
 * to that dashboard as well. The actual Site Settings remain available from
 * the dashboard's Open settings button/card.
 *
 * The exact data-plugin-setting-button selector is provided by current
 * Discourse. The plugin-card fallback mirrors the compatibility approach used
 * by the other working custom admin plugins on this installation.
 */
export default apiInitializer("0.11.1", (api) => {
  const PLUGIN_DISPLAY_NAME = "Discourse-Social-Profile-Plugin";
  const ADMIN_PLUGINS_PATH = getURL("/admin/plugins");
  const OVERVIEW_URL = getURL("/admin/plugins/social-profile");
  const SETTINGS_BUTTON_SELECTOR =
    `[data-plugin-setting-button="${PLUGIN_DISPLAY_NAME}"]`;

  let observer = null;
  let clickHandlerInstalled = false;

  function normalizedPath(url) {
    return (url || "")
      .split("?")[0]
      .replace(/\/+$/, "");
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
      card.querySelector?.(
        'a[href*="Discourse-Social-Profile-Plugin"]'
      )
    );
  }

  function rewriteExactSettingsButtons() {
    for (const button of document.querySelectorAll(SETTINGS_BUTTON_SELECTOR)) {
      if (button.dataset.socialProfileOverviewFixed === "1") {
        continue;
      }

      button.setAttribute("href", OVERVIEW_URL);
      button.dataset.socialProfileOverviewFixed = "1";
    }
  }

  function rewriteSettingsLinkInCard(card) {
    if (!cardLooksLikeOurPlugin(card)) {
      return;
    }

    const candidates = Array.from(
      card.querySelectorAll(
        'a[href*="/admin/site_settings"], a[href*="/admin/plugins/"][data-plugin-setting-button]'
      )
    );

    for (const control of candidates) {
      if (control.dataset.socialProfileOverviewFixed === "1") {
        continue;
      }

      control.setAttribute("href", OVERVIEW_URL);
      control.dataset.socialProfileOverviewFixed = "1";
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
          window.location.assign(OVERVIEW_URL);
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
        window.location.assign(OVERVIEW_URL);
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
