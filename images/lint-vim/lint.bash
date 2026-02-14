#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============== Linter: vim ================
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

mapfile -t vim_files < <(git ls-files '*.vim' 'vimrc' '*/vimrc')

if [[ ${#vim_files[@]} -eq 0 ]]; then
    echo "No vim files found, skipping."
    exit 0
fi

errors=0

# vint auto-discovers .vintrc.yaml from cwd; symlink if in .linter/
vint_link=""
if [[ -f .linter/.vintrc.yaml ]] && [[ ! -f .vintrc.yaml ]]; then
    ln --symbolic .linter/.vintrc.yaml .vintrc.yaml
    vint_link=1
fi
cleanup_vint() {
    if [[ -n "$vint_link" ]]; then
        rm --force .vintrc.yaml
    fi
}
trap cleanup_vint EXIT

echo "Running vint..."
if ! vint "${vim_files[@]}"; then
    echo "FAIL: vint"
    errors=$((errors + 1))
else
    echo "PASS: vint"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Vim linting failed with $errors error(s)"
    exit 1
fi
