# frozen_string_literal: true
class Object
  def blank?; respond_to?(:empty?) ? !!empty? : !self; end
  def present? = !blank?
end
class NilClass; def blank? = true; end
class FalseClass; def blank? = true; end
class TrueClass; def blank? = false; end
class String; def blank? = strip.empty?; end
class SiteSetting
  def self.discourse_social_profile_allow_external_icon_urls = false
end
module DiscourseSocialProfile
  class LinkBuilder
    REGEX_TIMEOUT = 0.05
  end
end
require File.expand_path("../lib/discourse_social_profile/default_platforms", __dir__)
require File.expand_path("../lib/discourse_social_profile/platform_validator", __dir__)
Attrs = Struct.new(:input_type,:base_url,:allowed_hosts,:path_regex,:badge_background,:badge_background_dark,:color,:color_dark,:badge_radius,:icon_image_url,:icon_mask_url, keyword_init: true)
passed=0
DiscourseSocialProfile::DefaultPlatforms::DATA.each do |row|
  p = Attrs.new(**row.slice(:input_type,:base_url,:allowed_hosts,:path_regex,:badge_background,:badge_background_dark,:color,:color_dark,:badge_radius).merge(icon_image_url:nil,icon_mask_url:nil))
  r=DiscourseSocialProfile::PlatformValidator.call(p)
  abort "FAIL #{row[:key]} #{r[:errors].inspect}" unless r[:valid]
  passed += 1
end
puts "Default platform validator checks: #{passed} passed, 0 failed"
