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

  it "moves plugin-owned data during Discourse user merge even when the UI setting is disabled" do
    target_user = Fabricate(:user)
    source_link = DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "source-name")
    token = source_link.click_token
    SiteSetting.discourse_social_profile_enabled = false

    DiscourseEvent.trigger(:merging_users, user, target_user)

    moved = DiscourseSocialProfile::Link.find_by(user_id: target_user.id, platform_id: platform.id)
    expect(moved).to be_present
    expect(moved.value).to eq("source-name")
    expect(moved.click_token).to eq(token)
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end

  it "preserves the target social profile when merged users share a platform" do
    target_user = Fabricate(:user)
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "source-name")
    target_link = DiscourseSocialProfile::Link.create!(user: target_user, platform: platform, value: "target-name")

    DiscourseEvent.trigger(:merging_users, user, target_user)

    expect(target_link.reload.value).to eq("target-name")
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
