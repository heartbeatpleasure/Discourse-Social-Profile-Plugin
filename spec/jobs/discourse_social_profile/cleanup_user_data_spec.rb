# frozen_string_literal: true

RSpec.describe Jobs::DiscourseSocialProfileCleanupUserData do
  fab!(:user) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(
      key: "user-cleanup",
      label: "User Cleanup",
      input_type: "handle",
      base_url: "https://example.com/",
      allowed_hosts: "example.com",
    )
  end

  it "removes retained social-profile data for the requested user" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    described_class.new.execute(user_id: user.id)
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end
end
