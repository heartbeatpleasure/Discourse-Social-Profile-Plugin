# frozen_string_literal: true

RSpec.describe "Social Profile admin overview/statistics" do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "admin-stats", label: "Admin Stats", input_type: "handle", base_url: "https://example.com/", allowed_hosts: "example.com")
  end

  it "keeps both admin endpoints admin-only" do
    sign_in(user)
    get "/admin/plugins/discourse-social-profile/overview.json"
    expect(response.status).to be_in([403, 404])
    get "/admin/plugins/discourse-social-profile/statistics.json"
    expect(response.status).to be_in([403, 404])
  end

  it "returns aggregate overview and no-store" do
    sign_in(admin)
    get "/admin/plugins/discourse-social-profile/overview.json"
    expect(response.status).to eq(200)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.parsed_body["platform_count"]).to be >= 1
  end

  it "returns privacy-friendly statistics and supports refresh" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "user")
    sign_in(admin)
    get "/admin/plugins/discourse-social-profile/statistics.json", params: { refresh: true }
    expect(response.status).to eq(200)
    expect(response.headers["Cache-Control"]).to include("no-store")
    body = response.parsed_body
    expect(body["total_links"]).to be >= 1
    expect(body).not_to have_key("users")
  end
end
