# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::LinkBuilder do
  def platform(input_type:, base_url: nil, allowed_hosts: nil, path_regex: nil)
    DiscourseSocialProfile::Platform.new(
      key: "test",
      label: "Test",
      input_type: input_type,
      base_url: base_url,
      allowed_hosts: allowed_hosts,
      path_regex: path_regex,
    )
  end

  it "normalizes a handle and safely builds the configured URL" do
    result = described_class.call(platform(input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com"), " @john doe ")
    expect(result).to be_ok
    expect(result.canonical_value).to eq("johndoe")
    expect(result.href).to eq("https://example.com/u/johndoe")
  end

  it "matches JavaScript-style Unicode whitespace normalization for identifiers" do
    result = described_class.call(platform(input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com"), "\u00A0@john\u00A0doe\u00A0")
    expect(result).to be_ok
    expect(result.canonical_value).to eq("johndoe")
  end

  it "encodes identifier characters instead of allowing them to alter the URL origin" do
    result = described_class.call(platform(input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com"), "john+tag@example")
    expect(result).to be_ok
    expect(result.href).to eq("https://example.com/u/john%2Btag%40example")
  end

  it "rejects identifier dot segments and encoded path separators before URL construction" do
    p = platform(input_type: "handle", base_url: "https://example.com/users/", allowed_hosts: "example.com")
    %w[. .. %2e %2e%2e %252e%252e alice\\admin alice%2Fadmin alice%255Cadmin].each do |value|
      expect(described_class.call(p, value).error_code).to eq("invalid_handle"), value
    end
  end

  it "preserves a matching full HTTPS URL for handle input" do
    raw = "https://www.example.com/u/john?tab=profile#about"
    result = described_class.call(platform(input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com,www.example.com"), raw)
    expect(result).to be_ok
    expect(result.canonical_value).to eq(raw)
  end

  it "preserves allowed subdomain full-URL semantics" do
    p = platform(input_type: "handle", base_url: "https://www.tumblr.com/", allowed_hosts: "tumblr.com,www.tumblr.com,.tumblr.com")
    raw = "https://john.tumblr.com/not-the-profile-root?view=archive#top"
    expect(described_class.call(p, raw)).to be_ok
  end

  it "rejects HTTP, protocol-relative, javascript and data URLs" do
    p = platform(input_type: "url_any_https")
    expect(described_class.call(p, "http://example.com/u/test").error_code).to eq("invalid_protocol")
    expect(described_class.call(p, "//example.com/u/test").error_code).to eq("invalid_protocol")
    expect(described_class.call(p, "javascript:alert(1)").error_code).to eq("invalid_url")
    expect(described_class.call(p, "data:text/plain,test").error_code).to eq("invalid_url")
  end

  it "canonicalizes host case, trailing dot and default HTTPS port" do
    result = described_class.call(platform(input_type: "url_locked", allowed_hosts: "example.com"), "HTTPS://EXAMPLE.COM.:443/u")
    expect(result).to be_ok
    expect(result.href).to eq("https://example.com/u")
  end

  it "serializes an origin-only URL with the browser-equivalent root slash" do
    result = described_class.call(platform(input_type: "url_any_https"), "https://example.com")
    expect(result.href).to eq("https://example.com/")
  end

  it "rejects credentials, deceptive hosts and non-default ports" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com")
    expect(described_class.call(p, "https://user:pass@example.com/u").error_code).to eq("invalid_url")
    expect(described_class.call(p, "https://example.com.evil.test/u").error_code).to eq("invalid_host")
    expect(described_class.call(p, "https://evil-example.com/u").error_code).to eq("invalid_host")
    expect(described_class.call(p, "https://example.com:444/u").error_code).to eq("invalid_host")
  end

  it "rejects raw, encoded and double-encoded redirector constructions" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com")
    expect(described_class.call(p, "https://example.com/l.php?u=https://evil.test").error_code).to eq("invalid_url")
    expect(described_class.call(p, "https://example.com/l.php?u=https%3A%2F%2Fevil.test").error_code).to eq("invalid_url")
    expect(described_class.call(p, "https://example.com/l.php?u=https%253A%252F%252Fevil.test").error_code).to eq("invalid_url")
    expect(described_class.call(p, "https://example.com/out/https%3A%2F%2Fevil.test").error_code).to eq("invalid_url")
  end

  it "rejects nested redirect targets encoded with browser-style backslashes" do
    p = platform(input_type: "url_any_https")
    expect(described_class.call(p, "https://example.com/?next=https:%5c%5cevil.example").error_code).to eq("invalid_url")
    expect(described_class.call(p, "https://example.com/?next=https:%255c%255cevil.example").error_code).to eq("invalid_url")
  end

  it "allows normal query and fragment semantics" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com")
    expect(described_class.call(p, "https://example.com/profile?tab=about#bio")).to be_ok
  end

  it "implements explicit suffix-host rules without substring matching" do
    p = platform(input_type: "url_locked", allowed_hosts: ".example.com")
    expect(described_class.call(p, "https://profile.example.com/u")).to be_ok
    expect(described_class.call(p, "https://example.com/u")).to be_ok
    expect(described_class.call(p, "https://notexample.com/u").error_code).to eq("invalid_host")
  end

  it "normalizes literal and percent-encoded dot segments before pathname validation" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com", path_regex: "^/users/")
    expect(described_class.call(p, "https://example.com/users/alice/../../admin").error_code).to eq("invalid_path")
    expect(described_class.call(p, "https://example.com/users/alice/%2e%2e/%2e%2e/admin").error_code).to eq("invalid_path")
    open = described_class.call(platform(input_type: "url_any_https"), "https://example.com/a/%2e%2e/b")
    expect(open.href).to eq("https://example.com/b")
  end

  it "validates strict pathname rules after decoding encoded separators" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com", path_regex: "^/users/[^/]+/?$")
    expect(described_class.call(p, "https://example.com/users/alice%2Fadmin").error_code).to eq("invalid_path")
    expect(described_class.call(p, "https://example.com/users/alice%252Fadmin").error_code).to eq("invalid_path")
    expect(described_class.call(p, "https://example.com/users/alice%5Cadmin").error_code).to eq("invalid_path")
  end

  it "enforces pathname regexes and fails closed on invalid regex" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com", path_regex: "^/users/\\d+/?$")
    expect(described_class.call(p, "https://example.com/users/123")).to be_ok
    expect(described_class.call(p, "https://example.com/admin").error_code).to eq("invalid_path")
    bad = platform(input_type: "url_locked", allowed_hosts: "example.com", path_regex: "[")
    expect(described_class.call(bad, "https://example.com/users/123").error_code).to eq("invalid_regex")
  end

  it "validates numeric IDs and accepts a matching full URL" do
    p = platform(input_type: "numeric_id", base_url: "https://example.com/users/", allowed_hosts: "example.com", path_regex: "^/users/\\d+")
    expect(described_class.call(p, "12345").href).to eq("https://example.com/users/12345")
    expect(described_class.call(p, "abc").error_code).to eq("invalid_numeric_id")
    expect(described_class.call(p, "https://example.com/users/99?view=profile#top")).to be_ok
  end

  it "keeps host/path rules as full-URL rules rather than generated-handle rules" do
    p = platform(input_type: "handle", base_url: "https://base.example/users/", allowed_hosts: "profiles.example", path_regex: "^/profile/[^/]+$")
    generated = described_class.call(p, "alice")
    expect(generated.href).to eq("https://base.example/users/alice")
    expect(described_class.call(p, "https://profiles.example/profile/alice")).to be_ok
    expect(described_class.call(p, "https://profiles.example/users/alice").error_code).to eq("invalid_path")
  end

  it "validates email input and produces mailto links" do
    p = platform(input_type: "email")
    expect(described_class.call(p, "person@example.com").href).to eq("mailto:person@example.com")
    expect(described_class.call(p, "https://example.com").error_code).to eq("invalid_email")
    expect(described_class.call(p, "person@example.com?subject=evil").error_code).to eq("invalid_email")
  end

  it "supports arbitrary HTTPS with optional host restrictions" do
    expect(described_class.call(platform(input_type: "url_any_https"), "https://social.example/@name")).to be_ok
    restricted = platform(input_type: "url_any_https", allowed_hosts: "social.example")
    expect(described_class.call(restricted, "https://evil.example/@name").error_code).to eq("invalid_host")
  end

  it "rejects loopback, private and browser-normalized shorthand IP destinations" do
    p = platform(input_type: "url_any_https")
    %w[
      https://127.0.0.1/profile
      https://10.0.0.1/profile
      https://169.254.169.254/latest/meta-data
      https://127.1/profile
      https://0177.0.0.1/profile
      https://0x7f000001/profile
      https://2130706433/profile
      https://home.arpa/profile
      https://router.local/profile
    ].each do |value|
      expect(described_class.call(p, value).error_code).to eq("invalid_host"), value
    end
  end

  it "fails closed for non-ASCII hosts, encoded controls and unsafe base URLs" do
    p = platform(input_type: "url_locked", allowed_hosts: "example.com")
    expect(described_class.call(p, "https://éxample.com/user").error_code).to eq("invalid_url")
    expect(described_class.call(platform(input_type: "url_any_https"), "https://example.com/%0aevil").error_code).to eq("invalid_value")
    expect(described_class.call(platform(input_type: "url_any_https"), "https://example.com/%252525250aevil").error_code).to eq("invalid_value")
    unsafe = platform(input_type: "handle", base_url: "https://user@example.com/", allowed_hosts: "example.com")
    expect(described_class.call(unsafe, "john").error_code).to eq("invalid_base_url")
  end
end
