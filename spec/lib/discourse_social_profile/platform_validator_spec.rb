# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::PlatformValidator do
  def platform(**attrs)
    defaults = { key: "test", label: "Test", input_type: "handle", base_url: "https://example.com/" }
    DiscourseSocialProfile::Platform.new(defaults.merge(attrs))
  end

  before { SiteSetting.discourse_social_profile_allow_external_icon_urls = false }

  it "accepts a valid handle contract" do
    expect(described_class.call(platform)[:valid]).to eq(true)
  end

  it "rejects unsafe base URL shapes" do
    expect(described_class.call(platform(base_url: "http://example.com/"))[:errors]).to have_key(:base_url)
    expect(described_class.call(platform(base_url: "https://u:p@example.com/"))[:errors]).to have_key(:base_url)
    expect(described_class.call(platform(base_url: "https://example.com/?x=1"))[:errors]).to have_key(:base_url)
  end

  it "requires hosts for url_locked and validates host configuration" do
    locked = platform(input_type: "url_locked", base_url: nil, allowed_hosts: nil)
    expect(described_class.call(locked)[:errors]).to have_key(:allowed_hosts)
    bad = platform(allowed_hosts: "https://example.com")
    expect(described_class.call(bad)[:errors]).to have_key(:allowed_hosts)
  end

  it "validates safe CSS colors and radii" do
    expect(described_class.call(platform(color: "#112233", badge_radius: "4px"))[:valid]).to eq(true)
    expect(described_class.call(platform(color: "red;display:none"))[:errors]).to have_key(:color)
    expect(described_class.call(platform(badge_radius: "1px;position:fixed"))[:errors]).to have_key(:badge_radius)
  end

  it "keeps external icon URLs opt-in and HTTPS-only" do
    expect(described_class.call(platform(icon_image_url: "https://cdn.example/icon.png"))[:errors]).to have_key(:icon_image_url)
    SiteSetting.discourse_social_profile_allow_external_icon_urls = true
    expect(described_class.call(platform(icon_image_url: "https://cdn.example/icon.png"))[:valid]).to eq(true)
    expect(described_class.call(platform(icon_image_url: "http://cdn.example/icon.png"))[:errors]).to have_key(:icon_image_url)
    expect(described_class.call(platform(icon_mask_url: "https://u:p@cdn.example/mask.svg"))[:errors]).to have_key(:icon_mask_url)
  end

  it "rejects invalid regex" do
    expect(described_class.call(platform(path_regex: "["))[:errors]).to have_key(:path_regex)
  end
end
