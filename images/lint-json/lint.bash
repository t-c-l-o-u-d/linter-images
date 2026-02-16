#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t json_files < <(git ls-files '*.json')

if [[ ${#json_files[@]} -eq 0 ]]; then
    echo "No JSON files found, skipping."
    exit 0
fi

echo "Running json syntax check..."
errors=0
for f in "${json_files[@]}"; do
    if ! output=$(python3 -m json.tool "$f" 2>&1 > /dev/null); then
        echo "  ${f}: ${output}"
        errors=$((errors + 1))
    fi
done

if [[ $errors -gt 0 ]]; then
    echo "FAIL: json syntax check"
    exit 1
else
    echo "PASS: json syntax check"
fi
