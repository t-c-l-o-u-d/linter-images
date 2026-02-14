#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============== Linter: bash ===============
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

mapfile -t bash_scripts < <(
    grep --recursive --files-with-matches --exclude-dir=.git '^#!.*bash' . \
    | while IFS= read -r f; do
        if [[ "$(file --brief --mime-type "$f")" == "text/x-shellscript" ]]; then
            printf '%s\n' "$f"
        fi
    done
)

if [[ ${#bash_scripts[@]} -eq 0 ]]; then
    echo "No bash scripts found, skipping."
    exit 0
fi

errors=0

echo "Running bash -n (syntax check)..."
if ! bash -n "${bash_scripts[@]}"; then
    echo "FAIL: bash syntax check"
    errors=$((errors + 1))
else
    echo "PASS: bash syntax check"
fi

echo ""
echo "Running shellcheck..."
if ! shellcheck --external-sources "${bash_scripts[@]}"; then
    echo "FAIL: shellcheck"
    errors=$((errors + 1))
else
    echo "PASS: shellcheck"
fi

echo ""
echo "Running shellharden..."
if ! shellharden --check "${bash_scripts[@]}"; then
    echo "FAIL: shellharden"
    errors=$((errors + 1))
else
    echo "PASS: shellharden"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Bash linting failed with $errors error(s)"
    exit 1
fi
