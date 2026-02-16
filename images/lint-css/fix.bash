#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t css_files < <(git ls-files '*.css' '*.scss')

if [[ ${#css_files[@]} -eq 0 ]]; then
    echo "No CSS/SCSS files found, skipping."
    exit 0
fi

echo "Running stylelint --fix..."
sl_args=(--fix)
if [[ -f .linter/.stylelintrc.json ]]; then
    sl_args+=(--config .linter/.stylelintrc.json)
elif [[ -f .stylelintrc.json ]]; then
    sl_args+=(--config .stylelintrc.json)
else
    echo "SKIP: stylelint (no config found)"
fi
if [[ ${#sl_args[@]} -gt 1 ]]; then
    stylelint "${sl_args[@]}" "${css_files[@]}"
fi

echo "Running biome format --write..."
mapfile -t css_only < <(printf '%s\n' "${css_files[@]}" | grep --extended-regexp '\.css$')
if [[ ${#css_only[@]} -eq 0 ]]; then
    echo "SKIP: biome format (no .css files)"
else
    biome_args=(--write)
    if [[ -f .linter/biome.json ]]; then
        biome_args+=(--config-path .linter)
    elif [[ -f biome.json ]]; then
        biome_args+=(--config-path .)
    fi
    biome format "${biome_args[@]}" "${css_only[@]}"
fi

echo "Done. Run lint to verify."
