#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Install grype via its install script and scan a container image.
# No third-party GitHub Actions involved -- runs grype directly.
#
# Usage:
#   .github/scripts/grype.bash <image-ref> [--format table|json] [--exit-code 0|1] [--config path]
#
# Environment:
#   GRYPE_SEVERITY   - minimum severity cutoff (default: medium)

set -euo pipefail

IMAGE_REF="${1:?Usage: grype.bash <image-ref> [--format table|json] [--exit-code 0|1] [--config path]}"
shift

FORMAT="table"
EXIT_CODE="1"
CONFIG=""
SEVERITY="${GRYPE_SEVERITY:-medium}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="${2:?--format requires a value}"
            shift 2
            ;;
        --exit-code)
            EXIT_CODE="${2:?--exit-code requires a value}"
            shift 2
            ;;
        --config)
            CONFIG="${2:?--config requires a value}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Install grype if not already present
if ! command -v grype &>/dev/null; then
    echo "Installing grype..."
    curl --silent --show-error --fail \
        https://raw.githubusercontent.com/anchore/grype/main/install.sh \
        | sudo sh -s -- -b /usr/local/bin
fi

echo "grype version: $(grype version | grep '^Application' | awk '{print $2}')"

# Build the grype command
GRYPE_CMD=(
    grype
    "$IMAGE_REF"
    --output "$FORMAT"
    --fail-on "$SEVERITY"
    --only-fixed
    --by-cve
)

if [[ -n "$CONFIG" ]]; then
    GRYPE_CMD+=(--config "$CONFIG")
fi

echo "Running: ${GRYPE_CMD[*]}"

if "${GRYPE_CMD[@]}"; then
    exit 0
else
    rc=$?
    if [[ "$EXIT_CODE" == "0" ]]; then
        exit 0
    fi
    exit "$rc"
fi
