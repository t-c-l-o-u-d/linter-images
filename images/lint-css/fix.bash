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
elif [[ -f .linters/stylelintrc.json ]]; then
    sl_args+=(--config .linters/stylelintrc.json)
elif [[ -f .stylelintrc.json ]]; then
    sl_args+=(--config .stylelintrc.json)
else
    sl_default_config=$(mktemp --suffix=.json)
    echo '{"extends":"stylelint-config-standard"}' > "$sl_default_config"
    sl_args+=(--config-basedir /usr/lib/node_modules)
    sl_args+=(--config "$sl_default_config")
fi
for f in "${css_files[@]}"; do
    printf "  %s\n" "$f"
    stylelint "${sl_args[@]}" "$f"
done

echo "Running biome format --write..."
mapfile -t css_only < <(printf '%s\n' "${css_files[@]}" | grep --extended-regexp '\.css$')
if [[ ${#css_only[@]} -eq 0 ]]; then
    echo "SKIP: biome format (no .css files)"
else
    biome_args=(--write)
    if [[ -f .linter/biome.json ]]; then
        biome_args+=(--config-path .linter)
    elif [[ -f .linters/biome.json ]]; then
        biome_args+=(--config-path .linters)
    elif [[ -f biome.json ]]; then
        biome_args+=(--config-path .)
    fi
    for f in "${css_only[@]}"; do
        printf "  %s\n" "$f"
        biome format "${biome_args[@]}" "$f"
    done
fi

echo "Done. Run lint to verify."
