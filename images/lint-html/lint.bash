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
elif [[ -f .linters/tidyrc ]]; then
    tidy_args+=(-config .linters/tidyrc)
elif [[ -f .tidyrc ]]; then
    tidy_args+=(-config .tidyrc)
fi
tool_errors=0
for f in "${html_files[@]}"; do
    if ! output=$(tidy "${tidy_args[@]}" "$f" 2>&1 > /dev/null); then
        printf "  FAIL: %s\n" "$f"
        printf "    %s\n" "${output//$'\n'/$'\n'    }"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done

if ((tool_errors > 0)); then
    printf "FAIL: tidy (%d file(s))\n" "$tool_errors"
    exit 1
else
    printf "PASS: tidy\n"
fi
