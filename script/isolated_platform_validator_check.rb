# frozen_string_literal: true

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
  def present? = !blank?
end
class NilClass; def blank? = true; end
class FalseClass; def blank? = true; end
class TrueClass; def blank? = false; end
class String; def blank? = strip.empty?; end

class SiteSetting
  class << self
    attr_accessor :discourse_social_profile_allow_external_icon_urls
  end
end
SiteSetting.discourse_social_profile_allow_external_icon_urls = false

module DiscourseSocialProfile
  class LinkBuilder
    REGEX_TIMEOUT = 0.05
  end
end

Platform = Struct.new(
  :input_type, :base_url, :allowed_hosts, :path_regex,
  :badge_background, :badge_background_dark, :color, :color_dark,
  :badge_radius, :icon_image_url, :icon_mask_url,
  keyword_init: true
)

require File.expand_path("../lib/discourse_social_profile/platform_validator", __dir__)
PV = DiscourseSocialProfile::PlatformValidator
$passed = 0

def platform(**kw)
  defaults = {
    input_type: "url_any_https", base_url: nil, allowed_hosts: nil, path_regex: nil,
    badge_background: nil, badge_background_dark: nil, color: nil, color_dark: nil,
    badge_radius: nil, icon_image_url: nil, icon_mask_url: nil
  }
  Platform.new(**defaults.merge(kw))
end

def check(name)
  yield
  $passed += 1
  puts "PASS  #{name}"
rescue => e
  warn "FAIL  #{name} — #{e.class}: #{e.message}"
  exit 1
end

def valid!(p)
  r = PV.call(p)
  raise "expected valid, got #{r[:errors].inspect}" unless r[:valid]
end

def invalid!(p, key)
  r = PV.call(p)
  raise "expected #{key} error, got #{r.inspect}" unless !r[:valid] && r[:errors].key?(key)
end

check("url_any_https can omit host allowlist") { valid!(platform) }
check("handle requires base_url") { invalid!(platform(input_type: "handle"), :base_url) }
check("numeric_id requires base_url") { invalid!(platform(input_type: "numeric_id"), :base_url) }
check("url_locked requires allowed_hosts") { invalid!(platform(input_type: "url_locked"), :allowed_hosts) }
check("HTTPS base accepted") { valid!(platform(input_type: "handle", base_url: "https://example.com/u/")) }
check("HTTP base rejected") { invalid!(platform(input_type: "handle", base_url: "http://example.com/u/"), :base_url) }
check("base userinfo rejected") { invalid!(platform(input_type: "handle", base_url: "https://u:p@example.com/u/"), :base_url) }
check("base query rejected") { invalid!(platform(input_type: "handle", base_url: "https://example.com/u/?x=1"), :base_url) }
check("invalid hostname rule rejected") { invalid!(platform(input_type: "url_locked", allowed_hosts: "example.com/path"), :allowed_hosts) }
check("suffix hostname rule accepted") { valid!(platform(input_type: "url_locked", allowed_hosts: ".example.com")) }
check("valid regex accepted") { valid!(platform(path_regex: "^/users/[0-9]+/?$")) }
check("invalid regex rejected") { invalid!(platform(path_regex: "("), :path_regex) }
check("safe CSS color and radius accepted") { valid!(platform(color: "#fff", badge_background_dark: "var(--primary)", badge_radius: "4px 8px")) }
check("unsafe CSS rejected") { invalid!(platform(color: "red;display:none"), :color) }
check("external icon disabled by default") { invalid!(platform(icon_image_url: "https://cdn.example.com/icon.png"), :icon_image_url) }

SiteSetting.discourse_social_profile_allow_external_icon_urls = true
check("safe external image URL accepted when enabled") { valid!(platform(icon_image_url: "https://cdn.example.com/icon.png")) }
check("external icon userinfo rejected") { invalid!(platform(icon_image_url: "https://u:p@cdn.example.com/icon.png"), :icon_image_url) }
check("mask CSS-breaking characters rejected") { invalid!(platform(icon_mask_url: "https://cdn.example.com/a'b.svg"), :icon_mask_url) }

puts "PlatformValidator isolated checks: #{$passed} passed, 0 failed"
