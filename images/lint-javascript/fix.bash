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

echo "Running eslint --fix..."
es_args=(--fix)
if [[ -f .linter/eslint.config.js ]]; then
    es_args+=(--config .linter/eslint.config.js)
elif [[ -f .linters/eslint.config.js ]]; then
    es_args+=(--config .linters/eslint.config.js)
elif [[ -f eslint.config.js ]]; then
    es_args+=(--config eslint.config.js)
fi
for f in "${js_files[@]}"; do
    printf "  %s\n" "$f"
    eslint "${es_args[@]}" "$f"
done

echo "Running biome format --write..."
biome_args=(--write)
if [[ -f .linter/biome.json ]]; then
    biome_args+=(--config-path .linter)
elif [[ -f .linters/biome.json ]]; then
    biome_args+=(--config-path .linters)
elif [[ -f biome.json ]]; then
    biome_args+=(--config-path .)
fi
for f in "${js_files[@]}"; do
    printf "  %s\n" "$f"
    biome format "${biome_args[@]}" "$f"
done

echo "Done. Run lint to verify."
