#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
======== Orchestrator: lint-all ==========
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

# source detection and runner functions
# shellcheck source=scan.bash
source /usr/local/bin/scan

validate_runtime

echo "Scanning workspace for file types..."
mapfile -t images < <(detect_images)

if [[ ${#images[@]} -eq 0 ]]; then
    echo "No recognized file types found in workspace."
    echo "Nothing to lint."
    exit 0
fi

echo ""
echo "Detected linter images to run:"
for img in "${images[@]}"; do
    echo "  - ${img}"
done

errors=0
passed=0

for img in "${images[@]}"; do
    if run_container "${img}" "/usr/local/bin/lint"; then
        echo "PASS: ${img}"
        passed=$((passed + 1))
    else
        echo "FAIL: ${img}"
        errors=$((errors + 1))
    fi
done

echo ""
echo "==========================================="
echo "  Lint Summary"
echo "==========================================="
echo "  Passed:  ${passed}"
echo "  Failed:  ${errors}"
echo "  Total:   ${#images[@]}"
echo "==========================================="

if [[ ${errors} -gt 0 ]]; then
    echo ""
    echo "Linting failed with ${errors} error(s)"
    exit 1
fi
