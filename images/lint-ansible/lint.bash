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
    ansible-galaxy collection install \
        --collections-path /tmp/.ansible/collections \
        --requirements-file "$req_file"
fi

mapfile -t ansible_files < <(git ls-files '*.yml' '*.yaml')

if [[ ${#ansible_files[@]} -eq 0 ]]; then
    echo "No ansible files found, skipping."
    exit 0
fi

errors=0

echo "Running ansible-lint..."
al_args=()
if [[ -f .linter/.ansible-lint ]]; then
    al_args+=(--config-file .linter/.ansible-lint)
elif [[ -f .ansible-lint ]]; then
    al_args+=(--config-file .ansible-lint)
fi

# run once in auto-detection mode, capture json violations from stdout
al_output=$(ansible-lint "${al_args[@]}" --format json --show-relpath 2>/dev/null) || true
al_output="${al_output:-[]}"

# report per-file results
tool_errors=0
for f in "${ansible_files[@]}"; do
    file_violations=$(jq --raw-output --arg f "$f" \
        '.[] | select(.location.path == $f) | "\(.location.path):\(.location.lines.begin): \(.check_name): \(.description)"' \
        <<< "$al_output")
    if [[ -n "$file_violations" ]]; then
        printf "%s\n" "$file_violations"
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: ansible-lint (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: ansible-lint\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Ansible linting failed with $errors error(s)"
    exit 1
fi
