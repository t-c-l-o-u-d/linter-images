#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
========= Orchestrator: fix-all ==========
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

# images that support fix mode
declare -A FIX_SUPPORTED=(
    [lint-bash]=1
    [lint-css]=1
    [lint-javascript]=1
    [lint-python]=1
)

validate_runtime

echo "Scanning workspace for file types..."
mapfile -t images < <(detect_images)

if [[ ${#images[@]} -eq 0 ]]; then
    echo "No recognized file types found in workspace."
    echo "Nothing to fix."
    exit 0
fi

echo ""
echo "Detected linter images to run:"
for img in "${images[@]}"; do
    if [[ -n "${FIX_SUPPORTED[${img}]+x}" ]]; then
        echo "  - ${img} (fix + lint)"
    else
        echo "  - ${img} (lint only)"
    fi
done

errors=0
fixed=0
linted=0

for img in "${images[@]}"; do
    # run fix first if supported
    if [[ -n "${FIX_SUPPORTED[${img}]+x}" ]]; then
        if run_container "${img}" "/usr/local/bin/fix"; then
            echo "PASS: ${img} fix"
            fixed=$((fixed + 1))
        else
            echo "FAIL: ${img} fix"
            errors=$((errors + 1))
        fi
    fi

    # always lint
    if run_container "${img}" "/usr/local/bin/lint"; then
        echo "PASS: ${img} lint"
        linted=$((linted + 1))
    else
        echo "FAIL: ${img} lint"
        errors=$((errors + 1))
    fi
done

echo ""
echo "==========================================="
echo "  Fix + Lint Summary"
echo "==========================================="
echo "  Fixed:   ${fixed}"
echo "  Linted:  ${linted} / ${#images[@]}"
echo "  Errors:  ${errors}"
echo "==========================================="

if [[ ${errors} -gt 0 ]]; then
    echo ""
    echo "Fix+lint failed with ${errors} error(s)"
    exit 1
fi

echo ""
echo "Done. All fixes applied and lints passed."
