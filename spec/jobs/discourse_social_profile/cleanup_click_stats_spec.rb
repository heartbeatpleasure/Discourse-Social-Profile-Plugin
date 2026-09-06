# frozen_string_literal: true

RSpec.describe Jobs::DiscourseSocialProfileCleanupClickStats do
  let!(:platform) { DiscourseSocialProfile::Platform.create!(key: "cleanup", label: "Cleanup", input_type: "url_any_https") }

  it "deletes only aggregates older than configured retention" do
    SiteSetting.discourse_social_profile_click_stats_retention_days = 365
    old = DiscourseSocialProfile::ClickStat.create!(platform: platform, stat_date: 365.days.ago.to_date, click_count: 1)
    keep = DiscourseSocialProfile::ClickStat.create!(platform: platform, stat_date: 364.days.ago.to_date, click_count: 1)
    described_class.new.execute({})
    expect(DiscourseSocialProfile::ClickStat.find_by(id: old.id)).to be_nil
    expect(DiscourseSocialProfile::ClickStat.find_by(id: keep.id)).to be_present
  end
end
