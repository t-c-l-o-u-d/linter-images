#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t json_files < <(git ls-files '*.json')

if [[ ${#json_files[@]} -eq 0 ]]; then
    echo "No JSON files found, skipping."
    exit 0
fi

echo "Running jq format..."
for f in "${json_files[@]}"; do
    printf "  %s\n" "$f"
    tmp="${f}.tmp"
    jq . "$f" > "$tmp"
    mv "$tmp" "$f"
done

echo "Done. Run lint to verify."
