import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
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

  // Click tracking intentionally uses a same-origin relative path. Allow a
  // normal single-slash path so Discourse subfolder installs are supported.
  if (candidate.startsWith("/") && !candidate.startsWith("//")) {
    return candidate;
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

    // Never let one malformed serialized item break a user profile or card.
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

      const label = stringValue(link.label) || "Social profile";
      const iconName = stringValue(link.icon_name) || "globe";
      const imageUrl = safeAssetUrl(link.icon_image_url);
      const maskUrl = safeMaskUrl(link.icon_mask_url);
      const badgeBackground = this.badgeBackgroundFor(link);

      const style = [];
      if (this.siteSettings.discourse_social_profile_use_platform_colors) {
        const light = safeColor(link.color);
        const dark = safeColor(link.color_dark);
        const selected = this.isDarkScheme ? dark || light : light;
        if (selected) {
          style.push(`--slc-icon-color:${selected};`);
        }
      }

      if (badgeBackground) {
        style.push(`--slc-badge-bg:${badgeBackground};`);
      }

      const radius = safeRadius(link.badge_radius);
      if (radius) {
        style.push(`--slc-badge-radius:${radius};`);
      }

      if (maskUrl) {
        style.push(`--slc-icon-mask:url('${maskUrl}');`);
      }

      return {
        href,
        label,
        iconName,
        imageUrl,
        maskUrl,
        frameClass: badgeBackground
          ? "slc-icon-frame slc-badge"
          : "slc-icon-frame",
        style: htmlSafe(style.join(" ")),
      };
    } catch {
      return null;
    }
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
    return htmlSafe(
      selected ? `--slc-global-icon-color:${selected};` : ""
    );
  }

  badgeBackgroundFor(link) {
    const light = safeColor(link.badge_background);
    const dark = safeColor(link.badge_background_dark);
    return this.isDarkScheme ? dark || light : light;
  }

  <template>
    {{#if this.links.length}}
      <div class="iconic-user-fields" style={{this.containerStyle}}>
        {{#each this.links as |link|}}
          <a
            href={{link.href}}
            rel="nofollow noopener noreferrer"
            target="_blank"
            title={{link.label}}
            aria-label={{link.label}}
            referrerpolicy="no-referrer"
            style={{link.style}}
          >
            <span class={{link.frameClass}}>
              {{#if link.imageUrl}}
                <img
                  class="slc-image-icon"
                  src={{link.imageUrl}}
                  alt=""
                  aria-hidden="true"
                  referrerpolicy="no-referrer"
                />
              {{else if link.maskUrl}}
                <span class="slc-custom-icon" aria-hidden="true"></span>
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
