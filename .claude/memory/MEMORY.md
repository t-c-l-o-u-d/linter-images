# Project memories (linter-images)

## Decisions

- [JSONC handling decision](jsonc_handling_decision.md) — four options
  considered for jq vs JSONC; open question on which to ship

## Rules

- [Verify CVE removal with a real build](feedback_verify_cve_removal.md)
  — never trust the CVE review workflow alone; trigger
  `gh workflow run Main` and confirm against actual scans
