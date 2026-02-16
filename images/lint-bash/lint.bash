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
tool_errors=0
for f in "${bash_scripts[@]}"; do
    if ! bash -n "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: bash syntax check (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: bash syntax check\n"
fi

echo ""
echo "Running shellcheck..."
sc_args=(--external-sources)
if [[ -f .linter/.shellcheckrc ]]; then
    sc_args+=(--rcfile .linter/.shellcheckrc)
elif [[ -f .shellcheckrc ]]; then
    sc_args+=(--rcfile .shellcheckrc)
fi
tool_errors=0
for f in "${bash_scripts[@]}"; do
    if ! shellcheck "${sc_args[@]}" "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: shellcheck (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: shellcheck\n"
fi

echo ""
echo "Running shellharden..."
tool_errors=0
for f in "${bash_scripts[@]}"; do
    if ! shellharden --check "$f"; then
        diff --unified "$f" <(shellharden --transform "$f") || true
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: shellharden (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: shellharden\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Bash linting failed with $errors error(s)"
    exit 1
fi
