# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::UserDataMerger do
  fab!(:source_user) { Fabricate(:user) }
  fab!(:target_user) { Fabricate(:user) }

  let!(:platform_a) do
    DiscourseSocialProfile::Platform.create!(
      key: "merge-a",
      label: "Merge A",
      input_type: "handle",
      base_url: "https://example.com/a/",
      allowed_hosts: "example.com",
    )
  end

  let!(:platform_b) do
    DiscourseSocialProfile::Platform.create!(
      key: "merge-b",
      label: "Merge B",
      input_type: "handle",
      base_url: "https://example.com/b/",
      allowed_hosts: "example.com",
    )
  end

  it "moves source-only links to the target and preserves their click token" do
    source_link =
      DiscourseSocialProfile::Link.create!(
        user: source_user,
        platform: platform_a,
        value: "source-a",
      )
    token = source_link.click_token

    described_class.call(source_user.id, target_user.id)

    moved = DiscourseSocialProfile::Link.find_by(user_id: target_user.id, platform_id: platform_a.id)
    expect(moved).to be_present
    expect(moved.value).to eq("source-a")
    expect(moved.click_token).to eq(token)
    expect(DiscourseSocialProfile::Link.where(user_id: source_user.id)).to be_empty
  end

  it "keeps the target value when both users have the same platform" do
    DiscourseSocialProfile::Link.create!(
      user: source_user,
      platform: platform_a,
      value: "source-a",
    )
    target_link =
      DiscourseSocialProfile::Link.create!(
        user: target_user,
        platform: platform_a,
        value: "target-a",
      )

    described_class.call(source_user.id, target_user.id)

    remaining = DiscourseSocialProfile::Link.where(user_id: target_user.id, platform_id: platform_a.id)
    expect(remaining.count).to eq(1)
    expect(remaining.first.id).to eq(target_link.id)
    expect(remaining.first.value).to eq("target-a")
    expect(DiscourseSocialProfile::Link.where(user_id: source_user.id, platform_id: platform_a.id)).to be_empty
  end

  it "moves source-only rows while preserving unrelated target rows" do
    DiscourseSocialProfile::Link.create!(
      user: source_user,
      platform: platform_a,
      value: "source-a",
    )
    DiscourseSocialProfile::Link.create!(
      user: target_user,
      platform: platform_b,
      value: "target-b",
    )

    described_class.call(source_user.id, target_user.id)

    values =
      DiscourseSocialProfile::Link
        .where(user_id: target_user.id)
        .order(:platform_id)
        .pluck(:platform_id, :value)
        .to_h
    expect(values).to eq(platform_a.id => "source-a", platform_b.id => "target-b")
  end

  it "falls back to database conflict protection when the Redis mutex is unavailable" do
    DiscourseSocialProfile::Link.create!(
      user: source_user,
      platform: platform_a,
      value: "source-a",
    )
    allow(DistributedMutex).to receive(:synchronize).and_raise(Redis::CannotConnectError)

    expect { described_class.call(source_user.id, target_user.id) }.not_to raise_error
    expect(
      DiscourseSocialProfile::Link.exists?(user_id: target_user.id, platform_id: platform_a.id),
    ).to eq(true)
  end

  it "is a no-op when source and target are the same account" do
    link =
      DiscourseSocialProfile::Link.create!(
        user: source_user,
        platform: platform_a,
        value: "source-a",
      )

    expect(described_class.call(source_user.id, source_user.id)).to eq(true)
    expect(link.reload.user_id).to eq(source_user.id)
  end
end
