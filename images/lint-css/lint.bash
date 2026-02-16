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

errors=0

echo "Running stylelint..."
sl_args=()
if [[ -f .linter/.stylelintrc.json ]]; then
    sl_args+=(--config .linter/.stylelintrc.json)
elif [[ -f .stylelintrc.json ]]; then
    sl_args+=(--config .stylelintrc.json)
else
    echo "SKIP: stylelint (no config found)"
fi
if [[ ${#sl_args[@]} -gt 0 ]]; then
    if ! stylelint "${sl_args[@]}" "${css_files[@]}"; then
        echo "FAIL: stylelint"
        errors=$((errors + 1))
    else
        echo "PASS: stylelint"
    fi
fi

echo ""
echo "Running biome check..."
mapfile -t css_only < <(printf '%s\n' "${css_files[@]}" | grep --extended-regexp '\.css$')
if [[ ${#css_only[@]} -eq 0 ]]; then
    echo "SKIP: biome check (no .css files)"
else
    biome_args=()
    if [[ -f .linter/biome.json ]]; then
        biome_args+=(--config-path .linter)
    elif [[ -f biome.json ]]; then
        biome_args+=(--config-path .)
    fi
    if ! biome check "${biome_args[@]}" "${css_only[@]}"; then
        echo "FAIL: biome check"
        errors=$((errors + 1))
    else
        echo "PASS: biome check"
    fi
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "CSS linting failed with $errors error(s)"
    exit 1
fi
