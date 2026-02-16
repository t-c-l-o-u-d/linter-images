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
if ! yamllint "${yamllint_args[@]}" "${yaml_files[@]}"; then
    echo "FAIL: yamllint"
    errors=$((errors + 1))
else
    echo "PASS: yamllint"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "YAML linting failed with $errors error(s)"
    exit 1
fi
