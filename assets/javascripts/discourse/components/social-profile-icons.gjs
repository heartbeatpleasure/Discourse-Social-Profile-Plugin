import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const COLOR_PATTERNS = [
  /^#[0-9a-fA-F]{3,8}$/,
  /^[a-zA-Z][a-zA-Z0-9-]{0,31}$/,
  /^(?:rgb|rgba|hsl|hsla)\([0-9.,%\s+-]+\)$/,
  /^var\(--[a-zA-Z0-9_-]+\)$/,
];
const UNSAFE_STYLE = /[\u0000-\u001f\u007f;{}<>]/;
const RADIUS_TOKEN =
  "(?:0|(?:\\d+(?:\\.\\d+)?)(?:px|em|rem|%|vh|vw|vmin|vmax)?|var\\(--[a-zA-Z0-9_-]+\\))";
const RADIUS_PATTERN = new RegExp(
  `^${RADIUS_TOKEN}(?:\\s+${RADIUS_TOKEN}){0,3}(?:\\s*\\/\\s*${RADIUS_TOKEN}(?:\\s+${RADIUS_TOKEN}){0,3})?$`
);
const CONTROL = /[\u0000-\u001f\u007f]/;

function stringValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

function safeColor(value) {
  const candidate = stringValue(value);
  if (!candidate || candidate.length > 128 || UNSAFE_STYLE.test(candidate)) {
    return "";
  }
  return COLOR_PATTERNS.some((pattern) => pattern.test(candidate))
    ? candidate
    : "";
}

function safeRadius(value) {
  const candidate = stringValue(value);
  if (!candidate || candidate.length > 64 || UNSAFE_STYLE.test(candidate)) {
    return "";
  }
  return RADIUS_PATTERN.test(candidate) ? candidate : "";
}

function safeAssetUrl(value) {
  const candidate = stringValue(value);
  if (!candidate || candidate.length > 2048 || CONTROL.test(candidate)) {
    return "";
  }

  if (candidate.startsWith("/") && !candidate.startsWith("//")) {
    return candidate;
  }

  try {
    const parsed = new URL(candidate);
    return parsed.protocol === "https:" && !parsed.username && !parsed.password
      ? candidate
      : "";
  } catch {
    return "";
  }
}

function safeMaskUrl(value) {
  const candidate = safeAssetUrl(value);
  if (!candidate || /['"()\\]/.test(candidate)) {
    return "";
  }
  return candidate;
}

function safeHref(value) {
  const candidate = stringValue(value);
  if (!candidate || candidate.length > 2048 || CONTROL.test(candidate)) {
    return "";
  }

  if (candidate.toLowerCase().startsWith("mailto:")) {
    return candidate;
  }

  try {
    const parsed = new URL(candidate);
    return parsed.protocol === "https:" && !parsed.username && !parsed.password
      ? candidate
      : "";
  } catch {
    return "";
  }
}

function safeClickToken(value) {
  const candidate = stringValue(value);
  return /^[A-Za-z0-9_-]{32}$/.test(candidate) ? candidate : "";
}

export default class SocialProfileIcons extends Component {
  @service interfaceColor;
  @service siteSettings;

  get userModel() {
    return this.args.outletArgs?.user || this.args.outletArgs?.model;
  }

  get links() {
    const links = this.userModel?.social_profiles;
    if (!Array.isArray(links)) {
      return [];
    }

    return links
      .map((link) => this.normalizeLink(link))
      .filter((link) => link !== null);
  }

  normalizeLink(link) {
    try {
      if (!link || typeof link !== "object") {
        return null;
      }

      const href = safeHref(link.href);
      if (!href) {
        return null;
      }

      const key = stringValue(link.key) || "social-profile";
      const label = stringValue(link.label) || "Social profile";
      const iconName = stringValue(link.icon_name) || "globe";
      const imageUrl = safeAssetUrl(link.icon_image_url);
      const maskUrl = safeMaskUrl(link.icon_mask_url);
      const clickToken = safeClickToken(link.click_token);
      const badgeBackground = this.badgeBackgroundFor(link);

      const linkStyle = [
        "display:inline-flex",
        "flex:0 0 auto",
        "align-items:center",
        "justify-content:center",
        "margin:0",
        "text-decoration:none",
        "line-height:1",
        "color:var(--slc-icon-color,var(--slc-global-icon-color,currentColor))",
      ];

      if (this.siteSettings.discourse_social_profile_use_platform_colors) {
        const light = safeColor(link.color);
        const dark = safeColor(link.color_dark);
        const selected = this.isDarkScheme ? dark || light : light;
        if (selected) {
          linkStyle.push(`--slc-icon-color:${selected}`);
        }
      }

      if (badgeBackground) {
        linkStyle.push(`--slc-badge-bg:${badgeBackground}`);
      }

      const radius = safeRadius(link.badge_radius);
      if (radius) {
        linkStyle.push(`--slc-badge-radius:${radius}`);
      }

      if (maskUrl) {
        linkStyle.push(`--slc-icon-mask:url('${maskUrl}')`);
      }

      const frameStyle = [
        "display:inline-flex",
        "align-items:center",
        "justify-content:center",
        "flex:0 0 auto",
        "color:var(--slc-icon-color,var(--slc-global-icon-color,currentColor))",
        "font-size:1.2em",
        "line-height:1",
      ];

      if (badgeBackground) {
        frameStyle.push(
          "width:1.2em",
          "height:1.2em",
          "background-color:var(--slc-badge-bg)",
          "border-radius:var(--slc-badge-radius,0.25em)"
        );
      }

      const maskStyle = maskUrl
        ? htmlSafe(
            [
              "display:block",
              "width:1.2em",
              "height:1.2em",
              "flex:0 0 1.2em",
              "background-color:var(--slc-icon-color,var(--slc-global-icon-color,currentColor))",
              ...(this.siteSettings.discourse_social_profile_use_platform_colors
                ? []
                : ["opacity:0.45"]),
              `-webkit-mask:url('${maskUrl}') no-repeat center / contain`,
              `mask:url('${maskUrl}') no-repeat center / contain`,
            ].join(";")
          )
        : null;

      return {
        key,
        href,
        label,
        clickToken,
        iconName,
        imageUrl,
        maskUrl,
        frameClass: badgeBackground
          ? "slc-icon-frame slc-badge"
          : "slc-icon-frame",
        linkStyle: htmlSafe(linkStyle.join(";")),
        frameStyle: htmlSafe(frameStyle.join(";")),
        maskStyle,
      };
    } catch {
      return null;
    }
  }

  @action
  trackClick(clickToken) {
    if (!clickToken) {
      return;
    }

    // Analytics must never become part of navigation. The anchor already points
    // directly at the external profile; this same-origin POST is best-effort only.
    ajax(getURL("/social-profile/click.json"), {
      type: "POST",
      data: { social_profile_click_token: clickToken },
    }).catch(() => {});
  }

  get isDarkScheme() {
    if (this.interfaceColor?.colorModeIsDark) {
      return true;
    }
    if (this.interfaceColor?.colorModeIsLight) {
      return false;
    }

    if (typeof document !== "undefined") {
      try {
        const schemeType = getComputedStyle(document.documentElement)
          .getPropertyValue("--scheme-type")
          .trim()
          .toLowerCase();
        if (schemeType === "dark") {
          return true;
        }
        if (schemeType === "light") {
          return false;
        }
      } catch {
        return false;
      }
    }

    return false;
  }

  get containerStyle() {
    const light = safeColor(
      this.siteSettings.discourse_social_profile_icon_color
    );
    const dark = safeColor(
      this.siteSettings.discourse_social_profile_icon_color_dark
    );
    const selected = this.isDarkScheme ? dark || light : light;
    const styles = [
      "display:flex",
      "flex-direction:row",
      "flex-wrap:wrap",
      "align-items:center",
      "gap:5px",
      "width:100%",
      "min-width:0",
    ];
    if (selected) {
      styles.push(`--slc-global-icon-color:${selected}`, `color:${selected}`);
    }
    return htmlSafe(styles.join(";"));
  }

  badgeBackgroundFor(link) {
    const light = safeColor(link.badge_background);
    const dark = safeColor(link.badge_background_dark);
    return this.isDarkScheme ? dark || light : light;
  }

  <template>
    {{#if this.links.length}}
      <div
        class="iconic-user-fields social-profile-icons"
        style={{this.containerStyle}}
        data-social-profile-count={{this.links.length}}
      >
        {{#each this.links as |link|}}
          <a
            href={{link.href}}
            rel="nofollow noopener noreferrer"
            target="_blank"
            title={{link.label}}
            aria-label={{link.label}}
            referrerpolicy="no-referrer"
            data-social-platform={{link.key}}
            data-click-tracking={{if link.clickToken "true" "false"}}
            style={{link.linkStyle}}
            {{on "click" (fn this.trackClick link.clickToken)}}
          >
            <span class={{link.frameClass}} style={{link.frameStyle}}>
              {{#if link.imageUrl}}
                <img
                  class="slc-image-icon"
                  src={{link.imageUrl}}
                  alt=""
                  aria-hidden="true"
                  referrerpolicy="no-referrer"
                  width="24"
                  height="24"
                  style="display:block;width:1.2em;height:1.2em;object-fit:contain;"
                />
              {{else if link.maskUrl}}
                <span
                  class="slc-custom-icon"
                  aria-hidden="true"
                  style={{link.maskStyle}}
                ></span>
              {{else}}
                {{dIcon link.iconName}}
              {{/if}}
            </span>
          </a>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
