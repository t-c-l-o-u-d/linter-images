#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Install trivy via package manager and scan a container image.
# No third-party GitHub Actions involved -- runs trivy directly.
#
# Usage:
#   .github/scripts/trivy.bash <image-ref> [--format table|json] [--exit-code 0|1] [--ignorefile path]
#
# Environment:
#   TRIVY_SEVERITY   - comma-separated severities (default: CRITICAL,HIGH,MEDIUM)

set -euo pipefail

IMAGE_REF="${1:?Usage: trivy.bash <image-ref> [--format table|json] [--exit-code 0|1] [--ignorefile path]}"
shift

FORMAT="table"
EXIT_CODE="1"
IGNOREFILE=""
SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH,MEDIUM}"

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
        --ignorefile)
            IGNOREFILE="${2:?--ignorefile requires a value}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Install trivy if not already present
if ! command -v trivy &>/dev/null; then
    echo "Installing trivy..."
    sudo apt-get update --quiet
    sudo apt-get install --yes --quiet --no-install-recommends \
        wget apt-transport-https gnupg
    wget --quiet --output-document - \
        https://aquasecurity.github.io/trivy-repo/deb/public.key \
        | sudo gpg --dearmor --output /usr/share/keyrings/trivy.gpg
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
        | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt-get update --quiet
    sudo apt-get install --yes --quiet trivy
fi

echo "trivy version: $(trivy --version | head --lines 1)"

# Build the trivy command
TRIVY_CMD=(
    trivy image
    --severity "$SEVERITY"
    --ignore-unfixed
    --pkg-types "os,library"
    --format "$FORMAT"
    --exit-code "$EXIT_CODE"
)

if [[ -n "$IGNOREFILE" ]]; then
    TRIVY_CMD+=(--ignorefile "$IGNOREFILE")
fi

TRIVY_CMD+=("$IMAGE_REF")

echo "Running: ${TRIVY_CMD[*]}"
"${TRIVY_CMD[@]}"
