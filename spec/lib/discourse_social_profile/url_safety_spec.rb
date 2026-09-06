# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::UrlSafety do
  it "accepts normal public DNS names and public IP literals" do
    expect(described_class.public_host?("social.example.com")).to eq(true)
    expect(described_class.public_host?("8.8.8.8")).to eq(true)
    expect(described_class.public_host?("2606:4700:4700::1111")).to eq(true)
  end

  it "rejects local/private/reserved destinations and local search names" do
    %w[
      localhost
      localhost.localdomain
      home.arpa
      router.local
      service.internal
      gateway.lan
      intranet
      127.0.0.1
      10.0.0.1
      100.64.0.1
      169.254.169.254
      192.168.1.1
      ::1
      fe80::1
      fc00::1
      64:ff9b::c0a8:101
      2001::1
      2002:c0a8:0101::1
      100:0:0:1::1
    ].each do |host|
      expect(described_class.public_host?(host)).to eq(false), host
    end
  end

  it "rejects historical browser IPv4 spellings that IPAddr does not normalize" do
    %w[127.1 0177.0.0.1 0x7f000001 2130706433].each do |host|
      expect(described_class.public_host?(host)).to eq(false), host
    end
  end

  it "rejects malformed DNS labels instead of relying on parser differences" do
    %w[-bad.example bad-.example bad_name.example example..com].each do |host|
      expect(described_class.public_host?(host)).to eq(false), host
    end
  end
  it "rejects controls through multiple layers of percent encoding" do
    %w[%0a %250a %25250a %2525250d].each do |encoded|
      expect(described_class.unsafe_control_encoding?("https://example.com/#{encoded}")).to eq(true), encoded
    end
    expect(described_class.unsafe_control_encoding?("https://example.com/a%20b")).to eq(false)
  end

end
