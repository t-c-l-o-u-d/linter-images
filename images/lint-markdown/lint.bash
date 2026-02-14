#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============ Linter: markdown ============
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

mapfile -t md_files < <(git ls-files '*.md')

if [[ ${#md_files[@]} -eq 0 ]]; then
    echo "No markdown files found, skipping."
    exit 0
fi

errors=0

echo "Running markdownlint-cli2..."
if ! markdownlint-cli2 "${md_files[@]}"; then
    echo "FAIL: markdownlint-cli2"
    errors=$((errors + 1))
else
    echo "PASS: markdownlint-cli2"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Markdown linting failed with $errors error(s)"
    exit 1
fi
