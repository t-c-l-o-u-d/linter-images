#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============== Linter: rust ===============
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

errors=0

echo "Checking dependency tree for duplicates..."
cargo tree --duplicates --quiet
echo ""

echo "Running cargo fmt --check..."
if ! cargo fmt --check; then
    echo "FAIL: cargo fmt"
    errors=$((errors + 1))
else
    echo "PASS: cargo fmt"
fi

echo ""
echo "Running cargo clippy..."
clippy_args=(
    --all-features
    --quiet
    --
    -D warnings
    -D clippy::all
    -D clippy::correctness
    -D clippy::suspicious
    -D clippy::complexity
    -D clippy::perf
    -D clippy::style
    -D clippy::pedantic
    -D clippy::cargo
    -A clippy::doc-markdown
)
if ! cargo clippy "${clippy_args[@]}"; then
    echo "FAIL: cargo clippy"
    errors=$((errors + 1))
else
    echo "PASS: cargo clippy"
fi

echo ""
echo "Running cargo audit..."
if ! cargo audit \
    --deny warnings \
    --deny unmaintained \
    --deny unsound \
    --deny yanked \
    --quiet; then
    echo "FAIL: cargo audit"
    errors=$((errors + 1))
else
    echo "PASS: cargo audit"
fi

echo ""
echo "Running cargo deny..."
deny_args=()
if [[ -f .linter/deny.toml ]]; then
    deny_args+=(--config .linter/deny.toml)
fi
if ! cargo deny "${deny_args[@]}" check advisories bans sources; then
    echo "FAIL: cargo deny"
    errors=$((errors + 1))
else
    echo "PASS: cargo deny"
fi

echo ""
echo "Running cargo test..."
if ! cargo test --release --quiet; then
    echo "FAIL: cargo test"
    errors=$((errors + 1))
else
    echo "PASS: cargo test"
fi

echo ""
echo "Running cargo check (debug)..."
if ! cargo check --all-features --quiet; then
    echo "FAIL: cargo check (debug)"
    errors=$((errors + 1))
else
    echo "PASS: cargo check (debug)"
fi

echo ""
echo "Running cargo check (release)..."
if ! cargo check --all-features --release --quiet; then
    echo "FAIL: cargo check (release)"
    errors=$((errors + 1))
else
    echo "PASS: cargo check (release)"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Rust linting failed with $errors error(s)"
    exit 1
fi
