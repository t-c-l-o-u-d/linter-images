#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t ruby_files < <(git ls-files '*.rb' '*.gemspec' '*.rake' 'Gemfile' 'Rakefile')

if [[ ${#ruby_files[@]} -eq 0 ]]; then
    echo "No Ruby files found, skipping."
    exit 0
fi

errors=0

echo "Running rubocop..."
rubocop_args=(
    --require rubocop-performance
    --require rubocop-rake
    --require rubocop-rspec
    --format json
)
if [[ -f .linter/.rubocop.yml ]]; then
    rubocop_args+=(--config .linter/.rubocop.yml)
elif [[ -f .rubocop.yml ]]; then
    rubocop_args+=(--config .rubocop.yml)
fi

rubocop_output=$(rubocop "${rubocop_args[@]}" \
    "${ruby_files[@]}" 2>/dev/null) || true

tool_errors=0
for f in "${ruby_files[@]}"; do
    file_offenses=$(echo "$rubocop_output" \
        | jq --raw-output --arg f "$f" \
            '.files[] | select(.path == $f) | .offenses | length')
    if [[ "$file_offenses" -gt 0 ]]; then
        echo "$rubocop_output" \
            | jq --raw-output --arg f "$f" \
                '.files[] | select(.path == $f) | .offenses[] | "\($f):\(.location.line):\(.location.column): \(.severity): \(.message) [\(.cop_name)]"'
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: rubocop (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: rubocop\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Ruby linting failed with $errors error(s)"
    exit 1
fi
