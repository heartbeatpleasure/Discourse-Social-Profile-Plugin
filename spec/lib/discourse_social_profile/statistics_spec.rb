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

  it "separates exactly five links from six or more" do
    five_user = Fabricate(:user)
    six_user = Fabricate(:user)
    6.times do |index|
      platform = DiscourseSocialProfile::Platform.create!(
        key: "distribution-#{index}",
        label: "Distribution #{index}",
        input_type: "url_any_https",
      )
      DiscourseSocialProfile::Link.create!(user: five_user, platform: platform, value: "https://example.com/five/#{index}") if index < 5
      DiscourseSocialProfile::Link.create!(user: six_user, platform: platform, value: "https://example.com/six/#{index}")
    end

    result = described_class.calculate
    expect(result.dig(:distribution, :five)).to eq(1)
    expect(result.dig(:distribution, :six_plus)).to eq(1)
  end

  it "uses exact 30-day and configured retention click windows" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.discourse_social_profile_click_stats_retention_days = 365
    p = DiscourseSocialProfile::Platform.create!(key: "click-window", label: "Window", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 29.days.ago.to_date, click_count: 2)
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 30.days.ago.to_date, click_count: 3)
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 364.days.ago.to_date, click_count: 5)
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: 365.days.ago.to_date, click_count: 99)

    result = described_class.calculate
    expect(result[:clicks_30d_total]).to eq(2)
    expect(result[:clicks_retention_total]).to eq(10)
    expect(result[:click_retention_days]).to eq(365)
    expect(result[:click_retention_matches_30d]).to eq(false)
    expect(result[:platforms].find { |row| row[:id] == p.id }[:clicks_retention]).to eq(10)
  end

  it "does not duplicate retention reporting when retention is exactly 30 days" do
    SiteSetting.discourse_social_profile_track_clicks = true
    SiteSetting.discourse_social_profile_click_stats_retention_days = 30
    p = DiscourseSocialProfile::Platform.create!(key: "click-thirty", label: "Thirty", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p, stat_date: Date.current, click_count: 2)

    result = described_class.calculate
    expect(result[:clicks_30d_total]).to eq(2)
    expect(result[:clicks_retention_total]).to eq(2)
    expect(result[:click_retention_matches_30d]).to eq(true)
  end

  it "reports aggregate click share only" do
    SiteSetting.discourse_social_profile_track_clicks = true
    p1 = DiscourseSocialProfile::Platform.create!(key: "click-one", label: "Click One", input_type: "url_any_https")
    p2 = DiscourseSocialProfile::Platform.create!(key: "click-two", label: "Click Two", input_type: "url_any_https")
    DiscourseSocialProfile::ClickStat.create!(platform: p1, stat_date: Date.current, click_count: 3)
    DiscourseSocialProfile::ClickStat.create!(platform: p2, stat_date: Date.current, click_count: 1)
    result = described_class.calculate
    expect(result[:clicks_30d_total]).to eq(4)
    expect(result[:clicks_retention_total]).to eq(4)
    expect(result[:clicks].find { |row| row[:platform_id] == p1.id }[:click_share_percentage]).to eq(75.0)
    expect(result[:platforms].find { |row| row[:id] == p1.id }[:clicks_30d]).to eq(3)
    expect(result[:platforms].find { |row| row[:id] == p2.id }[:clicks_30d]).to eq(1)
  end
end
