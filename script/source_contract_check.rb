# frozen_string_literal: true

require "digest"
require "json"
require "yaml"
require "pathname"

ROOT = Pathname.new(File.expand_path("..", __dir__))
checks = []

def check(checks, name)
  yield
  checks << [name, true, nil]
rescue => e
  checks << [name, false, "#{e.class}: #{e.message}"]
end

def assert(value, message)
  raise message unless value
end

def read(path)
  (ROOT / path).read
end

check(checks, "Ruby syntax") do
  files = Dir[ROOT.join("**/*.rb")]
  assert(files.any?, "no Ruby files")
  bad = files.reject { |f| system({ "TERM" => "xterm" }, "ruby", "-c", f, out: File::NULL, err: File::NULL) }
  assert(bad.empty?, "syntax failure: #{bad.join(', ')}")
end

check(checks, "YAML syntax") do
  Dir[ROOT.join("**/*.{yml,yaml}")].each { |f| YAML.load_file(f, aliases: true) }
end

check(checks, "JSON fixtures") do
  Dir[ROOT.join("**/*.json")].each { |f| JSON.parse(File.read(f)) }
end

check(checks, "27 authoritative component defaults") do
  fixture = JSON.parse(read("spec/fixtures/component_social_links.json"))
  assert(fixture.length == 27, "expected 27 fixture platforms")
  assert(fixture.all? { |r| r.keys.length == 16 }, "fixture must preserve 16 properties")
  source = read("lib/discourse_social_profile/default_platforms.rb")
  keys = fixture.map { |r| r.fetch("id") }
  positions = keys.map { |k| source.index(%(key: "#{k}")) }
  assert(positions.none?(&:nil?) && positions == positions.sort, "default key order drift")
  fixture.each do |r|
    assert(source.include?(%(label: #{r["label"].to_json})), "label drift #{r['id']}")
    assert(source.include?(%(input_type: #{r["input_type"].to_json})), "input type drift #{r['id']}")
  end
end

check(checks, "Global parity defaults and SVG registrations") do
  fixture = JSON.parse(read("spec/fixtures/component_global_settings.json"))
  settings = YAML.load_file(ROOT / "config/settings.yml", aliases: true).fetch("plugins")
  assert(settings.dig("discourse_social_profile_icon_color", "default") == fixture["icon_color"], "light color drift")
  assert(settings.dig("discourse_social_profile_icon_color_dark", "default") == fixture["icon_color_dark"], "dark color drift")
  assert(settings.dig("discourse_social_profile_use_platform_colors", "default") == fixture["use_platform_colors"], "platform color drift")
  assert(read("plugin.rb").include?("fab-amazon"), "Amazon fallback icon not preloaded")
end

check(checks, "Every default Discourse icon is preloaded") do
  fixture = JSON.parse(read("spec/fixtures/component_social_links.json"))
  icons = fixture.map { |r| r["icon"] }.reject(&:empty?).uniq
  plugin = read("plugin.rb")
  missing = icons.reject { |icon| plugin.include?(icon) }
  assert(missing.empty?, "missing icons: #{missing.join(', ')}")
end

check(checks, "Bundled icon assets") do
  expected = {
    "discord-mask.svg" => "2f6e3fa93dd92de075e4a3dbb4fe2a9bb6f803f326087b92f4f1b729f5db3b59",
    "linktree.svg" => "4a554e87205a25aaaf6e71d193476796776f076814bd1d8cdd340e10912b4217",
    "onlyfans.svg" => "92c908fa21e545b68874793d47b92139be2a4df354b18de88efbec8b22bcb6c0",
    "pornhub.svg" => "9c4c134bf784f7898ab52257d78429dc7c24e44480f4246cf39dabd4e5a5153b",
    "fansly.svg" => "9ec4d2227ef656e34a1f33187a6428de87f527fb0c21fb3be5cdf1dd582a11e5",
    "fetlife.svg" => "ab0675865a5b4fcdcef8b90ef685cdfaef6a3b662135812dc72d4cb506705bfd",
    "tumblr.svg" => "abcc27a32320a2c046729332bf555f63139e7b8dea1838ef8811cad7ef0e79fd",
    "fancentro.svg" => "ce91014f142df2b69952b98a2fb37fed12a329b038303633199f305bd8f3150e",
  }
  expected.each do |name, sha|
    path = ROOT / "public/images/social-profile" / name
    assert(path.exist?, "missing #{name}")
    assert(Digest::SHA256.file(path).hexdigest == sha, "hash mismatch #{name}")
    text = path.read.downcase
    assert(!text.match?(/<script|onload\s*=|onclick\s*=|javascript:|<foreignobject/), "active marker #{name}")
  end
  assert(!(ROOT / "public/images/social-profile/amazon.svg").exist?, "must not invent missing amazon.svg")
end

check(checks, "Plugin public asset base") do
  plugin = read("plugin.rb")
  model = read("app/models/discourse_social_profile/platform.rb")
  assert(plugin.include?('# name: Discourse-Social-Profile-Plugin'), "plugin metadata must match canonical GitHub install directory")
  assert(plugin.include?('PLUGIN_NAME = "Discourse-Social-Profile-Plugin"'), "runtime plugin identity mismatch")
  assert(model.include?("Discourse.base_path") && model.include?("PUBLIC_ASSET_BASE"), "subfolder-safe asset path absent")
end

check(checks, "No Custom User Field runtime dependency") do
  runtime = %w[plugin.rb app lib assets admin].flat_map { |p| (ROOT / p).directory? ? Dir[ROOT.join(p, "**/*")] : [ROOT / p] }.select { |f| File.file?(f) }.map { |f| File.read(f) }.join("\n")
  %w[model.user_fields UserField modifyClass].each { |term| assert(!runtime.include?(term), "forbidden runtime term #{term}") }
end

check(checks, "No unsafe frontend HTML injection") do
  frontend = Dir[ROOT.join("{assets,admin,test}/**/*.{js,gjs}")].map { |f| File.read(f) }.join("\n")
  %w[innerHTML insertAdjacentHTML trustHTML].each { |term| assert(!frontend.include?(term), "unsafe frontend API #{term}") }
end

check(checks, "Relative-URL-root-safe server paths") do
  presenter = read("lib/discourse_social_profile/profile_presenter.rb")
  platform = read("app/models/discourse_social_profile/platform.rb")
  assert(presenter.include?("Discourse.base_path"), "click route not base_path safe")
  assert(platform.include?("GlobalPath.full_cdn_url") && platform.include?("Discourse.base_path"), "upload/bundled path not safe")
end

check(checks, "Stable frontend compatibility guards") do
  all = Dir[ROOT.join("{assets,admin}/**/*.{js,gjs}")].map { |f| File.read(f) }.join("\n")
  assert(!all.include?("register_svg_icon_source"), "main-only API in frontend")
  assert(all.include?("colorModeIsDark") && all.include?("colorModeIsLight"), "InterfaceColor stable getters not used")
  assert(read("admin/assets/javascripts/discourse/components/social-profile-platform-editor.gjs").include?('@icon="flask"'), "stable flask icon not used")
end

check(checks, "Profile icon CSS preserves Theme Component sizing semantics") do
  css = read("assets/stylesheets/common/social-profile.scss")
  assert(css.include?("margin-right: 5px"), "5px spacing missing")
  assert(css.scan("1.2em").length >= 5, "1.2em sizing missing")
  assert(css.include?("0.85"), "badge glyph scale missing")
  assert(read("assets/stylesheets/mobile/social-profile.scss").include?("padding-bottom: 2em"), "mobile parity missing")
end

check(checks, "Scheme-dependent badge parity") do
  gjs = read("assets/javascripts/discourse/components/social-profile-icons.gjs")
  assert(gjs.include?("badgeBackgroundFor") && gjs.include?("dark || light") && gjs.include?("frameClass"), "badge scheme fallback missing")
end

check(checks, "Full-color upload format policy") do
  model = read("app/models/discourse_social_profile/platform.rb")
  assert(model.include?("%w[png jpg jpeg svg webp]") && model.include?("%w[svg]"), "upload extensions drift")
  assert(model.include?("MAX_ICON_UPLOAD_BYTES = 1.megabyte"), "size bound missing")
  assert(model.include?("must not be a secure upload"), "secure upload rejection missing")
end

check(checks, "Preferences capacity is bounded by platform capacity") do
  prefs = read("app/controllers/discourse_social_profile/preferences_controller.rb")
  model = read("app/models/discourse_social_profile/platform.rb")
  assert(model.include?("MAX_PLATFORMS = 250"), "platform bound missing")
  assert(prefs.include?("MAX_PREFERENCES_ENTRIES = Platform::MAX_PLATFORMS"), "shared capacity constant missing")
  assert(prefs.index("raw_entries.length") < prefs.index("permitted_links(raw_entries)"), "oversize check occurs too late")
end

check(checks, "Path regex compilation is bounded and cached") do
  builder = read("lib/discourse_social_profile/link_builder.rb")
  assert(builder.include?("LruRedux::ThreadSafeCache.new(REGEX_CACHE_SIZE)"), "LRU cache missing")
  assert(builder.include?("Regexp.new(pattern.to_s, timeout: REGEX_TIMEOUT)"), "per-regex timeout missing")
end

check(checks, "Lifecycle cleanup ignores the enabled UI setting") do
  plugin = read("plugin.rb")
  assert(plugin.include?("DiscourseEvent.on(:user_destroyed)") && plugin.include?("DiscourseEvent.on(:user_anonymized)"), "direct lifecycle hooks missing")
  lifecycle = plugin[plugin.index("DiscourseEvent.on(:user_destroyed)")..]
  assert(!lifecycle.lines.first(18).join.include?("discourse_social_profile_enabled"), "cleanup incorrectly gated")
end

check(checks, "Expected profile/card outlets") do
  renderer = read("assets/javascripts/discourse/api-initializers/social-profile-renderer.js")
  assert(renderer.include?('"user-post-names"') && renderer.include?('"user-card-post-names"'), "outlet mismatch")
end

check(checks, "Serializer registration order") do
  plugin = read("plugin.rb")
  card = plugin.index(":user_card,")
  user = plugin.index(":user,", card + 1)
  assert(card && user && card < user, "user_card must be registered before user")
end

check(checks, "Admin candidate validation preserves record identity") do
  c = read("app/controllers/discourse_social_profile/admin/platforms_controller.rb")
  assert(c.scan("candidate = Platform.find(@platform.id)").length >= 2, "persisted candidate missing")
  assert(!c.include?("@platform.dup"), "dup uniqueness bug present")
end

check(checks, "Discourse 2026.7 stable API compatibility") do
  plugin = read("plugin.rb")
  admin = read("assets/javascripts/discourse/admin-social-profile-plugin-route-map.js")
  nav = read("assets/javascripts/discourse/initializers/social-profile-admin-plugin-configuration-nav.js")
  assert(plugin.include?("# required_version: 2026.7.2"), "required_version drift")
  assert(plugin.include?("use_new_show_route: true"), "modern admin route missing")
  assert(admin.include?('resource: "admin.adminPlugins.show"'), "modern route map missing")
  assert(nav.include?("addAdminPluginConfigurationNav"), "modern plugin nav missing")
end

check(checks, "Admin plugin identity matches canonical GitHub install directory") do
  plugin = read("plugin.rb")
  nav = read("assets/javascripts/discourse/initializers/social-profile-admin-plugin-configuration-nav.js")
  identity = "Discourse-Social-Profile-Plugin"
  assert(plugin.include?("# name: #{identity}"), "metadata identity drift")
  assert(plugin.include?(%(PLUGIN_NAME = "#{identity}")), "requires_plugin identity drift")
  admin_route = plugin[/add_admin_route\(.*?\n\)/m]
  assert(admin_route&.include?(%("#{identity}")), "new-show admin route location must match canonical plugin ID")
  assert(admin_route&.include?("use_new_show_route: true"), "new-show admin route flag missing")
  assert(nav.include?(%(const PLUGIN_ID = "#{identity}";)), "admin navigation identity drift")
  assert(nav.index('route: "adminPlugins.show.discourse-social-profile-overview"') < nav.index('route: "adminPlugins.show.discourse-social-profile-platforms"'), "overview must remain first custom admin route")
end

check(checks, "Admin landing page is the dashboard before settings") do
  overview = read("admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-social-profile-overview.gjs")
  legacy_nav = read("admin/assets/javascripts/discourse/initializers/social-profile-admin-plugin-configuration-nav.js")
  assert(overview.include?("social-profile-admin-dashboard__grid"), "dashboard card grid missing")
  assert(overview.include?("/admin/plugins/Discourse-Social-Profile-Plugin/settings"), "dashboard settings destination missing")
  assert(overview.include?("/admin/plugins/Discourse-Social-Profile-Plugin/platforms"), "dashboard platforms destination missing")
  assert(overview.include?("/admin/plugins/Discourse-Social-Profile-Plugin/statistics"), "dashboard statistics destination missing")
  assert(legacy_nav.include?("legacy-stub") && !legacy_nav.include?("addAdminPluginConfigurationNav"), "legacy admin initializer must not double-register navigation")
end

check(checks, "URL and identifier canonicalization follows parity contract") do
  b = read("lib/discourse_social_profile/link_builder.rb")
  assert(b.include?("normalize_identifier") && b.include?("URI.encode_www_form_component"), "identifier normalization missing")
  assert(b.include?("canonical_uri.host = host") && b.include?("canonical_uri.port = nil"), "full URL canonicalization missing")
  assert(b.include?("normalize_url_path"), "pathname normalization missing")
end

check(checks, "Generated identifiers keep full-URL host/path rules separate") do
  b = read("lib/discourse_social_profile/link_builder.rb")
  assert(b.include?("unless generated") && b.include?("if generated"), "generated/full URL split missing")
end

check(checks, "Valid full-URL parity plus redirector hardening") do
  b = read("lib/discourse_social_profile/link_builder.rb")
  assert(b.include?("return validate_url(@raw, hosts_required: true) if @raw.match?"), "full handle URL parity missing")
  assert(b.include?("redirector_like?") && b.include?("MAX_REDIRECT_DECODE_PASSES"), "redirector hardening missing")
end

check(checks, "Malformed request payloads fail closed") do
  prefs = read("app/controllers/discourse_social_profile/preferences_controller.rb")
  admin = read("app/controllers/discourse_social_profile/admin/platforms_controller.rb")
  assert(prefs.include?("links must be an array") && prefs.include?("each links entry must be an object"), "preferences shape checks missing")
  assert(admin.include?("platform must be an object"), "admin platform shape check missing")
end

check(checks, "Strict identifier parsing at request boundaries") do
  prefs = read("app/controllers/discourse_social_profile/preferences_controller.rb")
  admin = read("app/controllers/discourse_social_profile/admin/platforms_controller.rb")
  assert(prefs.include?("Integer(value.to_s, 10)") && admin.include?("Integer(value.to_s, 10)"), "strict numeric parse missing")
  clicks = read("app/controllers/discourse_social_profile/clicks_controller.rb")
  assert(clicks.include?("CLICK_TOKEN_PATTERN"), "strict click token parse missing")
end

check(checks, "Opaque click redirect identifiers") do
  link = read("app/models/discourse_social_profile/link.rb")
  presenter = read("lib/discourse_social_profile/profile_presenter.rb")
  assert(link.include?("SecureRandom.urlsafe_base64(CLICK_TOKEN_BYTES)"), "random token missing")
  assert(link.include?("CLICK_TOKEN_LENGTH = 32"), "token length drift")
  assert(presenter.include?("link.click_token"), "presenter not token based")
  assert(!presenter.include?('/social-profile/click/#{link.id}'), "sequential link id exposed")
end

check(checks, "Click analytics is aggregate-only") do
  migration = read("db/migrate/20260905000300_create_discourse_social_profile_click_stats.rb")
  %w[user_id link_id ip user_agent referrer destination].each { |col| assert(!migration.include?(col), "sensitive click column #{col}") }
  assert(migration.include?(":stat_date") && migration.include?(":platform_id") && migration.include?(":click_count"), "aggregate columns missing")
end

check(checks, "Database constraints and migration count") do
  migrations = Dir[ROOT.join("db/migrate/*.rb")]
  assert(migrations.length == 4, "expected 4 migrations including seed")
  links = read("db/migrate/20260905000200_create_discourse_social_profile_links.rb")
  clicks = read("db/migrate/20260905000300_create_discourse_social_profile_click_stats.rb")
  assert(links.include?("unique: true") && links.include?("on_delete: :cascade") && links.include?("on_delete: :restrict"), "link constraints missing")
  assert(clicks.include?("idx_social_profile_clicks_date_platform") && clicks.include?("unique: true"), "click unique pair missing")
end

check(checks, "Legacy data import intentionally absent") do
  runtime = Dir[ROOT.join("{app,lib,db}/**/*")].select { |f| File.file?(f) }.map { |f| File.read(f) }.join("\n")
  assert(!runtime.include?("UserField"), "legacy UserField runtime/import dependency")
  assert(Dir[ROOT.join("**/*migration*wiz*")].empty?, "migration wizard present")
end

passed = checks.count { |_, ok, _| ok }
failed = checks.length - passed
puts "Source contract checks: #{passed} passed, #{failed} failed"
checks.each do |name, ok, error|
  puts "#{ok ? 'PASS' : 'FAIL'}  #{name}#{error ? " — #{error}" : ''}"
end
exit(failed.zero? ? 0 : 1)
