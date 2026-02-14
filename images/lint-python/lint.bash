#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============= Linter: python ==============
===========================================
============ Brought to you by ============
       _       _                 _
      | |_ ___| | ___  _   _  __| |
      | __/ __| |/ _ \| | | |/ _` |
      | || (__| | (_) | |_| | (_| |
       \__\___|_|\___/ \__,_|\__,_|
===========================================
===== https://github.com/t-c-l-o-u-d =====
===========================================
EOF
echo ""

mapfile -t py_files < <(git ls-files '*.py')

if [[ ${#py_files[@]} -eq 0 ]]; then
    echo "No Python files found, skipping."
    exit 0
fi

errors=0

echo "Running ruff check..."
if ! ruff check "${py_files[@]}"; then
    echo "FAIL: ruff check"
    errors=$((errors + 1))
else
    echo "PASS: ruff check"
fi

echo ""
echo "Running ruff format --check..."
if ! ruff format --check "${py_files[@]}"; then
    echo "FAIL: ruff format"
    errors=$((errors + 1))
else
    echo "PASS: ruff format"
fi

echo ""
echo "Running mypy..."
if ! mypy --strict "${py_files[@]}"; then
    echo "FAIL: mypy"
    errors=$((errors + 1))
else
    echo "PASS: mypy"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Python linting failed with $errors error(s)"
    exit 1
fi
