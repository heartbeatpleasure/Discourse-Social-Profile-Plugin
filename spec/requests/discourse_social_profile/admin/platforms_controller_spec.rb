# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::Admin::PlatformsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:other_admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(
      key: "admin-test",
      label: "Admin Test",
      input_type: "handle",
      base_url: "https://example.com/u/",
      allowed_hosts: "example.com",
      position: 0,
    )
  end

  it "rejects non-admin users" do
    sign_in(user)
    get "/admin/plugins/discourse-social-profile/platforms.json"
    expect(response.status).to be_in([403, 404])
  end

  it "lists and shows platforms only for admin" do
    sign_in(admin)
    get "/admin/plugins/discourse-social-profile/platforms.json"
    expect(response.status).to eq(200)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.parsed_body["platforms"].map { |p| p["key"] }).to include("admin-test")

    get "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json"
    expect(response.parsed_body.dig("platform", "key")).to eq("admin-test")
  end

  it "creates and updates a valid platform without uniqueness false positives" do
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms.json", params: {
      platform: {
        key: "created",
        enabled: true,
        label: "Created",
        input_type: "handle",
        base_url: "https://created.example/",
        allowed_hosts: "created.example",
        icon_name: "globe",
      },
    }
    expect(response.status).to eq(201)
    created = DiscourseSocialProfile::Platform.find_by!(key: "created")

    put "/admin/plugins/discourse-social-profile/platforms/#{created.id}.json", params: {
      platform: { label: "Renamed" },
    }
    expect(response.status).to eq(200)
    expect(created.reload.label).to eq("Renamed")
  end

  it "rejects invalid platform configuration" do
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms.json", params: {
      platform: { key: "bad", label: "Bad", input_type: "handle", base_url: "http://example.com/" },
    }
    expect(response.status).to eq(422)
  end

  it "rejects malformed platform payloads on create and test" do
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms.json", params: { platform: "bad" }
    expect(response.status).to eq(400)
    post "/admin/plugins/discourse-social-profile/platforms/#{platform.id}/test.json", params: { social_profile_test_value: "alice", platform: "bad" }
    expect(response.status).to eq(400)
  end

  it "does not accept the generic legacy value key on the platform test endpoint" do
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms/#{platform.id}/test.json",
         params: { value: "alice" }
    expect(response.status).to eq(200)
    expect(response.parsed_body["accepted"]).to eq(false)
    expect(response.parsed_body["error_code"]).to eq("blank")
  end

  it "tests an unsaved candidate without changing the stored platform" do
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms/#{platform.id}/test.json", params: {
      social_profile_test_value: "https://profiles.example/profile/alice",
      platform: { allowed_hosts: "profiles.example", path_regex: "^/profile/" },
    }
    expect(response.status).to eq(200)
    expect(response.parsed_body["accepted"]).to eq(true)
    expect(platform.reload.allowed_hosts).to eq("example.com")
  end

  it "refuses validation changes that invalidate existing user values" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    sign_in(admin)
    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: { input_type: "url_locked", base_url: "", allowed_hosts: "other.example" },
    }
    expect(response.status).to eq(422)
    expect(platform.reload.input_type).to eq("handle")
  end

  it "allows validation repairs while disabled and re-audits all stored links before re-enabling" do
    link = DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    sign_in(admin)

    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: {
        enabled: false,
        input_type: "url_locked",
        base_url: "",
        allowed_hosts: "other.example",
      },
    }
    expect(response.status).to eq(200)
    expect(platform.reload.enabled).to eq(false)
    expect(platform.input_type).to eq("url_locked")
    expect(link.reload.value).to eq("alice")

    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: { enabled: true },
    }
    expect(response.status).to eq(422)
    expect(platform.reload.enabled).to eq(false)

    link.destroy!
    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: { enabled: true },
    }
    expect(response.status).to eq(200)
    expect(platform.reload.enabled).to eq(true)
  end

  it "only accepts newly assigned public uploads owned by the current admin" do
    sign_in(admin)
    upload = Fabricate(:upload, user_id: admin.id, extension: "png", filesize: 1000, secure: false)
    UserUpload.find_or_create_by!(user_id: admin.id, upload_id: upload.id)
    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: { icon_image_upload_id: upload.id },
    }
    expect(response.status).to eq(200)
    expect(platform.reload.icon_image_upload_id).to eq(upload.id)

    foreign = Fabricate(:upload, user_id: other_admin.id, extension: "png", filesize: 1000, secure: false)
    UserUpload.find_or_create_by!(user_id: other_admin.id, upload_id: foreign.id)
    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: {
      platform: { icon_image_upload_id: foreign.id },
    }
    expect(response.status).to eq(422)
    expect(platform.reload.icon_image_upload_id).to eq(upload.id)
  end

  it "rejects a used platform delete and permits unused delete" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    sign_in(admin)
    delete "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json"
    expect(response.status).to eq(409)

    unused = DiscourseSocialProfile::Platform.create!(key: "unused", label: "Unused", input_type: "url_any_https")
    delete "/admin/plugins/discourse-social-profile/platforms/#{unused.id}.json"
    expect(response.status).to eq(200)
    expect(DiscourseSocialProfile::Platform.find_by(id: unused.id)).to be_nil
  end

  it "requires the complete exact ID set for reorder" do
    second = DiscourseSocialProfile::Platform.create!(key: "admin-second", label: "Second", input_type: "url_any_https", position: 1)
    sign_in(admin)
    post "/admin/plugins/discourse-social-profile/platforms/reorder.json", params: { ids: [second.id, platform.id] }
    expect(response.status).to eq(200)
    expect(second.reload.position).to eq(0)

    post "/admin/plugins/discourse-social-profile/platforms/reorder.json", params: { ids: ["#{platform.id}junk", second.id] }
    expect(response.status).to eq(422)
  end
  it "allows a used platform to be disabled and safely re-enabled when its saved values remain valid" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    sign_in(admin)

    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: { platform: { enabled: false } }
    expect(response.status).to eq(200)
    expect(platform.reload.enabled).to eq(false)

    put "/admin/plugins/discourse-social-profile/platforms/#{platform.id}.json", params: { platform: { enabled: true } }
    expect(response.status).to eq(200)
    expect(platform.reload.enabled).to eq(true)
  end

end
