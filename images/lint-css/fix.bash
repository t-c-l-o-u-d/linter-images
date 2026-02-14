#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
=============== Fixer: css ================
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

mapfile -t css_files < <(git ls-files '*.css')

if [[ ${#css_files[@]} -eq 0 ]]; then
    echo "No CSS files found, skipping."
    exit 0
fi

echo "Running stylelint --fix..."
stylelint --fix "${css_files[@]}"

echo "Running biome format --write..."
biome format --write "${css_files[@]}"

echo "Done. Run lint to verify."
