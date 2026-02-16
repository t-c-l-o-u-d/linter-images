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
