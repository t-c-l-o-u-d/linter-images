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

errors=0

echo "Running csvclean..."
csvclean_fail=0
for csv_file in "${csv_files[@]}"; do
    if ! csvclean --enable-all-checks "$csv_file" > /dev/null; then
        csvclean_fail=1
    fi
done
if [[ ${csvclean_fail} -ne 0 ]]; then
    echo "FAIL: csvclean"
    errors=$((errors + 1))
else
    echo "PASS: csvclean"
fi

schema_file=""
if [[ -f .linter/csv-schema.json ]]; then
    schema_file=".linter/csv-schema.json"
elif [[ -f csv-schema.json ]]; then
    schema_file="csv-schema.json"
fi

if [[ -n "$schema_file" ]]; then
    echo "Running qsv validate (schema: ${schema_file})..."
    if ! qsv validate --json "${csv_files[@]}" "$schema_file"; then
        echo "FAIL: qsv validate"
        errors=$((errors + 1))
    else
        echo "PASS: qsv validate"
    fi
else
    echo "Skipping qsv validate (no csv-schema.json found)."
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "CSV linting failed with $errors error(s)"
    exit 1
fi
