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
tool_errors=0
for csv_file in "${csv_files[@]}"; do
    if ! csvclean --enable-all-checks "$csv_file" > /dev/null; then
        printf "  FAIL: %s\n" "$csv_file"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$csv_file"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: csvclean (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: csvclean\n"
fi

schema_file=""
if [[ -f .linter/csv-schema.json ]]; then
    schema_file=".linter/csv-schema.json"
elif [[ -f .linters/csv-schema.json ]]; then
    schema_file=".linters/csv-schema.json"
elif [[ -f csv-schema.json ]]; then
    schema_file="csv-schema.json"
fi

if [[ -n "$schema_file" ]]; then
    echo "Running qsv validate (schema: ${schema_file})..."
    tool_errors=0
    for f in "${csv_files[@]}"; do
        if ! qsv validate --json "$f" "$schema_file"; then
            printf "  FAIL: %s\n" "$f"
            tool_errors=$((tool_errors + 1))
        else
            printf "  PASS: %s\n" "$f"
        fi
    done
    if ((tool_errors > 0)); then
        printf "FAIL: qsv validate (%d file(s))\n" "$tool_errors"
        errors=$((errors + 1))
    else
        printf "PASS: qsv validate\n"
    fi
else
    echo "Skipping qsv validate (no csv-schema.json found)."
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "CSV linting failed with $errors error(s)"
    exit 1
fi
