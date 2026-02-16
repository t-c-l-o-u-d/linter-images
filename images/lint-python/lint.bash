#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t py_files < <(git ls-files '*.py')

if [[ ${#py_files[@]} -eq 0 ]]; then
    echo "No Python files found, skipping."
    exit 0
fi

errors=0

echo "Running ruff check..."
ruff_args=()
if [[ -f .linter/ruff.toml ]]; then
    ruff_args+=(--config .linter/ruff.toml)
elif [[ -f ruff.toml ]]; then
    ruff_args+=(--config ruff.toml)
fi
if ! ruff check "${ruff_args[@]}" "${py_files[@]}"; then
    echo "FAIL: ruff check"
    errors=$((errors + 1))
else
    echo "PASS: ruff check"
fi

echo ""
echo "Running ruff format --check..."
if ! ruff format --check "${ruff_args[@]}" "${py_files[@]}"; then
    echo "FAIL: ruff format"
    errors=$((errors + 1))
else
    echo "PASS: ruff format"
fi

echo ""
echo "Running mypy..."
mypy_args=(--strict)
if [[ -f .linter/mypy.ini ]]; then
    mypy_args+=(--config-file .linter/mypy.ini)
elif [[ -f mypy.ini ]]; then
    mypy_args+=(--config-file mypy.ini)
fi
if ! mypy "${mypy_args[@]}" "${py_files[@]}"; then
    echo "FAIL: mypy"
    errors=$((errors + 1))
else
    echo "PASS: mypy"
fi

echo ""
echo "Running bandit..."
bandit_args=(--recursive --quiet)
if [[ -f .linter/.bandit ]]; then
    bandit_args+=(--configfile .linter/.bandit)
elif [[ -f .bandit ]]; then
    bandit_args+=(--configfile .bandit)
fi
if ! bandit "${bandit_args[@]}" "${py_files[@]}"; then
    echo "FAIL: bandit"
    errors=$((errors + 1))
else
    echo "PASS: bandit"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Python linting failed with $errors error(s)"
    exit 1
fi
