# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::UserDataCleanup do
  fab!(:user) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(
      key: "cleanup-service",
      label: "Cleanup Service",
      input_type: "handle",
      base_url: "https://example.com/",
      allowed_hosts: "example.com",
    )
  end

  it "removes social-profile links" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    described_class.call(user.id)
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end

  it "still removes private data when Redis cannot provide the cleanup mutex" do
    DiscourseSocialProfile::Link.create!(user: user, platform: platform, value: "alice")
    allow(DistributedMutex).to receive(:synchronize).and_raise(Redis::CannotConnectError)

    described_class.call(user.id)
    expect(DiscourseSocialProfile::Link.where(user_id: user.id)).to be_empty
  end
end
