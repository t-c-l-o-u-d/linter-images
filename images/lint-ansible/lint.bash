#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

req_file=""
if [[ -f .linter/requirements.yml ]]; then
    req_file=".linter/requirements.yml"
elif [[ -f collections/requirements.yml ]]; then
    req_file="collections/requirements.yml"
elif [[ -f requirements.yml ]]; then
    req_file="requirements.yml"
fi

if [[ -n "$req_file" ]]; then
    echo "Installing Galaxy collections from ${req_file}..."
    ansible-galaxy collection install --requirements-file "$req_file"
fi

errors=0

echo "Running ansible-lint..."
al_args=()
if [[ -f .linter/.ansible-lint ]]; then
    al_args+=(--config-file .linter/.ansible-lint)
elif [[ -f .ansible-lint ]]; then
    al_args+=(--config-file .ansible-lint)
fi
if ! ansible-lint "${al_args[@]}"; then
    echo "FAIL: ansible-lint"
    errors=$((errors + 1))
else
    echo "PASS: ansible-lint"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Ansible linting failed with $errors error(s)"
    exit 1
fi
