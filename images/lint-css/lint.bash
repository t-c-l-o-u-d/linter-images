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
tool_errors=0
for f in "${css_files[@]}"; do
    if ! stylelint "${sl_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: stylelint (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: stylelint\n"
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
    elif [[ -f .linters/biome.json ]]; then
        biome_args+=(--config-path .linters)
    elif [[ -f biome.json ]]; then
        biome_args+=(--config-path .)
    fi
    tool_errors=0
    for f in "${css_only[@]}"; do
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
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "CSS linting failed with $errors error(s)"
    exit 1
fi
