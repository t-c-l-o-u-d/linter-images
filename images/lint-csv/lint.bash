#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t csv_files < <(git ls-files '*.csv')

if [[ ${#csv_files[@]} -eq 0 ]]; then
    echo "No CSV files found, skipping."
    exit 0
fi

echo "Running csv syntax check..."
errors=0
for f in "${csv_files[@]}"; do
    if ! output=$(python3 /usr/local/lib/csvcheck.py "$f" 2>&1); then
        echo "  ${f}: ${output}"
        errors=$((errors + 1))
    fi
done

if [[ $errors -gt 0 ]]; then
    echo "FAIL: csv syntax check"
    exit 1
else
    echo "PASS: csv syntax check"
fi
