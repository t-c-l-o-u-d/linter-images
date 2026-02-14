#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
=========== Linter: systemd ===============
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

mapfile -t systemd_units < <(git ls-files '*.service' '*.timer' '*.socket' '*.path' '*.mount' '*.target' '*.slice')

if [[ ${#systemd_units[@]} -eq 0 ]]; then
    echo "No systemd unit files found, skipping."
    exit 0
fi

errors=0

echo "Running systemd-analyze verify..."
if ! systemd-analyze verify "${systemd_units[@]}"; then
    echo "FAIL: systemd-analyze verify"
    errors=$((errors + 1))
else
    echo "PASS: systemd-analyze verify"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Systemd linting failed with $errors error(s)"
    exit 1
fi
