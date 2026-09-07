# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::Statistics do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  before { described_class.clear! }

  it "calculates adoption and distribution without person-level analytics" do
    p1 = DiscourseSocialProfile::Platform.create!(key: "stats-one", label: "One", input_type: "handle", base_url: "https://one.example/", allowed_hosts: "one.example")
    p2 = DiscourseSocialProfile::Platform.create!(key: "stats-two", label: "Two", input_type: "handle", base_url: "https://two.example/", allowed_hosts: "two.example")
    DiscourseSocialProfile::Link.create!(user: user1, platform: p1, value: "a")
    DiscourseSocialProfile::Link.create!(user: user1, platform: p2, value: "b")
    DiscourseSocialProfile::Link.create!(user: user2, platform: p1, value: "c")
    result = described_class.calculate
    expect(result[:users_with_profiles]).to eq(2)
    expect(result[:total_links]).to eq(3)
    expect(result.dig(:distribution, :one)).to eq(1)
    expect(result.dig(:distribution, :two)).to eq(1)
    expect(result.dig(:distribution, :five)).to eq(0)
    expect(result.dig(:distribution, :six_plus)).to eq(0)
    expect(result[:invalid_values_detected]).to eq(0)
  end

  it "uses an exact 30-calendar-day click window" do
    SiteSetting.discourse_social_profile_track_clicks = true
    p = DiscourseSocialProfile::Platform.create!(key: "click-window", label: "Window", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 29.days.ago.to_date, click_count: 2)
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 30.days.ago.to_date, click_count: 99)

    result = described_class.calculate
    expect(result[:clicks_30d_total]).to eq(2)
  end

  it "reports aggregate click share only" do
    SiteSetting.discourse_social_profile_track_clicks = true
    p1 = DiscourseSocialProfile::Platform.create!(key: "click-one", label: "Click One", input_type: "url_any_https")
    p2 = DiscourseSocialProfile::Platform.create!(key: "click-two", label: "Click Two", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p1, stat_date: Date.current, click_count: 3)
    DiscourseSocialProfile::ClickStat.create!(platform: p2, stat_date: Date.current, click_count: 1)
    result = described_class.calculate
    expect(result[:clicks_30d_total]).to eq(4)
    expect(result[:clicks].find { |row| row[:platform_id] == p1.id }[:click_share_percentage]).to eq(75.0)
    expect(result[:platforms].find { |row| row[:id] == p1.id }[:clicks_30d]).to eq(3)
    expect(result[:platforms].find { |row| row[:id] == p2.id }[:clicks_30d]).to eq(1)
  end
  it "reports the configured retained click window separately from the 30-day view" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.discourse_social_profile_click_stats_retention_days = 365
    p = DiscourseSocialProfile::Platform.create!(key: "retained-window", label: "Retained", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: Date.current, click_count: 2)
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 100.days.ago.to_date, click_count: 5)

    result = described_class.calculate
    platform = result[:platforms].find { |row| row[:id] == p.id }
    expect(result[:clicks_30d_total]).to eq(2)
    expect(result[:clicks_retained_total]).to eq(7)
    expect(result[:click_retention_days]).to eq(365)
    expect(result[:click_retention_label]).to eq("1 year")
    expect(platform[:clicks_30d]).to eq(2)
    expect(platform[:clicks_retained]).to eq(7)
  end

end
