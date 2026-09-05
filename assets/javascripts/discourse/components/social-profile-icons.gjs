import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const COLOR_PATTERNS = [
  /^#[0-9a-fA-F]{3,8}$/,
  /^[a-zA-Z][a-zA-Z0-9-]{0,31}$/,
  /^(?:rgb|rgba|hsl|hsla)\([0-9.,%\s+-]+\)$/,
  /^var\(--[a-zA-Z0-9_-]+\)$/,
];
const UNSAFE_STYLE = /[\u0000-\u001f\u007f;{}<>]/;
const RADIUS_TOKEN = "(?:0|(?:\\d+(?:\\.\\d+)?)(?:px|em|rem|%|vh|vw|vmin|vmax)?|var\\(--[a-zA-Z0-9_-]+\\))";
const RADIUS_PATTERN = new RegExp(
  `^${RADIUS_TOKEN}(?:\\s+${RADIUS_TOKEN}){0,3}(?:\\s*\\/\\s*${RADIUS_TOKEN}(?:\\s+${RADIUS_TOKEN}){0,3})?$`
);

function safeColor(value) {
  const candidate = (value || "").trim();
  if (!candidate || candidate.length > 128 || UNSAFE_STYLE.test(candidate)) {
    return "";
  }
  return COLOR_PATTERNS.some((pattern) => pattern.test(candidate)) ? candidate : "";
}

function safeRadius(value) {
  const candidate = (value || "").trim();
  if (!candidate || candidate.length > 64 || UNSAFE_STYLE.test(candidate)) {
    return "";
  }
  return RADIUS_PATTERN.test(candidate) ? candidate : "";
}

function safeMaskUrl(value) {
  const candidate = (value || "").trim();
  if (
    !candidate ||
    candidate.length > 2048 ||
    /[\u0000-\u001f\u007f'"()\\]/.test(candidate)
  ) {
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

export default class SocialProfileIcons extends Component {
  @service interfaceColor;
  @service siteSettings;
  @tracked systemDark = false;

  mediaQuery = null;
  mediaListener = null;

  constructor() {
    super(...arguments);
    if (typeof window !== "undefined" && window.matchMedia) {
      this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
      this.systemDark = this.mediaQuery.matches;
      this.mediaListener = (event) => (this.systemDark = event.matches);
      this.mediaQuery.addEventListener?.("change", this.mediaListener);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.mediaQuery?.removeEventListener?.("change", this.mediaListener);
  }

  get userModel() {
    return this.args.outletArgs?.user || this.args.outletArgs?.model;
  }

  get links() {
    return this.userModel?.social_profiles || [];
  }

  get isDarkScheme() {
    if (this.interfaceColor?.colorModeIsDark) {
      return true;
    }
    if (this.interfaceColor?.colorModeIsLight) {
      return false;
    }
    if (this.interfaceColor?.colorModeIsAuto) {
      return this.systemDark;
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
        // Fall through to the system media preference.
      }
    }
    return this.systemDark;
  }

  get containerStyle() {
    const light = safeColor(this.siteSettings.discourse_social_profile_icon_color);
    const dark = safeColor(this.siteSettings.discourse_social_profile_icon_color_dark);
    const selected = this.isDarkScheme ? dark || light : light;
    return selected ? `--slc-global-icon-color:${selected};` : "";
  }

  styleFor(link) {
    const style = [];
    if (this.siteSettings.discourse_social_profile_use_platform_colors) {
      const light = safeColor(link.color);
      const dark = safeColor(link.color_dark);
      const selected = this.isDarkScheme ? dark || light : light;
      if (selected) {
        style.push(`--slc-icon-color:${selected};`);
      }
    }

    const badge = this.badgeBackgroundFor(link);
    if (badge) {
      style.push(`--slc-badge-bg:${badge};`);
    }

    const radius = safeRadius(link.badge_radius);
    if (radius) {
      style.push(`--slc-badge-radius:${radius};`);
    }

    const maskUrl = safeMaskUrl(link.icon_mask_url);
    if (maskUrl) {
      style.push(`--slc-icon-mask:url('${maskUrl}');`);
    }
    return style.join(" ");
  }

  badgeBackgroundFor(link) {
    const light = safeColor(link.badge_background);
    const dark = safeColor(link.badge_background_dark);
    return this.isDarkScheme ? dark || light : light;
  }

  frameClass(link) {
    return this.badgeBackgroundFor(link)
      ? "slc-icon-frame slc-badge"
      : "slc-icon-frame";
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
            style={{this.styleFor link}}
          >
            <span class={{this.frameClass link}}>
              {{#if link.icon_image_url}}
                <img
                  class="slc-image-icon"
                  src={{link.icon_image_url}}
                  alt=""
                  aria-hidden="true"
                  referrerpolicy="no-referrer"
                />
              {{else if link.icon_mask_url}}
                <span class="slc-custom-icon" aria-hidden="true"></span>
              {{else}}
                {{dIcon link.icon_name}}
              {{/if}}
            </span>
          </a>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
