#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t bash_scripts < <(
    git ls-files -z \
    | xargs --null grep --files-with-matches '^#!.*bash' \
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
sc_args=(--external-sources)
if [[ -f .linter/.shellcheckrc ]]; then
    sc_args+=(--rcfile .linter/.shellcheckrc)
elif [[ -f .shellcheckrc ]]; then
    sc_args+=(--rcfile .shellcheckrc)
fi
if ! shellcheck "${sc_args[@]}" "${bash_scripts[@]}"; then
    echo "FAIL: shellcheck"
    errors=$((errors + 1))
else
    echo "PASS: shellcheck"
fi

echo ""
echo "Running shellharden..."
if ! shellharden --check "${bash_scripts[@]}"; then
    for f in "${bash_scripts[@]}"; do
        diff --unified "$f" <(shellharden "$f") || true
    done
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
