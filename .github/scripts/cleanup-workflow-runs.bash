#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Delete old workflow runs, keeping only the most recent KEEP_COUNT per workflow.
# Called by .github/workflows/cleanup-workflow-runs.yaml

set -euo pipefail

KEEP_COUNT="${KEEP_COUNT:-3}"

# List all workflow files in the repository
WORKFLOWS=$(gh workflow list --json id,name --jq '.[].id')

for WORKFLOW_ID in ${WORKFLOWS}; do
  WORKFLOW_NAME=$(gh workflow view "${WORKFLOW_ID}" --json name --jq '.name')
  echo "::group::${WORKFLOW_NAME} (ID ${WORKFLOW_ID})"

  # Get all run IDs for this workflow, sorted newest first (default)
  RUN_IDS=$(gh run list --workflow "${WORKFLOW_ID}" --limit 500 --json databaseId --jq '.[].databaseId')

  COUNT=0
  for RUN_ID in ${RUN_IDS}; do
    COUNT=$((COUNT + 1))
    if [[ ${COUNT} -le ${KEEP_COUNT} ]]; then
      echo "Keeping run ${RUN_ID} (${COUNT}/${KEEP_COUNT})"
      continue
    fi
    echo "Deleting run ${RUN_ID}"
    gh run delete "${RUN_ID}" || true
  done

  echo "::endgroup::"
done
