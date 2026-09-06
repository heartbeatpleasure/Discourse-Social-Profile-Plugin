# frozen_string_literal: true

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
end
class NilClass; def blank? = true; end
class FalseClass; def blank? = true; end
class TrueClass; def blank? = false; end
class String; def blank? = strip.empty?; end

require File.expand_path("../lib/discourse_social_profile/url_safety", __dir__)
US = DiscourseSocialProfile::UrlSafety
$passed = 0

def check(name)
  yield
  $passed += 1
  puts "PASS  #{name}"
rescue => e
  warn "FAIL  #{name} — #{e.class}: #{e.message}"
  exit 1
end

def public!(*hosts)
  hosts.each { |host| raise "expected public #{host}" unless US.public_host?(host) }
end

def blocked!(*hosts)
  hosts.each { |host| raise "expected blocked #{host}" if US.public_host?(host) }
end

check("normal public DNS") { public!("example.com", "social.example.com", "xn--bcher-kva.de") }
check("public IP literals") { public!("8.8.8.8", "1.1.1.1", "2606:4700:4700::1111") }
check("loopback and unspecified") { blocked!("0.0.0.0", "127.0.0.1", "::", "::1") }
check("RFC1918 and link local") { blocked!("10.0.0.1", "172.16.0.1", "192.168.1.1", "169.254.169.254", "fe80::1", "fc00::1") }
check("CGNAT and benchmark") { blocked!("100.64.0.1", "198.18.0.1") }
check("documentation and reserved networks") { blocked!("192.0.2.1", "198.51.100.1", "203.0.113.1", "2001:db8::1") }
check("IPv4-mapped and transition forms") { blocked!("::ffff:127.0.0.1", "64:ff9b::c0a8:101", "2002:c0a8:0101::1") }
check("browser ambiguous IPv4 spellings") { blocked!("127.1", "0177.0.0.1", "0x7f000001", "2130706433") }
check("local and special-use DNS names") { blocked!("localhost", "router.local", "service.internal", "gateway.lan", "home.arpa", "foo.test", "foo.invalid", "foo.onion") }
check("single-label and malformed DNS") { blocked!("intranet", "-bad.example", "bad-.example", "bad_name.example", "example..com") }
check("normalization cannot rescue blocked hosts") { blocked!("LOCALHOST.", "[::1]") }
check("deeply encoded controls are rejected") do
  %w[%0a %250a %25250a %2525250a %252525250d].each do |value|
    raise "expected unsafe #{value}" unless US.unsafe_control_encoding?("https://example.com/#{value}")
  end
end
check("ordinary percent encoding is not treated as a control") do
  raise "false positive" if US.unsafe_control_encoding?("https://example.com/a%20b%2520c")
end

puts "UrlSafety isolated checks: #{$passed} passed, 0 failed"
