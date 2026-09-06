# frozen_string_literal: true

require "json"

RSpec.describe DiscourseSocialProfile::DefaultPlatforms do
  it "preserves the 27 authoritative Theme Component platforms and appends plugin-native platforms" do
    fixture = JSON.parse(File.read(File.expand_path("../../fixtures/component_social_links.json", __dir__)))
    fixture_keys = fixture.map { |row| row["id"] }
    keys = described_class::DATA.map { |row| row[:key] }

    expect(keys.first(fixture_keys.length)).to eq(fixture_keys)
    expect(keys.drop(fixture_keys.length)).to eq(
      %w[
        reddit snapchat pinterest kick patreon kofi buymeacoffee beacons medium
        deviantart vimeo flickr chaturbate manyvids loyalfans clips4sale iwantclips
        redgifs xvideos
      ],
    )
    expect(described_class::DATA.length).to eq(46)
  end

  it "preserves validation and presentation defaults" do
    fixture = JSON.parse(File.read(File.expand_path("../../fixtures/component_social_links.json", __dir__)))
    by_key = described_class::DATA.index_by { |row| row[:key] }
    fixture.each do |row|
      actual = by_key.fetch(row["id"])
      expect(actual[:enabled]).to eq(row["enabled"])
      expect(actual[:label]).to eq(row["label"])
      expect(actual[:input_type]).to eq(row["input_type"])
      expect(actual[:base_url].to_s).to eq(row["base_url"].to_s)
      expect(actual[:allowed_hosts].to_s).to eq(row["allowed_hosts"].to_s)
      expect(actual[:path_regex].to_s).to eq(row["path_regex"].to_s)
      expected_icon = row["id"] == "x" ? "fab-x-twitter" : row["icon"]
      expect(actual[:icon_name]).to eq(expected_icon)
      expect(actual[:legacy_user_field_name]).to eq(row["user_field"])
    end
  end

  it "does not copy the missing Amazon mask asset reference" do
    amazon = described_class::DATA.find { |row| row[:key] == "amazon_wishlist" }
    expect(amazon[:builtin_icon]).to be_nil
    expect(amazon[:icon_name]).to eq("fab-amazon")
  end
end
