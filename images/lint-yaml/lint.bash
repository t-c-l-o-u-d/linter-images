#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t yaml_files < <(git ls-files '*.yml' '*.yaml')

if [[ ${#yaml_files[@]} -eq 0 ]]; then
    echo "No yaml files found, skipping."
    exit 0
fi

errors=0

echo "Running yamllint..."
yamllint_args=()
if [[ -f .linter/.yamllint.yaml ]]; then
    yamllint_args+=(--config-file .linter/.yamllint.yaml)
elif [[ -f .yamllint.yaml ]]; then
    yamllint_args+=(--config-file .yamllint.yaml)
fi
tool_errors=0
for f in "${yaml_files[@]}"; do
    if ! yamllint "${yamllint_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: yamllint (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: yamllint\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "YAML linting failed with $errors error(s)"
    exit 1
fi
