#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Source contract =="
ruby script/source_contract_check.rb

echo
echo "== Isolated services =="
ruby script/isolated_url_safety_check.rb | tail -1
ruby script/isolated_link_builder_check.rb | tail -1
ruby script/isolated_platform_validator_check.rb | tail -1
ruby script/default_platforms_validator_check.rb
ruby script/default_platforms_link_check.rb

echo
echo "== Ruby parse =="
ruby_files=0
while IFS= read -r -d '' file; do
  ruby -c "$file" >/dev/null
  ruby -cw "$file" >/dev/null
  ruby_files=$((ruby_files + 1))
done < <(find . -type f -name '*.rb' -print0)
echo "Ruby files parsed with -c and -cw: $ruby_files"

echo
echo "== Plain JavaScript parse =="
js_files=0
while IFS= read -r -d '' file; do
  node --check "$file" >/dev/null
  js_files=$((js_files + 1))
done < <(find assets admin test -type f -name '*.js' -print0 2>/dev/null || true)
echo "Plain .js files parsed by node --check: $js_files"

echo
echo "== YAML/JSON parse =="
ruby -ryaml -e 'Dir["**/*.{yml,yaml}"].each { |f| YAML.load_file(f, aliases: true) }; puts "YAML: PASS"'
ruby -rjson -e 'Dir["**/*.json"].each { |f| JSON.parse(File.read(f)) }; puts "JSON: PASS"'

echo
echo "== Filesystem hygiene =="
symlinks=$(find . -type l | wc -l)
world_writable=$(find . -type f -perm -0002 | wc -l)
temp_files=$(find . -type f \( -name '*~' -o -name '*.bak' -o -name '*.tmp' -o -name '*.swp' \) | wc -l)
echo "Symlinks: $symlinks"
echo "World-writable files: $world_writable"
echo "Backup/temp files: $temp_files"
test "$symlinks" -eq 0
test "$world_writable" -eq 0
test "$temp_files" -eq 0

echo
echo "Static release audit: PASS"
