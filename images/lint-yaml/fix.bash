#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t yaml_files < <(git ls-files '*.yml' '*.yaml')

if [[ ${#yaml_files[@]} -eq 0 ]]; then
    echo "No yaml files found, skipping."
    exit 0
fi

# in ansible projects, exclude files that contain ansible keywords —
# those belong to lint-ansible and yamlfmt can break their structure
if [[ -d roles ]] || [[ -f ansible.cfg ]]; then
    ansible_re='^[[:space:]]*-?[[:space:]]*(become|gather_facts|tasks|handlers)[[:space:]]*:'
    filtered=()
    skipped=0
    for f in "${yaml_files[@]}"; do
        if head --lines=50 "$f" \
            | grep --quiet --extended-regexp "$ansible_re"; then
            skipped=$((skipped + 1))
        else
            filtered+=("$f")
        fi
    done
    if [[ $skipped -gt 0 ]]; then
        echo "Skipping ${skipped} ansible file(s) (handled by lint-ansible)."
    fi
    yaml_files=("${filtered[@]}")
    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        echo "No non-ansible yaml files to format."
        exit 0
    fi
fi

echo "Running yamlfmt..."
yamlfmt_args=()
if [[ -f .linter/.yamlfmt ]]; then
    yamlfmt_args+=(-conf .linter/.yamlfmt)
elif [[ -f .yamlfmt ]]; then
    yamlfmt_args+=(-conf .yamlfmt)
fi
for f in "${yaml_files[@]}"; do
    printf "  %s\n" "$f"
    yamlfmt "${yamlfmt_args[@]}" "$f"
done

echo "Done. Run lint to verify."
