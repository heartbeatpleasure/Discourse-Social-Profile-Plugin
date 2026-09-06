# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::ClicksController do
  fab!(:owner) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(
      key: "clicks",
      label: "Clicks",
      input_type: "handle",
      base_url: "https://example.com/u/",
      allowed_hosts: "example.com",
      enabled: true,
    )
  end
  let!(:link) { DiscourseSocialProfile::Link.create!(user: owner, platform: platform, value: "owner") }

  before do
    SiteSetting.discourse_social_profile_enabled = true
    SiteSetting.discourse_social_profile_track_clicks = false
  end

  it "does not expose a tokenized GET redirect route" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    get "/social-profile/click/#{link.click_token}"
    expect(response.status).to eq(404)
    expect(response.headers["Location"]).to be_blank
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "does not accept tokenized POST paths" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    post "/social-profile/click/#{link.click_token}", xhr: true
    expect(response.status).to eq(404)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "records a background click without returning or redirecting to the destination" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(response.body).to be_blank
    stat = DiscourseSocialProfile::ClickStat.find_by(platform_id: platform.id, stat_date: Date.current)
    expect(stat.click_count).to eq(1)
  end

  it "does not expose the destination from the background analytics endpoint" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.body).not_to include("example.com")
    expect(response.headers["Location"]).to be_blank
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "rejects forged, malformed and sequential identifiers before lookup" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    [link.id.to_s, "abc", "a" * 33, "12junk"].each do |token|
      post "/social-profile/click.json", params: { token: token }, xhr: true
      expect(response.status).to eq(404)
    end
  end

  it "skips aggregation when the per-link analytics limiter is exhausted" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)

    request_limiter = instance_double(RateLimiter, performed!: true)
    actor_link_limiter = instance_double(RateLimiter, performed!: true)
    link_limiter = instance_double(RateLimiter, performed!: false)
    allow(RateLimiter).to receive(:new).and_call_original
    allow(RateLimiter).to receive(:new).with(
      viewer,
      "social-profile-click-request",
      120,
      1.minute,
      apply_limit_to_staff: true,
    ).and_return(request_limiter)
    allow(RateLimiter).to receive(:new).with(
      viewer,
      "social-profile-click-link-#{link.id}",
      30,
      1.minute,
      apply_limit_to_staff: true,
    ).and_return(actor_link_limiter)
    allow(RateLimiter).to receive(:new).with(
      nil,
      "social-profile-click-link-#{link.id}",
      300,
      1.minute,
    ).and_return(link_limiter)

    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "does not query or aggregate after the actor limiter is exhausted" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)

    request_limiter = instance_double(RateLimiter, performed!: false)
    allow(RateLimiter).to receive(:new).and_call_original
    allow(RateLimiter).to receive(:new).with(
      viewer,
      "social-profile-click-request",
      120,
      1.minute,
      apply_limit_to_staff: true,
    ).and_return(request_limiter)
    expect(DiscourseSocialProfile::Link).not_to receive(:includes)

    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "keeps valid-format unknown tokens destination-blind on the background endpoint" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)

    post "/social-profile/click.json", params: { token: "A" * 32 }, xhr: true
    expect(response.status).to eq(204)
    expect(response.body).to be_blank
    expect(response.headers["Location"]).to be_blank
  end

  it "skips aggregation when the actor-per-link limiter is exhausted" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)

    request_limiter = instance_double(RateLimiter, performed!: true)
    actor_link_limiter = instance_double(RateLimiter, performed!: false)
    allow(RateLimiter).to receive(:new).and_call_original
    allow(RateLimiter).to receive(:new).with(
      viewer,
      "social-profile-click-request",
      120,
      1.minute,
      apply_limit_to_staff: true,
    ).and_return(request_limiter)
    allow(RateLimiter).to receive(:new).with(
      viewer,
      "social-profile-click-link-#{link.id}",
      30,
      1.minute,
      apply_limit_to_staff: true,
    ).and_return(actor_link_limiter)

    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "keeps the background endpoint destination-blind if a hidden-profile token is replayed" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.allow_users_to_hide_profile = true
    owner.user_option.update!(hide_profile: true)
    sign_in(viewer)
    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(response.body).to be_blank
    expect(response.headers["Location"]).to be_blank
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end

  it "does not aggregate when current platform rules invalidate the stored value" do
    SiteSetting.discourse_social_profile_track_clicks = true
    sign_in(viewer)
    link.update_column(:value, "https://evil.example/")
    post "/social-profile/click.json", params: { token: link.click_token }, xhr: true
    expect(response.status).to eq(204)
    expect(DiscourseSocialProfile::ClickStat.where(platform_id: platform.id)).to be_empty
  end
end
