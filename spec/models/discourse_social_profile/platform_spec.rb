# frozen_string_literal: true

RSpec.describe DiscourseSocialProfile::Platform do
  def valid_attrs
    {
      key: "platform-test",
      label: "Platform Test",
      input_type: "handle",
      base_url: "https://example.com/",
      allowed_hosts: "example.com",
    }
  end

  it "validates stable key uniqueness and input type" do
    described_class.create!(valid_attrs)
    expect(described_class.new(valid_attrs)).not_to be_valid
    expect(described_class.new(valid_attrs.merge(key: "bad key"))).not_to be_valid
    expect(described_class.new(valid_attrs.merge(key: "unique", input_type: "other"))).not_to be_valid
  end

  it "does not allow key changes after user data exists" do
    p = described_class.create!(valid_attrs)
    link = DiscourseSocialProfile::Link.create!(user: Fabricate(:user), platform: p, value: "alice")
    expect(link).to be_persisted
    p.key = "changed"
    expect(p).not_to be_valid
    expect(p.errors[:key]).to be_present
  end

  it "enforces the platform capacity" do
    stub_const("DiscourseSocialProfile::Platform::MAX_PLATFORMS", 1)
    described_class.create!(valid_attrs)
    second = described_class.new(valid_attrs.merge(key: "second"))
    expect(second).not_to be_valid
  end

  it "accepts supported public image and mask uploads and maintains references" do
    image = Fabricate(:upload, extension: "png", filesize: 1000, secure: false)
    mask = Fabricate(:upload, extension: "svg", filesize: 1000, secure: false)
    p = described_class.create!(valid_attrs.merge(icon_image_upload: image, icon_mask_upload: mask))
    expect(UploadReference.where(target: p).pluck(:upload_id)).to contain_exactly(image.id, mask.id)
  end

  it "rejects unsupported/private/oversized uploads" do
    bad = Fabricate(:upload, extension: "exe", filesize: 1000, secure: false)
    p = described_class.new(valid_attrs.merge(icon_image_upload: bad))
    expect(p).not_to be_valid
    private_upload = Fabricate(:upload, extension: "svg", filesize: 1000, secure: true)
    p = described_class.new(valid_attrs.merge(key: "private", icon_mask_upload: private_upload))
    expect(p).not_to be_valid
    large = Fabricate(:upload, extension: "png", filesize: 2.megabytes, secure: false)
    expect(described_class.new(valid_attrs.merge(key: "large", icon_image_upload: large))).not_to be_valid
  end

  it "resolves native uploads through GlobalPath" do
    upload = Fabricate(:upload, extension: "png", filesize: 1000, secure: false)
    p = described_class.create!(valid_attrs.merge(icon_image_upload: upload))
    expect(p.image_url).to eq(GlobalPath.full_cdn_url(upload.url))
  end
end
