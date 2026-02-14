#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============== Linter: html ===============
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

mapfile -t html_files < <(git ls-files '*.html')

if [[ ${#html_files[@]} -eq 0 ]]; then
    echo "No HTML files found, skipping."
    exit 0
fi

echo "Running tidy (syntax check)..."
tidy_args=(-quiet -errors)
if [[ -f .linter/.tidyrc ]]; then
    tidy_args+=(-config .linter/.tidyrc)
elif [[ -f .tidyrc ]]; then
    tidy_args+=(-config .tidyrc)
fi
errors=0
for f in "${html_files[@]}"; do
    if ! tidy "${tidy_args[@]}" "$f" > /dev/null 2>&1; then
        echo "  WARN: $f"
        errors=$((errors + 1))
    fi
done

if [[ $errors -gt 0 ]]; then
    echo "FAIL: tidy found issues in $errors file(s)"
    exit 1
else
    echo "PASS: tidy syntax check"
fi
