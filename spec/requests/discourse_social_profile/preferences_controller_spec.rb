# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::PreferencesController do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "preferences", label: "Preferences", input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com", enabled: true)
  end

  before { SiteSetting.discourse_social_profile_enabled = true }

  it "requires login" do
    get "/social-profile/preferences.json"
    expect(response.status).to eq(403)
  end

  it "returns only the current user's values and no-store" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    sign_in(user)
    get "/social-profile/preferences.json"
    expect(response.status).to eq(200)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.parsed_body["platforms"].first["value"]).to eq("alice")
  end

  it "writes only the current user even when a user_id is supplied" do
    sign_in(user)
    put "/social-profile/preferences.json", params: { user_id: other_user.id, links: [{ platform_id: platform.id, value: "mine" }] }
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform).value).to eq("mine")
    expect(DiscourseSocialProfile::Link.find_by(user: other_user, platform: platform)).to be_nil
  end

  it "also keeps an administrator on self-service ownership" do
    sign_in(admin)
    put "/social-profile/preferences.json", params: { user_id: other_user.id, links: [{ platform_id: platform.id, value: "admin-self" }] }
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: admin, platform: platform).value).to eq("admin-self")
    expect(DiscourseSocialProfile::Link.find_by(user: other_user, platform: platform)).to be_nil
  end

  it "rejects the whole save when one value is invalid" do
    second = DiscourseSocialProfile::Platform.create!(key: "preferences-two", label: "Two", input_type: "url_locked", allowed_hosts: "example.com", enabled: true)
    sign_in(user)
    put "/social-profile/preferences.json", params: { links: [{ platform_id: platform.id, value: "good" }, { platform_id: second.id, value: "https://evil.example/" }] }
    expect(response.status).to eq(422)
    expect(DiscourseSocialProfile::Link.where(user: user)).to be_empty
  end

  it "rejects malformed, duplicate, disabled and non-strict IDs" do
    sign_in(user)
    put "/social-profile/preferences.json", params: { links: "not-an-array" }
    expect(response.status).to eq(400)
    put "/social-profile/preferences.json", params: { links: ["not-an-object"] }
    expect(response.status).to eq(400)
    put "/social-profile/preferences.json", params: { links: [{ platform_id: "#{platform.id}junk", value: "a" }] }
    expect(response.status).to eq(422)
    put "/social-profile/preferences.json", params: { links: [{ platform_id: platform.id, value: "a" }, { platform_id: platform.id, value: "b" }] }
    expect(response.status).to eq(422)
    platform.update!(enabled: false)
    put "/social-profile/preferences.json", params: { links: [{ platform_id: platform.id, value: "a" }] }
    expect(response.status).to eq(422)
  end

  it "rejects oversized platform batches before transformation" do
    stub_const("DiscourseSocialProfile::PreferencesController::MAX_PREFERENCES_ENTRIES", 1)
    sign_in(user)
    put "/social-profile/preferences.json", params: { links: [{ platform_id: platform.id, value: "a" }, { platform_id: platform.id + 100, value: "b" }] }
    expect(response.status).to eq(422)
    expect(response.parsed_body.dig("errors", "base")).to eq("too_many_platforms")
  end

  it "returns not found when the plugin is disabled" do
    SiteSetting.discourse_social_profile_enabled = false
    sign_in(user)
    get "/social-profile/preferences.json"
    expect(response.status).to eq(404)
  end
end
