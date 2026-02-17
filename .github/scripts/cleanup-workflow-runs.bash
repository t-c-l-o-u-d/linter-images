#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
# Delete old workflow runs, keeping only the most recent KEEP_COUNT per workflow.
# Also deletes ALL runs from stale workflows (renamed or removed workflow files).
# Called by .github/workflows/cleanup-runs-and-caches.yaml

set -euo pipefail

KEEP_COUNT="${KEEP_COUNT:-3}"

# Build a set of active workflow names
declare -A ACTIVE_WORKFLOWS
while IFS=$'\t' read -r WORKFLOW_ID WORKFLOW_NAME; do
  ACTIVE_WORKFLOWS["${WORKFLOW_NAME}"]=1

  echo "::group::${WORKFLOW_NAME} (ID ${WORKFLOW_ID})"

  # Get all run IDs for this workflow, sorted newest first (default)
  RUN_IDS=$(gh run list --workflow "$WORKFLOW_ID" --limit 500 --json databaseId --jq '.[].databaseId')

  COUNT=0
  while IFS= read -r RUN_ID; do
    COUNT=$((COUNT + 1))
    if [[ ${COUNT} -le ${KEEP_COUNT} ]]; then
      echo "Keeping run ${RUN_ID} (${COUNT}/${KEEP_COUNT})"
      continue
    fi
    echo "Deleting run ${RUN_ID}"
    gh run delete "$RUN_ID" || true
  done <<< "$RUN_IDS"

  echo "::endgroup::"
done <<< "$(gh workflow list --all --json id,name --jq '.[] | [(.id | tostring), .name] | join("\t")')"

# Delete all runs from stale workflows (renamed or removed files)
echo "::group::Stale workflow cleanup"
STALE_RUNS=$(gh run list --limit 500 --json databaseId,workflowName \
  --jq '.[] | [(.databaseId | tostring), .workflowName] | join("\t")')

if [[ -z "${STALE_RUNS}" ]]; then
  echo "No runs found."
else
  while IFS=$'\t' read -r RUN_ID WORKFLOW_NAME; do
    if [[ -z "${ACTIVE_WORKFLOWS["${WORKFLOW_NAME}"]:-}" ]]; then
      echo "Deleting stale run ${RUN_ID} (${WORKFLOW_NAME})"
      gh run delete "$RUN_ID" || true
    fi
  done <<< "$STALE_RUNS"
fi

echo "::endgroup::"
