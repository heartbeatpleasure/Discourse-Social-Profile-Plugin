import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const CONTROL = /[\u0000-\u001f\u007f]/;

function safeAssetUrl(value) {
  const candidate = (value || "").trim();
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

export default class SocialProfilePlatformIcon extends Component {
  get imageUrl() {
    return safeAssetUrl(this.args.imageUrl);
  }

  get maskStyle() {
    const url = safeMaskUrl(this.args.maskUrl);
    if (!url) {
      return "";
    }

    return [
      "display:inline-block",
      "width:24px",
      "height:24px",
      "background:currentColor",
      `-webkit-mask:url('${url}') no-repeat center / contain`,
      `mask:url('${url}') no-repeat center / contain`,
    ].join(";");
  }

  get iconName() {
    return this.args.iconName || "globe";
  }

  <template>
    <span class="social-profile-platform-icon" aria-hidden="true">
      {{#if this.imageUrl}}
        <img
          class="social-profile-platform-icon__image"
          src={{this.imageUrl}}
          alt=""
          width="24"
          height="24"
          referrerpolicy="no-referrer"
        />
      {{else if this.maskStyle}}
        <span
          class="social-profile-platform-icon__mask"
          style={{this.maskStyle}}
        ></span>
      {{else}}
        {{dIcon this.iconName}}
      {{/if}}
    </span>
  </template>
}
