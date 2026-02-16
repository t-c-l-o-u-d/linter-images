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

echo "Running ruff check --fix..."
ruff_args=()
if [[ -f .linter/ruff.toml ]]; then
    ruff_args+=(--config .linter/ruff.toml)
elif [[ -f ruff.toml ]]; then
    ruff_args+=(--config ruff.toml)
fi
for f in "${py_files[@]}"; do
    printf "  %s\n" "$f"
    ruff check --fix "${ruff_args[@]}" "$f"
done

echo "Running ruff format..."
for f in "${py_files[@]}"; do
    printf "  %s\n" "$f"
    ruff format "${ruff_args[@]}" "$f"
done

echo "Done. Run lint to verify."
