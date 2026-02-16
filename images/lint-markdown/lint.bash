#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t md_files < <(git ls-files '*.md')

if [[ ${#md_files[@]} -eq 0 ]]; then
    echo "No markdown files found, skipping."
    exit 0
fi

errors=0

echo "Running markdownlint-cli2..."
mdl_args=()
if [[ -f .linter/.markdownlint-cli2.yaml ]]; then
    mdl_args+=(--config .linter/.markdownlint-cli2.yaml)
elif [[ -f .markdownlint-cli2.yaml ]]; then
    mdl_args+=(--config .markdownlint-cli2.yaml)
fi
tool_errors=0
for f in "${md_files[@]}"; do
    if ! markdownlint-cli2 "${mdl_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: markdownlint-cli2 (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: markdownlint-cli2\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Markdown linting failed with $errors error(s)"
    exit 1
fi
