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

mapfile -t rs_files < <(git ls-files '*.rs')

errors=0

echo "Checking dependency tree for duplicates..."
cargo tree --duplicates --quiet
echo ""

echo "Running cargo fmt --check..."
fmt_output=$(cargo fmt -- --check --files-with-diffs 2>/dev/null) || true
fmt_output="${fmt_output:-}"

tool_errors=0
for f in "${rs_files[@]}"; do
    if grep --quiet --fixed-strings "$f" <<< "$fmt_output"; then
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: cargo fmt (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: cargo fmt\n"
fi

echo ""
echo "Running cargo clippy..."
clippy_args=(
    --all-features
    --quiet
    --message-format=json
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
clippy_output=$(cargo clippy "${clippy_args[@]}" 2>/dev/null) || true
clippy_output="${clippy_output:-}"

tool_errors=0
for f in "${rs_files[@]}"; do
    file_violations=$(jq --raw-output --arg f "$f" \
        'select(.reason == "compiler-message")
         | select(.message.spans[]?.file_name == $f)
         | .message.rendered' \
        <<< "$clippy_output")
    if [[ -n "$file_violations" ]]; then
        printf "%s\n" "$file_violations"
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: cargo clippy (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: cargo clippy\n"
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
check_debug_output=$(cargo check \
    --all-features \
    --quiet \
    --message-format=json 2>/dev/null) || true
check_debug_output="${check_debug_output:-}"

tool_errors=0
for f in "${rs_files[@]}"; do
    file_violations=$(jq --raw-output --arg f "$f" \
        'select(.reason == "compiler-message")
         | select(.message.spans[]?.file_name == $f)
         | .message.rendered' \
        <<< "$check_debug_output")
    if [[ -n "$file_violations" ]]; then
        printf "%s\n" "$file_violations"
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: cargo check (debug) (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: cargo check (debug)\n"
fi

echo ""
echo "Running cargo check (release)..."
check_release_output=$(cargo check \
    --all-features \
    --release \
    --quiet \
    --message-format=json 2>/dev/null) || true
check_release_output="${check_release_output:-}"

tool_errors=0
for f in "${rs_files[@]}"; do
    file_violations=$(jq --raw-output --arg f "$f" \
        'select(.reason == "compiler-message")
         | select(.message.spans[]?.file_name == $f)
         | .message.rendered' \
        <<< "$check_release_output")
    if [[ -n "$file_violations" ]]; then
        printf "%s\n" "$file_violations"
        printf "  FAIL: %s\n" "$f"
        tool_errors=$((tool_errors + 1))
    else
        printf "  PASS: %s\n" "$f"
    fi
done
if ((tool_errors > 0)); then
    printf "FAIL: cargo check (release) (%d file(s))\n" "$tool_errors"
    errors=$((errors + 1))
else
    printf "PASS: cargo check (release)\n"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Rust linting failed with $errors error(s)"
    exit 1
fi
