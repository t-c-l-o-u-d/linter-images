#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

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
