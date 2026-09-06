# frozen_string_literal: true

RSpec.describe "Social profile serializers" do
  fab!(:owner) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }

  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "serializer", label: "Serializer", input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com", enabled: true, position: 0)
  end
  let!(:link) { DiscourseSocialProfile::Link.create!(user: owner, platform: platform, value: "owner") }

  before do
    SiteSetting.discourse_social_profile_enabled = true
    SiteSetting.discourse_social_profile_show_on_profile = true
    SiteSetting.discourse_social_profile_show_on_user_card = true
  end

  it "serializes render-ready links for an ordinary user viewing another user" do
    json = UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json
    expect(json[:social_profiles].first[:href]).to eq("https://example.com/u/owner")
    expect(json).not_to have_key(:social_profile_values)
  end

  it "serializes the same safe data on a user card" do
    json = UserCardSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json
    expect(json[:social_profiles].first[:key]).to eq("serializer")
  end

  it "keeps the external destination and exposes only an opaque analytics token when tracking is enabled" do
    SiteSetting.discourse_social_profile_track_clicks = true
    social = UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles].first
    expect(social[:href]).to eq("https://example.com/u/owner")
    expect(social[:click_token]).to eq(link.click_token)
    expect(social).not_to have_key(:id)
  end

  it "keeps full-profile and user-card visibility settings independent" do
    SiteSetting.discourse_social_profile_show_on_profile = false
    expect(UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json).not_to have_key(:social_profiles)
    expect(UserCardSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles]).to be_present

    SiteSetting.discourse_social_profile_show_on_profile = true
    SiteSetting.discourse_social_profile_show_on_user_card = false
    expect(UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles]).to be_present
    expect(UserCardSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json).not_to have_key(:social_profiles)
  end

  it "omits social profiles when the target profile is hidden" do
    SiteSetting.allow_users_to_hide_profile = true
    owner.user_option.update!(hide_profile: true)
    expect(UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json).not_to have_key(:social_profiles)
  end

  it "omits disabled platform values" do
    platform.update!(enabled: false)
    expect(UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles]).to be_blank
  end

  it "exposes raw values only to the owner" do
    self_json = UserSerializer.new(owner, scope: Guardian.new(owner), root: false).as_json
    expect(self_json[:social_profile_values]).to eq([{ platform_key: "serializer", platform_label: "Serializer", value: "owner" }])
    expect(UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json).not_to have_key(:social_profile_values)
  end

  it "keeps bundled-mask platforms such as Pornhub in both profile serializers" do
    pornhub =
      DiscourseSocialProfile::Platform.create!(
        key: "pornhub-test",
        label: "Pornhub",
        input_type: "handle",
        base_url: "https://www.pornhub.com/users/",
        allowed_hosts: "pornhub.com,.pornhub.com",
        icon_name: "globe",
        builtin_icon: "pornhub",
        enabled: true,
        position: 1,
      )
    DiscourseSocialProfile::Link.create!(user: owner, platform: pornhub, value: "owner")

    profile_rows = UserSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles]
    card_rows = UserCardSerializer.new(owner, scope: Guardian.new(viewer), root: false).as_json[:social_profiles]

    profile_pornhub = profile_rows.find { |row| row[:key] == "pornhub-test" }
    card_pornhub = card_rows.find { |row| row[:key] == "pornhub-test" }

    expect(profile_pornhub[:href]).to eq("https://www.pornhub.com/users/owner")
    expect(card_pornhub[:href]).to eq("https://www.pornhub.com/users/owner")
    expect(profile_pornhub[:icon_mask_url]).to end_with("/images/social-profile/pornhub.svg")
    expect(card_pornhub[:icon_mask_url]).to end_with("/images/social-profile/pornhub.svg")
  end

end
