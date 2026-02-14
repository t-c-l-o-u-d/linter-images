#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
=============== Fixer: rust ===============
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

if [[ ! -f Cargo.toml ]]; then
    echo "No Cargo.toml found, skipping."
    exit 0
fi

echo "Running cargo clippy --fix..."
cargo clippy \
    --fix \
    --allow-dirty \
    --allow-staged \
    --all-features \
    --quiet

echo "Running cargo fmt..."
cargo fmt

echo "Done. Run lint to verify."
