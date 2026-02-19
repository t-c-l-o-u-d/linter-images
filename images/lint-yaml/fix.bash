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

# exclude ansible vault files — yamlfmt corrupts their structure
vault_filtered=()
vault_skipped=0
for f in "${yaml_files[@]}"; do
    if head --lines=1 "$f" \
        | grep --quiet "^[\$]ANSIBLE_VAULT;"; then
        vault_skipped=$((vault_skipped + 1))
    else
        vault_filtered+=("$f")
    fi
done
if [[ $vault_skipped -gt 0 ]]; then
    echo "Skipping ${vault_skipped} ansible vault file(s)."
fi
yaml_files=("${vault_filtered[@]}")
if [[ ${#yaml_files[@]} -eq 0 ]]; then
    echo "No non-vault yaml files to format."
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
elif [[ -f .linters/yamlfmt ]]; then
    yamlfmt_args+=(-conf .linters/yamlfmt)
elif [[ -f .yamlfmt ]]; then
    yamlfmt_args+=(-conf .yamlfmt)
fi
for f in "${yaml_files[@]}"; do
    printf "  %s\n" "$f"
    yamlfmt "${yamlfmt_args[@]}" "$f"
done

echo "Done. Run lint to verify."
