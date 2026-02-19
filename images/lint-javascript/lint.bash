#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t js_files < <(git ls-files '*.js' '*.mjs' '*.cjs')

if [[ ${#js_files[@]} -eq 0 ]]; then
    echo "No JavaScript files found, skipping."
    exit 0
fi

errors=0

echo "Running eslint..."
es_args=()
if [[ -f .linter/eslint.config.js ]]; then
    es_args+=(--config .linter/eslint.config.js)
elif [[ -f .linters/eslint.config.js ]]; then
    es_args+=(--config .linters/eslint.config.js)
elif [[ -f eslint.config.js ]]; then
    es_args+=(--config eslint.config.js)
fi
tool_errors=0
for f in "${js_files[@]}"; do
    if ! eslint "${es_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: eslint (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: eslint\n"
fi

echo ""
echo "Running biome check..."
biome_args=()
if [[ -f .linter/biome.json ]]; then
    biome_args+=(--config-path .linter)
elif [[ -f .linters/biome.json ]]; then
    biome_args+=(--config-path .linters)
elif [[ -f biome.json ]]; then
    biome_args+=(--config-path .)
fi
tool_errors=0
for f in "${js_files[@]}"; do
    if ! biome check "${biome_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: biome check (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: biome check\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "JavaScript linting failed with $errors error(s)"
    exit 1
fi
