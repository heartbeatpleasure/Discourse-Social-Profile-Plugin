# frozen_string_literal: true

require "ipaddr"
require "uri"

module ::DiscourseSocialProfile
  module UrlSafety
    BLOCKED_HOSTS = %w[localhost localhost.localdomain home.arpa].freeze
    BLOCKED_SUFFIXES = %w[
      .localhost .local .localdomain .internal .lan .home.arpa .test .invalid
      .example .onion .alt .arpa .svc
    ].freeze
    DNS_LABEL = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/i
    AMBIGUOUS_IPV4 = /\A(?:0x[0-9a-f]+|[0-9]+)(?:\.(?:0x[0-9a-f]+|[0-9]+))*\z/i
    CONTROL = /[\u0000-\u001F\u007F]/
    ENCODED_CONTROL = /%(?:0[0-9a-f]|1[0-9a-f]|7f)/i
    MAX_DECODE_PASSES = 16

    BLOCKED_NETWORKS = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.0.0.0/24"),
      IPAddr.new("192.0.2.0/24"),
      IPAddr.new("192.88.99.0/24"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("198.18.0.0/15"),
      IPAddr.new("198.51.100.0/24"),
      IPAddr.new("203.0.113.0/24"),
      IPAddr.new("224.0.0.0/4"),
      IPAddr.new("240.0.0.0/4"),
      IPAddr.new("::/96"),
      IPAddr.new("::/128"),
      IPAddr.new("::1/128"),
      IPAddr.new("::ffff:0:0/96"),
      IPAddr.new("64:ff9b::/96"),
      IPAddr.new("64:ff9b:1::/48"),
      IPAddr.new("100::/64"),
      IPAddr.new("100:0:0:1::/64"),
      IPAddr.new("2001::/32"),
      IPAddr.new("2001:2::/48"),
      IPAddr.new("2001:10::/28"),
      IPAddr.new("2001:20::/28"),
      IPAddr.new("2001:db8::/32"),
      IPAddr.new("2002::/16"),
      IPAddr.new("3fff::/20"),
      IPAddr.new("5f00::/16"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10"),
      IPAddr.new("fec0::/10"),
      IPAddr.new("ff00::/8"),
    ].freeze

    module_function

    # This plugin never performs server-side requests to social-profile or icon URLs.
    # Still, rejecting obvious local/private destinations prevents profile links or
    # automatic icon loads from being used to target browser-local/private services.
    def public_host?(host)
      normalized = normalize_host(host)
      return false if normalized.blank? || !normalized.ascii_only?
      return false if BLOCKED_HOSTS.include?(normalized)
      return false if BLOCKED_SUFFIXES.any? { |suffix| normalized.end_with?(suffix) }

      ip = parse_ip(normalized)
      return globally_routable_ip?(ip) if ip

      # Browsers accept historical shorthand/octal/hex IPv4 forms (for example
      # 127.1 or 0177.0.0.1) which Ruby IPAddr does not. Reject numeric-looking
      # non-canonical hosts so browser URL normalization cannot turn an apparently
      # public hostname into a loopback/private address.
      return false if normalized.match?(AMBIGUOUS_IPV4)

      # Public DNS names contain at least one label separator. Single-label names
      # resolve through local search domains on many networks and are inappropriate
      # for public social-profile destinations. Enforce normal DNS label syntax as
      # additional protection against parser differences between Ruby and browsers.
      return false unless normalized.include?(".")
      return false if normalized.bytesize > 253

      labels = normalized.split(".", -1)
      labels.all? { |label| label.match?(DNS_LABEL) }
    end


    # Reject raw or recursively percent-encoded ASCII controls. Repeated decoding
    # matters because browser/application stacks can contain more than one URL
    # decoding layer; a shallow check such as %250a -> %0a is insufficient. The
    # input surfaces are bounded to 2048 bytes, so 16 normalization passes remain
    # inexpensive while covering realistic nested encodings.
    def unsafe_control_encoding?(value)
      decoded = value.to_s
      return true if decoded.match?(CONTROL) || decoded.match?(ENCODED_CONTROL)

      MAX_DECODE_PASSES.times do
        next_value = URI::DEFAULT_PARSER.unescape(decoded)
        return true if next_value.match?(CONTROL)
        break if next_value == decoded
        decoded = next_value
      end

      false
    rescue ArgumentError, Encoding::CompatibilityError
      true
    end

    def normalize_host(host)
      host.to_s.strip.downcase.chomp(".").delete_prefix("[").delete_suffix("]")
    end

    def parse_ip(host)
      IPAddr.new(host)
    rescue IPAddr::InvalidAddressError
      nil
    end

    def globally_routable_ip?(ip)
      BLOCKED_NETWORKS.none? { |network| network.include?(ip) }
    end
  end
end
