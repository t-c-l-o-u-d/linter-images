# Vulnerability Management

## Overview

All images in this project are built on Arch Linux
using upstream packages from the official
repositories. When vulnerabilities are found in those
packages, fixes depend on upstream maintainers
rebuilding with patched versions. We cannot apply
patches locally at this time.

## Ignore Files

Known vulnerabilities that cannot be resolved locally
are tracked in scanner-specific ignore files:

- `.linter/.trivyignore` &mdash; Trivy ignore list
- `.linter/.grype.yaml` &mdash; Grype ignore list

Each entry includes a comment noting the affected
package and why the override exists.

## CVE Review Workflow

The `CVE Review` workflow
(`.github/workflows/cve-review.yaml`) runs weekly on
Monday mornings and can be triggered manually. It
scans every image with both Trivy and Grype **without
applying the ignore files**, then compares the results
against the current ignore lists. If any ignored CVE
no longer appears in scan results, the workflow opens
a GitHub issue so the stale override can be removed.

## Review Process

Every ignore entry carries a `REVIEW-BY` date. When
that date passes, all listed CVEs are removed from the
ignore files and the build pipeline is re-run. Only
CVEs that still appear in scan results are re-added
with a new review date. This prevents stale overrides
from accumulating.
