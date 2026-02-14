#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
=========== Linter: javascript ============
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

errors=0

echo "Running eslint..."
if ! eslint "${js_files[@]}"; then
    echo "FAIL: eslint"
    errors=$((errors + 1))
else
    echo "PASS: eslint"
fi

echo ""
echo "Running biome check..."
if ! biome check "${js_files[@]}"; then
    echo "FAIL: biome check"
    errors=$((errors + 1))
else
    echo "PASS: biome check"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "JavaScript linting failed with $errors error(s)"
    exit 1
fi
