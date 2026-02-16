#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t containerfiles < <(git ls-files \
    'Containerfile' 'Containerfile.*' 'Dockerfile' 'Dockerfile.*' \
    '**/Containerfile' '**/Containerfile.*' '**/Dockerfile' '**/Dockerfile.*')

if [[ ${#containerfiles[@]} -eq 0 ]]; then
    echo "No Containerfiles found, skipping."
    exit 0
fi

errors=0

echo "Running hadolint..."
hadolint_args=()
if [[ -f .linter/.hadolint.yaml ]]; then
    hadolint_args+=(--config .linter/.hadolint.yaml)
elif [[ -f .hadolint.yaml ]]; then
    hadolint_args+=(--config .hadolint.yaml)
fi
if ! hadolint "${hadolint_args[@]}" "${containerfiles[@]}"; then
    echo "FAIL: hadolint"
    errors=$((errors + 1))
else
    echo "PASS: hadolint"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Containerfile linting failed with $errors error(s)"
    exit 1
fi
