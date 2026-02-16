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

echo "Running shellharden --replace..."
for f in "${bash_scripts[@]}"; do
    printf "  %s\n" "$f"
    shellharden --replace "$f"
done

echo "Done. Run lint to verify."
