# frozen_string_literal: true

require "base64"

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

  def png_content
    Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    )
  end

  def safe_svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <path d="M1 1h22v22H1z"/>
      </svg>
    SVG
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
    image = Fabricate(:upload, extension: "png", filesize: png_content.bytesize, secure: false)
    mask = Fabricate(:upload, extension: "svg", filesize: safe_svg.bytesize, secure: false)
    allow(image).to receive(:content).and_return(png_content)
    allow(mask).to receive(:content).and_return(safe_svg)

    p = described_class.create!(valid_attrs.merge(icon_image_upload: image, icon_mask_upload: mask))
    expect(UploadReference.where(target: p).pluck(:upload_id)).to contain_exactly(image.id, mask.id)
  end

  it "rejects raster uploads whose content does not match the allowed image extension" do
    image = Fabricate(:upload, extension: "png", filesize: 14, secure: false)
    allow(image).to receive(:content).and_return("not really png")

    p = described_class.new(valid_attrs.merge(icon_image_upload: image))
    expect(p).not_to be_valid
    expect(p.errors[:icon_image_upload]).to be_present
  end

  it "rejects SVG scripts, external references and XML base overrides" do
    unsafe_samples = [
      '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg"><use href="https://evil.example/icon.svg#x"/></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg" xml:base="https://evil.example/"><use href="#x"/></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg"><style>.x{fill:url(https://evil.example/x)}</style></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg"><style>.x{background:image-set("https://evil.example/x" 1x)}</style></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg"><style>.x{fill:u\\72l(https://evil.example/x)}</style></svg>',
      '<svg xmlns="http://www.w3.org/2000/svg"><image href="https://evil.example/x.png"/></svg>',
      '<!DOCTYPE svg [<!ENTITY x "boom">]><svg xmlns="http://www.w3.org/2000/svg"><text>&x;</text></svg>',
      '<svg xmlns="https://evil.example/not-svg"><path d="M0 0"/></svg>',
    ]

    unsafe_samples.each_with_index do |content, index|
      mask = Fabricate(:upload, extension: "svg", filesize: content.bytesize, secure: false)
      allow(mask).to receive(:content).and_return(content)
      p = described_class.new(
        valid_attrs.merge(key: "unsafe-#{index}", icon_mask_upload: mask),
      )
      expect(p).not_to be_valid
      expect(p.errors[:icon_mask_upload]).to be_present
    end
  end

  it "rejects oversized raster dimensions even when the file itself is small" do
    image = Fabricate(:upload, extension: "png", filesize: png_content.bytesize, secure: false)
    allow(image).to receive(:content).and_return(png_content)
    fast_image = instance_double(FastImage, type: :png, size: [8192, 1])
    allow(FastImage).to receive(:new).and_return(fast_image)

    p = described_class.new(valid_attrs.merge(icon_image_upload: image))
    expect(p).not_to be_valid
    expect(p.errors[:icon_image_upload]).to be_present
  end

  it "rejects dangling upload identifiers before hitting database foreign keys" do
    p = described_class.new(valid_attrs.merge(icon_image_upload_id: 9_223_372_036_854_775_000))
    expect(p).not_to be_valid
    expect(p.errors[:icon_image_upload]).to be_present
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
    upload = Fabricate(:upload, extension: "png", filesize: png_content.bytesize, secure: false)
    allow(upload).to receive(:content).and_return(png_content)
    p = described_class.create!(valid_attrs.merge(icon_image_upload: upload))
    expect(p.image_url).to eq(GlobalPath.full_cdn_url(upload.url))
  end
end
