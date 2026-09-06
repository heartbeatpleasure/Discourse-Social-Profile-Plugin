# frozen_string_literal: true

require "uri"
require "timeout"

module ::DiscourseSocialProfile
  class LinkBuilder
    Result = Struct.new(:ok?, :href, :canonical_value, :error_code, :matched_host, :matched_path, keyword_init: true)

    MAX_URL = 2048
    MAX_HANDLE = 255
    MAX_NUMERIC = 64
    MAX_EMAIL = 320
    REGEX_TIMEOUT = 0.05
    REGEX_CACHE_SIZE = 256
    SCHEME_PREFIX = /\A[a-z][a-z0-9+.-]*:/i
    HANDLE_FORBIDDEN = /[\/\\:?#]/
    CONTROL = /[\u0000-\u001F\u007F]/
    MAX_REDIRECT_DECODE_PASSES = ::DiscourseSocialProfile::UrlSafety::MAX_DECODE_PASSES
    REDIRECT_QUERY_KEYS = %w[
      u url target redirect redirect_url redirect_uri redirect_to next continue dest destination
      to out away return return_to return_url go
    ].freeze
    REDIRECT_PATH_BASENAMES = %w[l.php redirect redirect.php redirector out away url go].freeze

    def self.call(platform, value)
      new(platform, value).call
    end

    def self.compiled_path_regex(pattern)
      @path_regex_cache ||= LruRedux::ThreadSafeCache.new(REGEX_CACHE_SIZE)
      @path_regex_cache.getset(pattern.to_s) do
        Regexp.new(pattern.to_s, timeout: REGEX_TIMEOUT)
      end
    end

    def initialize(platform, value)
      @platform = platform
      @raw = value.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    end

    def call
      return failure(:blank) if @raw.blank?
      return failure(:too_long) if @raw.length > MAX_URL
      return failure(:invalid_value) if ::DiscourseSocialProfile::UrlSafety.unsafe_control_encoding?(@raw)

      case @platform.input_type
      when "email" then build_email
      when "handle" then build_identifier(numeric: false)
      when "numeric_id" then build_identifier(numeric: true)
      when "url_locked" then validate_url(@raw, hosts_required: true)
      when "url_any_https" then validate_url(@raw, hosts_required: false)
      else failure(:invalid_input_type)
      end
    end

    private

    def build_email
      return failure(:too_long) if @raw.length > MAX_EMAIL
      return failure(:invalid_email) if @raw.match?(SCHEME_PREFIX)
      return failure(:invalid_email) if @raw.match?(/[?#\/]/)
      return failure(:invalid_email) unless EmailAddressValidator.valid_value?(@raw)

      success("mailto:#{@raw}", @raw)
    end

    def build_identifier(numeric:)
      # Theme Component parity: a complete HTTP(S) value is treated as a URL,
      # not converted back into a base_url + identifier value. HTTP then fails
      # the plugin's HTTPS-only hardening in validate_url.
      return validate_url(@raw, hosts_required: true) if @raw.match?(/\Ahttps?:\/\//i)
      return failure(:invalid_protocol) if @raw.match?(SCHEME_PREFIX)

      normalized = normalize_identifier(@raw, numeric: numeric)
      return normalized if normalized.is_a?(Result)

      build_identifier_value(normalized)
    end

    def normalize_identifier(value, numeric:)
      normalized = value.to_s.sub(/\A@/, "").gsub(/[[:space:]]+/, "")
      limit = numeric ? MAX_NUMERIC : MAX_HANDLE
      return failure(:too_long) if normalized.length > limit
      return failure(numeric ? :invalid_numeric_id : :invalid_handle) if normalized.blank?
      return failure(:invalid_handle) if normalized.match?(HANDLE_FORBIDDEN)
      return failure(:invalid_numeric_id) if numeric && !normalized.match?(/\A\d+\z/)

      unless numeric
        decoded = repeatedly_percent_decode(normalized)
        return failure(:invalid_handle) unless decoded.valid_encoding?
        return failure(:invalid_handle) if %w[. ..].include?(decoded) || decoded.match?(HANDLE_FORBIDDEN)
      end

      normalized
    end

    def build_identifier_value(normalized)
      base_uri = safe_https_uri(@platform.base_url)
      return failure(:invalid_base_url) unless valid_base_uri?(base_uri)

      encoded = URI.encode_www_form_component(normalized).gsub("+", "%20")
      candidate = "#{@platform.base_url}#{encoded}"
      result = validate_url(candidate, hosts_required: false, generated: true)
      return result unless result.ok?

      result.canonical_value = normalized
      result
    end

    def validate_url(value, hosts_required:, generated: false)
      return failure(:too_long) if value.length > MAX_URL
      uri = safe_https_uri(value)
      return failure(:invalid_protocol) if uri.nil? && value.match?(/\A(?:http:|\/\/)/i)
      return failure(:invalid_url) unless uri
      return failure(:invalid_url) if uri.host.blank? || uri.userinfo.present?
      return failure(:invalid_host) unless uri.host.ascii_only?
      return failure(:invalid_host) if uri.port && uri.port != 443
      return failure(:invalid_host) unless ::DiscourseSocialProfile::UrlSafety.public_host?(uri.host)

      host = uri.host.downcase.chomp(".")
      uri = uri.dup
      uri.path = normalize_url_path(uri.path)

      return failure(:invalid_url) if !generated && redirector_like?(uri)

      matched_path = false
      unless generated
        allowed = normalized_hosts
        return failure(:invalid_host) if hosts_required && allowed.empty?
        return failure(:invalid_host) if allowed.any? && !host_allowed?(host, allowed)

        if @platform.path_regex.present?
          validation_path = normalized_path_for_validation(uri.path)
          return failure(:invalid_path) unless validation_path

          begin
            matched_path = self.class.compiled_path_regex(@platform.path_regex).match?(validation_path)
          rescue RegexpError
            return failure(:invalid_regex)
          end
          return failure(:invalid_path) unless matched_path
        end
      end

      if generated
        base = safe_https_uri(@platform.base_url)
        return failure(:invalid_base_url) unless valid_base_uri?(base)
        base_host = base.host.downcase.chomp(".")
        return failure(:invalid_base_url) unless host == base_host && uri.port == base.port
      end

      canonical_uri = uri.dup
      canonical_uri.host = host
      canonical_uri.port = nil if canonical_uri.port == 443
      canonical_uri.path = "/" if canonical_uri.path.blank?
      canonical = canonical_uri.to_s
      success(
        canonical,
        generated ? nil : canonical,
        matched_host: host,
        matched_path: matched_path,
      )
    end

    def redirector_like?(uri)
      return true if nested_external_url?(uri.path, anywhere: true)
      return true if nested_external_url?(uri.fragment, anywhere: true)
      return false if uri.query.blank?

      pairs = URI.decode_www_form(uri.query.to_s)
      redirect_endpoint = redirect_endpoint_path?(uri.path)
      pairs.any? do |key, value|
        nested_external_url?(value) ||
          (redirect_endpoint && REDIRECT_QUERY_KEYS.include?(repeatedly_percent_decode(key.to_s).downcase) && value.to_s.present?)
      end
    rescue ArgumentError
      true
    end

    def nested_external_url?(value, anywhere: false)
      # Browsers and some destination frameworks treat backslashes as URL
      # separators for special schemes. Normalize them before nested-URL checks so
      # encoded forms such as https:%5c%5cevil.example cannot bypass redirector
      # detection and be interpreted differently downstream.
      decoded = repeatedly_percent_decode(value.to_s).tr("\\", "/")
      pattern = anywhere ? %r{(?:https?:)?//}i : %r{\A[[:space:]]*(?:https?://|//)}i
      decoded.match?(pattern)
    end

    def repeatedly_percent_decode(value)
      decoded = value.to_s
      MAX_REDIRECT_DECODE_PASSES.times do
        next_value = URI.decode_www_form_component(decoded)
        break if next_value == decoded
        decoded = next_value
      rescue ArgumentError
        return decoded
      end
      decoded
    end

    def redirect_endpoint_path?(path)
      decoded = repeatedly_percent_decode(path.to_s).tr("\\", "/")
      basename = File.basename(decoded.sub(%r{/+\z}, "")).downcase
      REDIRECT_PATH_BASENAMES.include?(basename)
    end

    # Validate strict platform paths against the decoded path a destination
    # application is likely to route. This closes parser differentials where an
    # encoded (or double-encoded) slash/backslash can pass a raw-path allowlist
    # and then be interpreted as an extra path segment by the remote service.
    def normalized_path_for_validation(path)
      decoded = path.to_s
      MAX_REDIRECT_DECODE_PASSES.times do
        next_value = URI::DEFAULT_PARSER.unescape(decoded)
        break if next_value == decoded
        decoded = next_value
      end

      return nil unless decoded.valid_encoding?
      return nil if decoded.match?(CONTROL) || decoded.include?("\\")

      normalize_url_path(decoded)
    rescue ArgumentError, Encoding::CompatibilityError
      nil
    end

    def normalize_url_path(path)
      raw_path = path.to_s
      return "/" if raw_path.blank?

      segments = raw_path.split("/", -1)
      output = []
      final_dot_segment = false

      segments.each_with_index do |segment, index|
        if index.zero? && segment.empty?
          output << ""
          next
        end

        dot_form = segment.gsub(/%2e/i, ".")
        case dot_form
        when "."
          final_dot_segment = index == segments.length - 1
          next
        when ".."
          output.pop if output.length > 1
          final_dot_segment = index == segments.length - 1
          next
        else
          final_dot_segment = false
          output << segment
        end
      end

      normalized = output.join("/")
      normalized = "/" if normalized.empty? && raw_path.start_with?("/")
      normalized = "#{normalized}/" if final_dot_segment && !normalized.end_with?("/")
      normalized
    end

    def valid_base_uri?(uri)
      uri && uri.host.present? && uri.userinfo.blank? && uri.host.ascii_only? &&
        ::DiscourseSocialProfile::UrlSafety.public_host?(uri.host) &&
        (!uri.port || uri.port == 443) && uri.query.blank? && uri.fragment.blank?
    end

    def safe_https_uri(value)
      return nil if value.blank? || ::DiscourseSocialProfile::UrlSafety.unsafe_control_encoding?(value) || value.start_with?("//")
      uri = URI.parse(value)
      return nil unless uri.is_a?(URI::HTTPS)
      uri
    rescue URI::InvalidURIError
      nil
    end

    def normalized_hosts
      @platform.allowed_hosts.to_s.split(/[,\s]+/).map { |h| h.strip.downcase.chomp(".") }.reject(&:blank?).uniq
    end

    def host_allowed?(host, allowed)
      allowed.any? do |rule|
        if rule.start_with?(".")
          suffix = rule.delete_prefix(".")
          host == suffix || host.end_with?(".#{suffix}")
        else
          host == rule
        end
      end
    end

    def success(href, canonical_value, matched_host: nil, matched_path: false)
      Result.new(
        ok?: true,
        href: href,
        canonical_value: canonical_value || @raw,
        error_code: nil,
        matched_host: matched_host,
        matched_path: matched_path,
      )
    end

    def failure(code)
      Result.new(
        ok?: false,
        href: nil,
        canonical_value: nil,
        error_code: code.to_s,
        matched_host: nil,
        matched_path: false,
      )
    end
  end
end
