# frozen_string_literal: true

describe "Social Profiles plugin" do
  fab!(:viewer) { Fabricate(:user) }
  fab!(:owner) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:post) { Fabricate(:post, user: owner) }

  let!(:platform) do
    DiscourseSocialProfile::Platform.create!(
      key: "system-profile",
      label: "System Profile",
      input_type: "handle",
      base_url: "https://example.com/u/",
      allowed_hosts: "example.com",
      enabled: true,
      position: 0,
      icon_name: "globe",
    )
  end
  let!(:link) { DiscourseSocialProfile::Link.create!(user: owner, platform: platform, value: "owner") }

  before do
    SiteSetting.discourse_social_profile_enabled = true
    SiteSetting.discourse_social_profile_show_on_profile = true
    SiteSetting.discourse_social_profile_show_on_user_card = true
    sign_in(viewer)
  end

  it "shows another ordinary user's icon on the full profile without Custom User Fields" do
    visit("/u/#{owner.username}")
    expect(page).to have_css(".iconic-user-fields a[href='https://example.com/u/owner'][aria-label='System Profile']")
  end

  it "shows the same link on the user card" do
    visit("/t/#{post.topic.slug}/#{post.topic.id}")
    find("article[data-post-id='#{post.id}'] .names a", match: :first).click
    expect(page).to have_css(".user-card .iconic-user-fields a[href='https://example.com/u/owner']")
  end

  it "does not render social links for a hidden profile viewed by a normal user" do
    SiteSetting.allow_users_to_hide_profile = true
    owner.user_option.update!(hide_profile: true)
    visit("/u/#{owner.username}")
    expect(page).to have_no_css(".iconic-user-fields")
  end

  it "allows a user to save a social profile through the dedicated Preferences tab" do
    sign_in(owner)
    DiscourseSocialProfile::Link.where(user: owner, platform: platform).delete_all
    visit("/u/#{owner.username}/preferences/social-profiles")
    find(".social-profile-preferences input").fill_in(with: "new-owner")
    find(".social-profile-preferences__actions .btn-primary").click
    expect(page).to have_content(I18n.t("js.discourse_social_profile.preferences.saved"))
    expect(DiscourseSocialProfile::Link.find_by(user: owner, platform: platform).value).to eq("new-owner")
  end

  it "shows validation feedback and lets the owner remove a value from Preferences" do
    sign_in(owner)
    visit("/u/#{owner.username}/preferences/social-profiles")
    input = find(".social-profile-preferences input")
    input.fill_in(with: "https://evil.example/profile")
    find(".social-profile-preferences__actions .btn-primary").click
    expect(page).to have_css(".social-profile-preferences__error")
    expect(link.reload.value).to eq("owner")

    input.fill_in(with: "")
    find(".social-profile-preferences__actions .btn-primary").click
    expect(page).to have_content(I18n.t("js.discourse_social_profile.preferences.saved"))
    expect(DiscourseSocialProfile::Link.find_by(user: owner, platform: platform)).to be_nil
  end

  it "lets an admin create a custom platform through the modern plugin admin form" do
    sign_in(admin)
    visit("/admin/plugins/discourse-social-profile/platforms/new")
    form = PageObjects::Components::FormKit.new(".form-kit")
    form.field("key").fill_in("system-admin")
    form.field("label").fill_in("System Admin")
    form.field("base_url").fill_in("https://system-admin.example/")
    form.field("allowed_hosts").fill_in("system-admin.example")
    form.submit
    expect(page).to have_current_path(%r{/admin/plugins/discourse-social-profile/platforms/\d+/edit})
    created = DiscourseSocialProfile::Platform.find_by(key: "system-admin")
    expect(created).to be_present
    expect(created.label).to eq("System Admin")
  end
end
