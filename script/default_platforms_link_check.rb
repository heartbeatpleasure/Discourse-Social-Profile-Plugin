# frozen_string_literal: true
class Object
  def blank?; respond_to?(:empty?) ? !!empty? : !self; end
  def present? = !blank?
end
class NilClass; def blank? = true; end
class FalseClass; def blank? = true; end
class TrueClass; def blank? = false; end
class String; def blank? = strip.empty?; end
module LruRedux
  class ThreadSafeCache
    def initialize(_size); @h={}; @m=Mutex.new; end
    def getset(k); @m.synchronize{return @h[k] if @h.key?(k)}; v=yield; @m.synchronize{@h[k]=v}; v; end
  end
end
class EmailAddressValidator
  def self.valid_value?(v) = !!(v.to_s =~ /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
end
require File.expand_path("../lib/discourse_social_profile/default_platforms", __dir__)
require File.expand_path("../lib/discourse_social_profile/link_builder", __dir__)
P = Struct.new(:input_type,:base_url,:allowed_hosts,:path_regex, keyword_init: true)
special = {
  "email" => "a@example.com",
  "linkedin" => "https://www.linkedin.com/in/example",
  "spotify" => "https://open.spotify.com/artist/abc123",
  "bandcamp" => "https://artist.bandcamp.com/",
  "steam" => "https://steamcommunity.com/id/example",
  "mastodon" => "https://mastodon.social/@example",
  "amazon_wishlist" => "https://www.amazon.com/hz/wishlist/ls/ABC123",
  "manyvids" => "https://www.manyvids.com/Profile/1000592171/example",
  "iwantclips" => "https://iwantclips.com/store/1179915/example",
}
passed=0
DiscourseSocialProfile::DefaultPlatforms::DATA.each do |row|
  p=P.new(input_type:row[:input_type],base_url:row[:base_url],allowed_hosts:row[:allowed_hosts],path_regex:row[:path_regex])
  value = special[row[:key]] || (row[:input_type] == "numeric_id" ? "123456" : "example")
  r=DiscourseSocialProfile::LinkBuilder.call(p,value)
  abort "FAIL #{row[:key]} #{value.inspect}: #{r.error_code}" unless r.ok?
  passed += 1
end
puts "Default platform LinkBuilder checks: #{passed} passed, 0 failed"
