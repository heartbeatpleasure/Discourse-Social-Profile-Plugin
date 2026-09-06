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
    put "/social-profile/preferences.json", params: { user_id: other_user.id, social_profile_links: [{ platform_id: platform.id, value: "mine" }] }
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform).value).to eq("mine")
    expect(DiscourseSocialProfile::Link.find_by(user: other_user, platform: platform)).to be_nil
  end

  it "accepts the log-filtered JSON array shape sent by the current preferences client" do
    sign_in(user)
    put "/social-profile/preferences.json",
        params: { social_profile_links: [{ platform_id: platform.id, value: "json-user" }] },
        as: :json
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform).value).to eq("json-user")
  end

  it "rejects the generic legacy links parameter so profile values stay under a filtered key" do
    sign_in(user)
    put "/social-profile/preferences.json",
        params: { links: [{ platform_id: platform.id, value: "legacy-json" }] },
        as: :json
    expect(response.status).to eq(400)
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform)).to be_nil
  end

  it "accepts the numeric-key compatibility shape from older form-encoded clients" do
    sign_in(user)
    put "/social-profile/preferences.json",
        params: { social_profile_links: { "0" => { platform_id: platform.id, value: "form-client" } } }
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform).value).to eq("form-client")
  end

  it "also keeps an administrator on self-service ownership" do
    sign_in(admin)
    put "/social-profile/preferences.json",
        params: {
          user_id: other_user.id,
          social_profile_links: [{ platform_id: platform.id, value: "admin-self" }],
        }
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(user: admin, platform: platform).value).to eq("admin-self")
    expect(DiscourseSocialProfile::Link.find_by(user: other_user, platform: platform)).to be_nil
  end

  it "rejects the whole save when one value is invalid" do
    second = DiscourseSocialProfile::Platform.create!(key: "preferences-two", label: "Two", input_type: "url_locked", allowed_hosts: "example.com", enabled: true)
    sign_in(user)
    put "/social-profile/preferences.json", params: { social_profile_links: [{ platform_id: platform.id, value: "good" }, { platform_id: second.id, value: "https://evil.example/" }] }
    expect(response.status).to eq(422)
    expect(DiscourseSocialProfile::Link.where(user: user)).to be_empty
  end

  it "rejects malformed, duplicate and non-strict IDs and nonblank writes to disabled platforms" do
    sign_in(user)
    put "/social-profile/preferences.json", params: { social_profile_links: "not-an-array" }
    expect(response.status).to eq(400)
    put "/social-profile/preferences.json", params: { social_profile_links: ["not-an-object"] }
    expect(response.status).to eq(400)
    put "/social-profile/preferences.json", params: { social_profile_links: [{ platform_id: "#{platform.id}junk", value: "a" }] }
    expect(response.status).to eq(422)
    put "/social-profile/preferences.json", params: { social_profile_links: [{ platform_id: platform.id, value: "a" }, { platform_id: platform.id, value: "b" }] }
    expect(response.status).to eq(422)
    platform.update!(enabled: false)
    put "/social-profile/preferences.json", params: { social_profile_links: [{ platform_id: platform.id, value: "a" }] }
    expect(response.status).to eq(422)
    expect(response.parsed_body.dig("errors", platform.id.to_s)).to eq("platform_disabled")
  end

  it "shows a disabled platform only to owners who still have data and lets them delete it" do
    link = DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "old-profile")
    platform.update!(enabled: false)
    sign_in(user)

    get "/social-profile/preferences.json"
    expect(response.status).to eq(200)
    payload = response.parsed_body["platforms"].find { |row| row["id"] == platform.id }
    expect(payload).to be_present
    expect(payload["enabled"]).to eq(false)
    expect(payload["value"]).to eq("old-profile")
    expect(payload["preview_href"]).to be_nil

    put "/social-profile/preferences.json",
        params: { social_profile_links: [{ platform_id: platform.id, value: "" }] },
        as: :json
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Link.find_by(id: link.id)).to be_nil
    expect(response.parsed_body["platforms"].none? { |row| row["id"] == platform.id }).to eq(true)
  end

  it "treats an unchanged disabled value as a no-op so other profiles can still be saved" do
    disabled_link = DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "old-profile")
    platform.update!(enabled: false)
    enabled_platform = DiscourseSocialProfile::Platform.create!(
      key: "enabled-peer",
      label: "Enabled Peer",
      input_type: "handle",
      base_url: "https://peer.example/",
      allowed_hosts: "peer.example",
    )
    sign_in(user)

    put "/social-profile/preferences.json",
        params: {
          social_profile_links: [
            { platform_id: platform.id, value: "old-profile" },
            { platform_id: enabled_platform.id, value: "new-profile" },
          ],
        },
        as: :json

    expect(response.status).to eq(200)
    expect(disabled_link.reload.value).to eq("old-profile")
    expect(
      DiscourseSocialProfile::Link.find_by!(user: user, platform: enabled_platform).value,
    ).to eq("new-profile")
  end

  it "does not expose disabled platforms that have no stored value for the owner" do
    platform.update!(enabled: false)
    sign_in(user)
    get "/social-profile/preferences.json"
    expect(response.parsed_body["platforms"].none? { |row| row["id"] == platform.id }).to eq(true)
  end

  it "rejects oversized platform batches before transformation" do
    stub_const("DiscourseSocialProfile::PreferencesController::MAX_PREFERENCES_ENTRIES", 1)
    sign_in(user)
    put "/social-profile/preferences.json", params: { social_profile_links: [{ platform_id: platform.id, value: "a" }, { platform_id: platform.id + 100, value: "b" }] }
    expect(response.status).to eq(422)
    expect(response.parsed_body.dig("errors", "base")).to eq("too_many_platforms")
  end

  it "bounds numeric-key form batches before sorting or integer conversion" do
    stub_const("DiscourseSocialProfile::PreferencesController::MAX_PREFERENCES_ENTRIES", 1)
    sign_in(user)

    put "/social-profile/preferences.json",
        params: {
          social_profile_links: {
            "0" => { platform_id: platform.id, value: "a" },
            "1" => { platform_id: platform.id + 100, value: "b" },
          },
        }
    expect(response.status).to eq(422)
    expect(response.parsed_body.dig("errors", "base")).to eq("too_many_platforms")

    put "/social-profile/preferences.json",
        params: {
          social_profile_links: {
            "999999999999999999999999999999999999999999" => {
              platform_id: platform.id,
              value: "a",
            },
          },
        }
    expect(response.status).to eq(400)
  end

  it "bounds preview validation on preferences reads without blocking the page" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    stub_const("DiscourseSocialProfile::PreferencesController::PREVIEW_VALIDATION_BUDGET", -1.second)
    allow(DiscourseSocialProfile::LinkBuilder).to receive(:call).and_raise("preview should be skipped")
    sign_in(user)

    get "/social-profile/preferences.json"
    expect(response.status).to eq(200)
    payload = response.parsed_body["platforms"].find { |row| row["id"] == platform.id }
    expect(payload["value"]).to eq("alice")
    expect(payload["preview_href"]).to be_nil
    expect(payload["error_code"]).to be_nil
  end

  it "fails closed when the aggregate validation budget is exhausted" do
    stub_const("DiscourseSocialProfile::PreferencesController::VALIDATION_BUDGET", 0.seconds)
    sign_in(user)
    put "/social-profile/preferences.json",
        params: { social_profile_links: [{ platform_id: platform.id, value: "alice" }] },
        as: :json
    expect(response.status).to eq(422)
    expect(response.parsed_body.dig("errors", "base")).to eq("validation_timed_out")
    expect(DiscourseSocialProfile::Link.find_by(user: user, platform: platform)).to be_nil
  end

  it "returns not found when the plugin is disabled" do
    SiteSetting.discourse_social_profile_enabled = false
    sign_in(user)
    get "/social-profile/preferences.json"
    expect(response.status).to eq(404)
  end
end
