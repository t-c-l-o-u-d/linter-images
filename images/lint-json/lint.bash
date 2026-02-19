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

echo "Running json syntax check..."
tool_errors=0
for f in "${json_files[@]}"; do
    if ! output=$(python3 -c "
import json, sys
with open(sys.argv[1]) as fh:
    text = fh.read()
try:
    json.loads(text)
except json.JSONDecodeError:
    import json5
    json5.loads(text)
" "$f" 2>&1); then
        printf "  FAIL: %s\n" "$f"
        printf "    %s\n" "$output"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done

if ((tool_errors > 0)); then
    printf "FAIL: json syntax check (%d file(s))\n" "$tool_errors"
    exit 1
else
    printf "PASS: json syntax check\n"
fi
