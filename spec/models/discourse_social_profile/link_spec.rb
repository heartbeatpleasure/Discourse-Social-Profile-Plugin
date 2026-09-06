# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::Link do
  fab!(:user) { Fabricate(:user) }
  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(key: "link-test", label: "Link Test", input_type: "handle", base_url: "https://example.com/u/", allowed_hosts: "example.com")
  end

  it "normalizes values and generates opaque fixed-length click tokens" do
    link = described_class.create!(user: user, platform: platform, value: " @alice ")
    expect(link.value).to eq("alice")
    expect(link.click_token).to match(described_class::CLICK_TOKEN_PATTERN)
    expect(link.click_token.length).to eq(32)
  end

  it "rotates the opaque click token when the destination changes" do
    link = described_class.create!(user: user, platform: platform, value: "alice")
    original_token = link.click_token

    link.update!(value: "bob")

    expect(link.click_token).to match(described_class::CLICK_TOKEN_PATTERN)
    expect(link.click_token).not_to eq(original_token)
  end

  it "keeps the click token stable when the destination does not change" do
    link = described_class.create!(user: user, platform: platform, value: "alice")
    original_token = link.click_token

    link.update!(value: " alice ")

    expect(link.reload.click_token).to eq(original_token)
  end

  it "allows only one value per user/platform" do
    described_class.create!(user: user, platform: platform, value: "alice")
    duplicate = described_class.new(user: user, platform: platform, value: "bob")
    expect(duplicate).not_to be_valid
  end

  it "rejects invalid values" do
    link = described_class.new(user: user, platform: platform, value: "https://evil.example/alice")
    expect(link).not_to be_valid
    expect(link.errors[:value]).to be_present
  end
end
