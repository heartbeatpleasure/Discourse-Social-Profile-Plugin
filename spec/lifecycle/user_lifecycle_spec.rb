# frozen_string_literal: true

RSpec.describe "Social profile user lifecycle" do
  fab!(:user) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "lifecycle", label: "Lifecycle", input_type: "handle", base_url: "https://example.com/", allowed_hosts: "example.com")
  end

  before { SiteSetting.discourse_social_profile_enabled = true }

  it "removes plugin-owned data on user destruction" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "name")
    DiscourseEvent.trigger(:user_destroyed, user)
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end

  it "removes identifiers on anonymization" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "name")
    DiscourseEvent.trigger(:user_anonymized, user: user, opts: {})
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end

  it "still removes identifiers when the UI setting is disabled" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "name")
    SiteSetting.discourse_social_profile_enabled = false
    DiscourseEvent.trigger(:user_anonymized, user: user, opts: {})
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end

  it "includes raw values in the preferences payload used by user archive export" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "name")
    job = Jobs::ExportUserArchive.new
    job.archive_for_user = user
    expect(job.preferences_export.as_json[:social_profile_values]).to include(platform_key: "lifecycle", platform_label: "Lifecycle", value: "name")
  end

  it "keeps owner export data available even when the master UI setting is disabled" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "name")
    SiteSetting.discourse_social_profile_enabled = false
    json = UserSerializer.new(user, scope: Guardian.new(user), root: false).as_json
    expect(json[:social_profile_values]).to include(platform_key: "lifecycle", platform_label: "Lifecycle", value: "name")
  end
end
