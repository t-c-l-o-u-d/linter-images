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
elif [[ -f eslint.config.js ]]; then
    es_args+=(--config eslint.config.js)
fi
if ! eslint "${es_args[@]}" "${js_files[@]}"; then
    echo "FAIL: eslint"
    errors=$((errors + 1))
else
    echo "PASS: eslint"
fi

echo ""
echo "Running biome check..."
biome_args=()
if [[ -f .linter/biome.json ]]; then
    biome_args+=(--config-path .linter)
elif [[ -f biome.json ]]; then
    biome_args+=(--config-path .)
fi
if ! biome check "${biome_args[@]}" "${js_files[@]}"; then
    echo "FAIL: biome check"
    errors=$((errors + 1))
else
    echo "PASS: biome check"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "JavaScript linting failed with $errors error(s)"
    exit 1
fi
