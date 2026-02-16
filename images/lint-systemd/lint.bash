#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t systemd_units < <(git ls-files '*.service' '*.timer' '*.socket' '*.path' '*.mount' '*.target' '*.slice')

if [[ ${#systemd_units[@]} -eq 0 ]]; then
    echo "No systemd unit files found, skipping."
    exit 0
fi

errors=0

echo "Running systemd-analyze verify..."
tool_errors=0
for f in "${systemd_units[@]}"; do
    if ! systemd-analyze verify "$f"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: systemd-analyze verify (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: systemd-analyze verify\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Systemd linting failed with $errors error(s)"
    exit 1
fi
