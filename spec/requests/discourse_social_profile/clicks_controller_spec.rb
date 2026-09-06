# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::ClicksController do
  fab!(:owner) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "clicks", label: "Clicks", input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com", enabled: true)
  end
  let!(:link) { DiscourseSocialProfile::Link.create!(user: owner, platform: platform, value: "owner") }

  before do
    SiteSetting.discourse_social_profile_enabled = true
    SiteSetting.discourse_social_profile_track_clicks = false
  end

  it "does not expose the endpoint while tracking is disabled" do
    sign_in(viewer)
    get "/social-profile/click/#{link.click_token}"
    expect(response.status).to eq(404)
  end

  it "redirects a valid opaque token and stores only aggregate data" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    get "/social-profile/click/#{link.click_token}"
    expect(response).to redirect_to("https://example.com/u/owner")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    stat = DiscourseSocialProfile::ClickStat.find_by(platform_id: platform.id, stat_date: Date.current)
    expect(stat.click_count).to eq(1)
  end

  it "records a background click without returning or redirecting to the destination" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    post "/social-profile/click/#{link.click_token}", xhr: true
    expect(response.status).to eq(204)
    expect(response.body).to be_blank
    stat = DiscourseSocialProfile::ClickStat.find_by(platform_id: platform.id, stat_date: Date.current)
    expect(stat.click_count).to eq(1)
  end

  it "does not expose the destination from the background analytics endpoint" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    post "/social-profile/click/#{link.click_token}", xhr: true
    expect(response.body).not_to include("example.com")
    expect(response.headers["Location"]).to be_blank
  end

  it "rejects forged, malformed and sequential identifiers" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    [link.id.to_s, "abc", "a" * 33, "12junk"].each do |token|
      get "/social-profile/click/#{token}"
      expect(response.status).to eq(404)
    end
  end

  it "still redirects but skips aggregation when the click limiter is exhausted" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    limiter = instance_double(RateLimiter)
    allow(RateLimiter).to receive(:new).and_call_original
    allow(RateLimiter).to receive(:new).with(nil, "social-profile-click-link-#{link.id}", 300, 1.minute).and_return(limiter)
    allow(limiter).to receive(:performed!).and_raise(RateLimiter::LimitExceeded.new(300, "social-profile-click-link-#{link.id}"))
    get "/social-profile/click/#{link.click_token}"
    expect(response).to redirect_to("https://example.com/u/owner")
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "does not expose a tracked destination when the target profile is hidden" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.allow_users_to_hide_profile = true
    owner.user_option.update!(hide_profile: true)
    sign_in(viewer)
    get "/social-profile/click/#{link.click_token}"
    expect(response.status).to eq(404)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "keeps the background endpoint destination-blind even if a previously issued token is replayed" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.allow_users_to_hide_profile = true
    owner.user_option.update!(hide_profile: true)
    sign_in(viewer)
    post "/social-profile/click/#{link.click_token}", xhr: true
    expect(response.status).to eq(204)
    expect(response.body).to be_blank
    expect(response.headers["Location"]).to be_blank
  end

  it "does not redirect when current platform rules invalidate the stored value" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    link.update_column(:value, "https://evil.example/")
    get "/social-profile/click/#{link.click_token}"
    expect(response.status).to eq(404)
  end
end
