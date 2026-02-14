#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Delete all GitHub Actions caches for the repository.
# Called by .github/workflows/cleanup-workflow-runs.yaml

set -euo pipefail

CACHE_IDS=$(gh cache list --limit 100 --json id --jq '.[].id')

if [[ -z "$CACHE_IDS" ]]; then
  echo "No caches to delete."
  exit 0
fi

for CACHE_ID in "$CACHE_IDS"; do
  echo "Deleting cache ${CACHE_ID}"
  gh cache delete "$CACHE_ID" || true
done
