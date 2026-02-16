#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

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
    if ! output=$(tidy "${tidy_args[@]}" "$f" 2>&1 > /dev/null); then
        echo "  ${f}:"
        echo "    ${output//$'\n'/$'\n'    }"
        errors=$((errors + 1))
    fi
done

if [[ $errors -gt 0 ]]; then
    echo "FAIL: tidy found issues in $errors file(s)"
    exit 1
else
    echo "PASS: tidy syntax check"
fi
