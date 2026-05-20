---
name: Verify CVE removal with a real build
description: Never remove CVEs from ignore lists based solely on the automated CVE review report — always trigger a full build to verify first
type: feedback
---

# Verify CVE removal with a real build

Never trust the CVE review workflow report alone when removing CVEs
from ignore lists. Always trigger a full build and check scan results
before removing.

**Why:** The CVE review workflow gave false negatives (reported
captree Go stdlib CVEs as absent), but a real build found them all
still present. Removing based on the report alone broke CI.

**How to apply:** When working on CVE cleanup issues, trigger
`gh workflow run Main` first, wait for scan results, then only remove
CVEs confirmed absent from actual build scans.
