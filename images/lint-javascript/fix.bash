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
eslint --fix "${js_files[@]}"

echo "Running biome format --write..."
biome format --write "${js_files[@]}"

echo "Done. Run lint to verify."
