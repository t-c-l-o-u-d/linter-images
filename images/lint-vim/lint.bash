#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t vim_files < <(git ls-files '*.vim' 'vimrc' '*/vimrc')

if [[ ${#vim_files[@]} -eq 0 ]]; then
    echo "No vim files found, skipping."
    exit 0
fi

errors=0

# vint auto-discovers .vintrc.yaml from cwd; copy to tmpdir to avoid
# writing to the (read-only) workspace mount
vint_dir="/workspace"
if [[ -f .linter/.vintrc.yaml ]] && [[ ! -f .vintrc.yaml ]]; then
    vint_dir="$(mktemp --directory)"
    cp .linter/.vintrc.yaml "${vint_dir}/.vintrc.yaml"
fi

echo "Running vint..."
tool_errors=0
for f in "${vim_files[@]}"; do
    abs_f="/workspace/${f}"
    if ! (cd "$vint_dir" && vint "$abs_f"); then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: vint (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: vint\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Vim linting failed with $errors error(s)"
    exit 1
fi
