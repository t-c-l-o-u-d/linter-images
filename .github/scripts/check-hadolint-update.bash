#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Check for new hadolint releases and open a GitHub issue if one is available.
# Called by .github/workflows/check-hadolint-update.yaml

set -euo pipefail

CONTAINERFILE="images/lint-containerfile/Containerfile"

# extract the pinned version from the Containerfile
CURRENT_VERSION=$(grep --only-matching 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$CONTAINERFILE" | head --lines 1)
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "ERROR: could not extract hadolint version from ${CONTAINERFILE}"
    exit 1
fi
echo "Current pinned version: ${CURRENT_VERSION}"

# fetch the latest release tag from GitHub
LATEST_VERSION=$(gh api repos/hadolint/hadolint/releases/latest --jq '.tag_name')
if [[ -z "$LATEST_VERSION" ]]; then
    echo "ERROR: could not fetch latest hadolint release"
    exit 1
fi
echo "Latest release version: ${LATEST_VERSION}"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    echo "hadolint is up to date."
    exit 0
fi

echo "New hadolint version available: ${LATEST_VERSION} (currently ${CURRENT_VERSION})"

# check if an issue already exists for this version
EXISTING=$(gh issue list --search "Update hadolint to ${LATEST_VERSION}" --state open --json number --jq 'length')
if [[ "$EXISTING" -gt 0 ]]; then
    echo "Issue already exists for ${LATEST_VERSION}, skipping."
    exit 0
fi

# open a new issue
gh issue create \
    --title "Update hadolint to ${LATEST_VERSION}" \
    --body "$(cat <<EOF
A new hadolint release is available.

- **Current version:** ${CURRENT_VERSION}
- **Latest version:** ${LATEST_VERSION}
- **Release:** https://github.com/hadolint/hadolint/releases/tag/${LATEST_VERSION}

Update the version and sha256 hash in \`${CONTAINERFILE}\`.
EOF
)"

echo "Issue created."
