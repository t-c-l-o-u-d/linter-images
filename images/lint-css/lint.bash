#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
=============== Linter: css ===============
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

errors=0

echo "Running stylelint..."
if ! stylelint "${css_files[@]}"; then
    echo "FAIL: stylelint"
    errors=$((errors + 1))
else
    echo "PASS: stylelint"
fi

echo ""
echo "Running biome check..."
if ! biome check "${css_files[@]}"; then
    echo "FAIL: biome check"
    errors=$((errors + 1))
else
    echo "PASS: biome check"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "CSS linting failed with $errors error(s)"
    exit 1
fi
