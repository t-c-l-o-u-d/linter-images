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
if ! markdownlint-cli2 "${mdl_args[@]}" "${md_files[@]}"; then
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
