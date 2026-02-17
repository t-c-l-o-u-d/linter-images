# Project: linter-images

OCI linter images built on Arch Linux, published to
ghcr.io via GitHub Actions.

## Conventions

### Container tooling

- Never use Docker. Always use Buildah for builds/login
  and Podman for runtime.

### Containerfiles

- AGPL-3.0-or-later license header on every file
- **base-linter** (`images/base-linter/Containerfile`)
  is the foundation image:
  - `FROM ghcr.io/archlinux/archlinux:base`
    (NOT docker.io)
  - Handles all pacman setup: mirrorlist, parallel
    downloads, keyring, sysupgrade
  - Child images must NOT duplicate these steps
- **Child images** (`images/lint-*/Containerfile`)
  inherit from base-linter:
  - `FROM ghcr.io/t-c-l-o-u-d/linter-images/base-linter:latest`
  - Only install packages
    (`pacman --sync --refresh --noconfirm`) and clean up
- Long-form pacman flags:
  `--sync --refresh --sysupgrade` not `-Syu`,
  `--sync --clean --clean` not `-Scc`
- Long-form flags for all commands
  (e.g. `sed --in-place --expression`
  not `sed -i -e`)
- Multi-line container commands: break on each flag,
  one per line. Example:

  ```bash
  podman run \
      --rm \
      --pull always \
      --volume "$(pwd)":/workspace:ro,z \
      IMAGE \
      /usr/local/bin/lint
  ```

- Separate `RUN` per step with a comment above each
- Packages listed one per line, alphabetically sorted
- OCI labels at the bottom
  (authors, description, licenses, source)
- Images are built with `--squash=true` so separate
  RUN layers are fine

### Scripts (lint.bash / fix.bash)

- Do NOT add `command -v` checks for tools installed
  by the Containerfile — they are guaranteed to exist
- Use `set -euo pipefail`
- Use `git ls-files` or `grep -rl` for file discovery
- Accumulate errors and report PASS/FAIL per tool
- Every script prints the ASCII banner on startup
- **Per-file reporting (required):** lint scripts must
  run each tool per-file and print `PASS: <path>` or
  `FAIL: <path>` for every file, then a tool-level
  summary (`PASS: toolname` or
  `FAIL: toolname (N file(s))`). Fix scripts must
  print each file path before processing it.
  Project-level tools (cargo, mypy) that cannot run
  per-file must list all files before the tool runs.
  Tools with structured output (ansible-lint) should
  run once and parse output for per-file PASS/FAIL
  results.

### Packages

- Use pacman only. No AUR, no cargo, no pipx, no npm.
- Prefer the Arch package manager for everything.
- If a tool is not in the Arch repos, get explicit
  user approval before adding a static binary. Pin
  the version and verify with a sha256 or stronger
  checksum.
- Approved exceptions:
  - `hadolint` — static binary from GitHub releases
    (lint-containerfile)

### GitHub

- Org: t-c-l-o-u-d
- Registry: ghcr.io/t-c-l-o-u-d/linter-images
- Image tags: `lint-{language}:{YYYYMMDDHHmmss}`
  and `latest`
- Link: <https://github.com/t-c-l-o-u-d>

## Linting

Do not run linters (shellcheck, shellharden, hadolint,
markdownlint, yamllint, etc.) directly. The pre-commit
hook runs `bash linter-aio.bash fix` then
`bash linter-aio.bash lint` automatically on every
commit. To lint manually, use `bash linter-aio.bash lint`.

## Building images

Never build images locally. When touching anything in
an image directory, commit, push, then trigger
`gh workflow run main.yaml` and wait ~6 minutes for
CI to build.

## Shell commands

Run all commands directly from the repo root
(e.g. `git status`, `python3 scripts/rebuild.py`).
Never use `git -C <path>` or prefix commands with
absolute paths — the working directory is already
the repo root.

## Research

Always check `--help` and `man` pages locally before
consulting web documentation.

## Git

- Commit messages must be 12 words or fewer.
- Never include a `Co-Authored-By` line or give
  Claude credit.
- Always make small, focused commits — one logical
  change per commit.
- Commit frequently. Do not batch multiple changes —
  commit each logical change as soon as it's done
  and passing lint.
- When renaming or moving files/directories, include
  both the old and new paths in the **same commit**
  so git detects the rename.

## Documentation

- Keep all markdown files (`README.md`, `docs/`)
  in sync with the codebase.
- When a change affects documented behavior, update
  the relevant docs in the same commit.
- Outdated docs are treated as bugs.

## Maintenance

- `.linter/.trivyignore` and `.linter/.grype.yaml`
  entries have a `REVIEW-BY:` date. When that date
  has passed, remove all listed CVEs, re-run the
  pipeline, and only re-add any that still appear.
  Never let ignored CVEs go stale.
- Never assume CVE overlap between scanners. Only
  add a CVE to a scanner's ignore list after that
  specific scanner has reported it. Trivy and Grype
  classify and detect CVEs independently.
- Never add CVEs to ignore lists without explicit
  user approval. Report the CVEs found and ask
  before ignoring.

## Code quality

Treat this as production-grade software. Strict code
quality and maintainability are non-negotiable. All
linters must pass; no warnings, no exceptions. Write
clean well-structured code on every change.

- Never suppress, disable, or relax linter rules
  without explicit user approval. This includes
  `shellcheck disable`, yamllint config overrides,
  ignore directives, and any mechanism that weakens
  a check. Always present the finding and proposed
  override, then wait for approval before applying.
