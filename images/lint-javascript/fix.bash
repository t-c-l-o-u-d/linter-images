#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============ Fixer: javascript ============
===========================================
============ Brought to you by ============
       _       _                 _
      | |_ ___| | ___  _   _  __| |
      | __/ __| |/ _ \| | | |/ _` |
      | || (__| | (_) | |_| | (_| |
       \__\___|_|\___/ \__,_|\__,_|
===========================================
===== https://github.com/t-c-l-o-u-d =====
===========================================
EOF
echo ""

mapfile -t js_files < <(git ls-files '*.js' '*.mjs' '*.cjs')

if [[ ${#js_files[@]} -eq 0 ]]; then
    echo "No JavaScript files found, skipping."
    exit 0
fi

echo "Running eslint --fix..."
es_args=(--fix)
if [[ -f .linter/eslint.config.js ]]; then
    es_args+=(--config .linter/eslint.config.js)
elif [[ -f eslint.config.js ]]; then
    es_args+=(--config eslint.config.js)
fi
eslint "${es_args[@]}" "${js_files[@]}"

echo "Running biome format --write..."
biome_args=(--write)
if [[ -f .linter/biome.json ]]; then
    biome_args+=(--config-path .linter)
elif [[ -f biome.json ]]; then
    biome_args+=(--config-path .)
fi
biome format "${biome_args[@]}" "${js_files[@]}"

echo "Done. Run lint to verify."
