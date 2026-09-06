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

module LruRedux
  class ThreadSafeCache
    def initialize(_size); @h = {}; @m = Mutex.new; end
    def getset(key)
      @m.synchronize { return @h[key] if @h.key?(key) }
      value = yield
      @m.synchronize { @h[key] = value }
      value
    end
  end
end

class EmailAddressValidator
  RE = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
  def self.valid_value?(v) = !!(v.to_s =~ RE)
end

Platform = Struct.new(:input_type, :base_url, :allowed_hosts, :path_regex, keyword_init: true)
require File.expand_path("../lib/discourse_social_profile/url_safety", __dir__)
require File.expand_path("../lib/discourse_social_profile/link_builder", __dir__)

LB = DiscourseSocialProfile::LinkBuilder
$passed = 0

def platform(type:, base: nil, hosts: nil, regex: nil)
  Platform.new(input_type: type, base_url: base, allowed_hosts: hosts, path_regex: regex)
end

def check(name)
  yield
  $passed += 1
  puts "PASS  #{name}"
rescue => e
  warn "FAIL  #{name} — #{e.class}: #{e.message}"
  exit 1
end

def ok!(result, href: nil, value: nil)
  raise "expected ok, got #{result.error_code}" unless result.ok?
  raise "href #{result.href.inspect} != #{href.inspect}" if href && result.href != href
  raise "value #{result.canonical_value.inspect} != #{value.inspect}" if value && result.canonical_value != value
end

def fail!(result, code)
  raise "expected failure #{code}, got ok #{result.href}" if result.ok?
  raise "error #{result.error_code.inspect} != #{code.inspect}" unless result.error_code == code.to_s
end

check("email happy path") { ok!(LB.call(platform(type: "email"), "a@example.com"), href: "mailto:a@example.com", value: "a@example.com") }
check("email rejects URL") { fail!(LB.call(platform(type: "email"), "https://example.com"), :invalid_email) }
check("email rejects slash") { fail!(LB.call(platform(type: "email"), "a@example.com/x"), :invalid_email) }
check("handle encodes spaces after normalization") { ok!(LB.call(platform(type: "handle", base: "https://example.com/u/"), " @a b "), href: "https://example.com/u/ab", value: "ab") }
check("handle UTF-8 safely encodes") { ok!(LB.call(platform(type: "handle", base: "https://example.com/u/"), "münchen"), href: "https://example.com/u/m%C3%BCnchen", value: "münchen") }
check("handle rejects slash") { fail!(LB.call(platform(type: "handle", base: "https://example.com/u/"), "a/b"), :invalid_handle) }
check("handle rejects alternate scheme") { fail!(LB.call(platform(type: "handle", base: "https://example.com/u/"), "javascript:alert"), :invalid_protocol) }
check("numeric happy path") { ok!(LB.call(platform(type: "numeric_id", base: "https://example.com/users/"), "00123"), href: "https://example.com/users/00123", value: "00123") }
check("numeric rejects letters") { fail!(LB.call(platform(type: "numeric_id", base: "https://example.com/users/"), "12x"), :invalid_numeric_id) }
check("generated base must be HTTPS") { fail!(LB.call(platform(type: "handle", base: "http://example.com/u/"), "alice"), :invalid_base_url) }
check("generated base rejects userinfo") { fail!(LB.call(platform(type: "handle", base: "https://u:p@example.com/u/"), "alice"), :invalid_base_url) }
check("generated base rejects query") { fail!(LB.call(platform(type: "handle", base: "https://example.com/u/?x=1"), "alice"), :invalid_base_url) }
check("full handle URL allowed by exact host") { ok!(LB.call(platform(type: "handle", base: "https://example.com/u/", hosts: "example.com"), "https://example.com/u/alice"), href: "https://example.com/u/alice", value: "https://example.com/u/alice") }
check("full handle URL rejects HTTP") { fail!(LB.call(platform(type: "handle", base: "https://example.com/u/", hosts: "example.com"), "http://example.com/u/alice"), :invalid_protocol) }
check("full handle URL requires allowlist") { fail!(LB.call(platform(type: "handle", base: "https://example.com/u/"), "https://example.com/u/alice"), :invalid_host) }
check("exact host does not allow evil suffix") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com"), "https://evil-example.com/u"), :invalid_host) }
check("suffix host allows subdomain") { ok!(LB.call(platform(type: "url_locked", hosts: ".example.com"), "https://a.b.example.com/u"), href: "https://a.b.example.com/u") }
check("suffix host also allows apex") { ok!(LB.call(platform(type: "url_locked", hosts: ".example.com"), "https://example.com/u"), href: "https://example.com/u") }
check("trailing host dot canonicalizes") { ok!(LB.call(platform(type: "url_locked", hosts: "example.com"), "https://EXAMPLE.com./u"), href: "https://example.com/u") }
check("default 443 canonicalizes away") { ok!(LB.call(platform(type: "url_locked", hosts: "example.com"), "https://example.com:443/u"), href: "https://example.com/u") }
check("nondefault port rejected") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com"), "https://example.com:444/u"), :invalid_host) }
check("loopback destinations rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://127.0.0.1/profile"), :invalid_host) }
check("private network destinations rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://10.0.0.5/profile"), :invalid_host) }
check("local hostname destinations rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://localhost/profile"), :invalid_host) }
check("browser shorthand loopback rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://2130706433/profile"), :invalid_host) }
check("IPv4-mapped IPv6 destination rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://[::ffff:127.0.0.1]/profile"), :invalid_host) }
check("NAT64 private destination rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://[64:ff9b::c0a8:101]/profile"), :invalid_host) }
check("path regex happy path") { ok!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/\\d+/?$'), "https://example.com/users/123")) }
check("path regex mismatch") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/\\d+/?$'), "https://example.com/users/alice"), :invalid_path) }
check("encoded slash cannot bypass strict path regex") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/[^/]+/?$'), "https://example.com/users/alice%2Fadmin"), :invalid_path) }
check("double encoded slash cannot bypass strict path regex") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/[^/]+/?$'), "https://example.com/users/alice%252Fadmin"), :invalid_path) }
check("encoded backslash cannot bypass strict path regex") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/[^/]+/?$'), "https://example.com/users/alice%5Cadmin"), :invalid_path) }
check("invalid regex fails closed") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: "("), "https://example.com/users/1"), :invalid_regex) }
check("dot segments normalized before path regex") { ok!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/safe/profile$'), "https://example.com/a/../safe/profile"), href: "https://example.com/safe/profile") }
check("percent encoded dot segments normalized") { ok!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/safe/profile$'), "https://example.com/a/%2e%2e/safe/profile"), href: "https://example.com/safe/profile") }
check("nested URL path redirector rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/out/https://evil.test"), :invalid_url) }
check("nested URL query rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/?url=https%3A%2F%2Fevil.test"), :invalid_url) }
check("double encoded nested URL rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/?next=https%253A%252F%252Fevil.test"), :invalid_url) }
check("ordinary query preserved") { ok!(LB.call(platform(type: "url_any_https"), "https://example.com/profile?tab=about#bio"), href: "https://example.com/profile?tab=about#bio") }
check("protocol-relative rejected") { fail!(LB.call(platform(type: "url_any_https"), "//example.com/u"), :invalid_protocol) }
check("encoded control rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/a%0d%0aX"), :invalid_value) }
check("deeply encoded control rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/a%252525250aX"), :invalid_value) }
check("deeply encoded slash cannot bypass strict path regex") { fail!(LB.call(platform(type: "url_locked", hosts: "example.com", regex: '^/users/[^/]+/?$'), "https://example.com/users/alice%2525252Fadmin"), :invalid_path) }
check("deeply encoded nested URL rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/?next=https%2525253A%2525252F%2525252Fevil.test"), :invalid_url) }
check("dot-segment handle rejected") { fail!(LB.call(platform(type: "handle", base: "https://example.com/users/", hosts: "example.com"), ".."), :invalid_handle) }
check("encoded dot-segment handle rejected") { fail!(LB.call(platform(type: "handle", base: "https://example.com/users/", hosts: "example.com"), "%252e%252e"), :invalid_handle) }
check("encoded handle separator rejected") { fail!(LB.call(platform(type: "handle", base: "https://example.com/users/", hosts: "example.com"), "alice%252Fadmin"), :invalid_handle) }
check("backslash nested redirect rejected") { fail!(LB.call(platform(type: "url_any_https"), "https://example.com/?next=https:%255c%255cevil.test"), :invalid_url) }
check("blank rejected") { fail!(LB.call(platform(type: "url_any_https"), "  \t"), :blank) }

puts "LinkBuilder isolated checks: #{$passed} passed, 0 failed"
