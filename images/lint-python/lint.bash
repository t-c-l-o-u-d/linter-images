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
tool_errors=0
for f in "${py_files[@]}"; do
    if ! ruff check "${ruff_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: ruff check (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: ruff check\n"
fi

echo ""
echo "Running ruff format --check..."
tool_errors=0
for f in "${py_files[@]}"; do
    if ! ruff format --check "${ruff_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: ruff format (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: ruff format\n"
fi

echo ""
echo "Running mypy..."
mypy_args=(--strict)
if [[ -f .linter/mypy.ini ]]; then
    mypy_args+=(--config-file .linter/mypy.ini)
elif [[ -f mypy.ini ]]; then
    mypy_args+=(--config-file mypy.ini)
fi
printf "  Files:\n"
for f in "${py_files[@]}"; do
    printf "    %s\n" "$f"
done
if ! mypy "${mypy_args[@]}" "${py_files[@]}"; then
    printf "FAIL: mypy\n"
    errors=$((errors + 1))
else
    printf "PASS: mypy\n"
fi

echo ""
echo "Running bandit..."
bandit_args=(--quiet)
if [[ -f .linter/.bandit ]]; then
    bandit_args+=(--configfile .linter/.bandit)
elif [[ -f .bandit ]]; then
    bandit_args+=(--configfile .bandit)
fi
tool_errors=0
for f in "${py_files[@]}"; do
    if ! bandit "${bandit_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: bandit (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: bandit\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Python linting failed with $errors error(s)"
    exit 1
fi
