# linter-images

OCI linter images built on Arch Linux. Pull them, mount your repo, done.

Registry: `ghcr.io/t-c-l-o-u-d/linter-images`

## Quickstart: lint-all

The fastest way to get started. One image scans your repo and runs the right linters automatically.

### Lint everything

```bash
podman run --rm \
    --volume "$(pwd)":/workspace \
    --env WORKSPACE_HOST_PATH="$(pwd)" \
    --volume /run/podman/podman.sock:/run/podman/podman.sock \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-all:latest \
    /usr/local/bin/lint
```

### Fix and lint everything

```bash
podman run --rm \
    --volume "$(pwd)":/workspace \
    --env WORKSPACE_HOST_PATH="$(pwd)" \
    --volume /run/podman/podman.sock:/run/podman/podman.sock \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-all:latest \
    /usr/local/bin/fix
```

It detects file types, pulls only the needed linter images, and reports a single pass/fail.

> **Note:** The `lint-all` image needs access to a container runtime to invoke specialized linter images. Mount your podman socket and set `WORKSPACE_HOST_PATH` so child containers can access your repo.

---

## Available Images

| Image | Tools | Auto-fix? |
|-------|-------|-----------|
| **`lint-all`** | **orchestrator (invokes all others)** | **Yes** |
| `lint-ansible` | ansible-lint | No |
| `lint-bash` | shellcheck, shellharden | Yes |
| `lint-containerfile` | hadolint | No |
| `lint-css` | stylelint, biome | Yes |
| `lint-html` | tidy | No |
| `lint-javascript` | eslint, biome | Yes |
| `lint-json` | python json.tool | No |
| `lint-markdown` | markdownlint-cli2 | No |
| `lint-python` | ruff, mypy | Yes |
| `lint-systemd` | systemd-analyze | No |
| `lint-vim` | vint | No |
| `lint-yaml` | yamllint | No |

Every image has a `/usr/local/bin/lint` script. Images marked **Yes** also have a `/usr/local/bin/fix` script that auto-formats your code.

## How It Works

Each container expects your repo mounted at `/workspace`. The scripts use `git ls-files` to find files, so the mount **must** be a git repo.

```
podman run --rm -v "$(pwd)":/workspace IMAGE /usr/local/bin/lint
```

That's it. It exits `0` on pass, `1` on fail.

---

## Pre-commit Hook (Fix + Lint)

This runs **fix first** (auto-format), then **lint** to catch anything fix couldn't handle. Runs locally before every commit.

### Step 1: Create the hook file

Create `.git/hooks/pre-commit` in your project:

```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io/t-c-l-o-u-d/linter-images"

# Add one block per language your project uses.
# Remove what you don't need.

# --- Python ---
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-python:latest" /usr/local/bin/fix
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-python:latest" /usr/local/bin/lint

# --- Bash ---
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-bash:latest" /usr/local/bin/fix
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-bash:latest" /usr/local/bin/lint

# --- JavaScript ---
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-javascript:latest" /usr/local/bin/fix
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-javascript:latest" /usr/local/bin/lint

# --- CSS ---
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-css:latest" /usr/local/bin/fix
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-css:latest" /usr/local/bin/lint

# --- Lint-only (no auto-fix available) ---
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-ansible:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-containerfile:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-html:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-json:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-markdown:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-systemd:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-vim:latest" /usr/local/bin/lint
podman run --rm -v "$(pwd)":/workspace "${REGISTRY}/lint-yaml:latest" /usr/local/bin/lint
```

### Step 2: Make it executable

```bash
chmod +x .git/hooks/pre-commit
```

### Step 3: That's it

Next time you `git commit`, the hook runs automatically. If any linter fails, the commit is blocked until you fix the issues.

> **Tip:** Delete any lines for languages your project doesn't use. Fewer images = faster commits.

---

## GitHub Actions (Lint Only)

Add this to `.github/workflows/lint.yaml` in your project:

### Single language

```yaml
name: Lint

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint-python:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest
    steps:
      - uses: actions/checkout@v4
      - run: /usr/local/bin/lint
```

### Multiple languages (matrix)

```yaml
name: Lint

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        image:
          - lint-python
          - lint-bash
          - lint-yaml
          - lint-javascript
          # add or remove as needed
    container:
      image: ghcr.io/t-c-l-o-u-d/linter-images/${{ matrix.image }}:latest
    steps:
      - uses: actions/checkout@v4
      - run: /usr/local/bin/lint
```

---

## GitLab CI (Lint Only)

Add this to `.gitlab-ci.yml` in your project:

### Single language

```yaml
lint-python:
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest
  script:
    - /usr/local/bin/lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Multiple languages

```yaml
stages:
  - lint

.lint-template:
  stage: lint
  script:
    - /usr/local/bin/lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

lint-python:
  extends: .lint-template
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest

lint-bash:
  extends: .lint-template
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-bash:latest

lint-yaml:
  extends: .lint-template
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-yaml:latest

# add more as needed
```

---

## Passing Linter Config Overrides

The linters look for config files in the working directory (`/workspace`). Since your repo is mounted there, **any config file in your repo root is picked up automatically** — no extra steps needed.

For example, if your repo has a `ruff.toml` at the root, the Python linter uses it.

### Common config files by linter

| Image | Config files (place in your repo root) |
|-------|---------------------------------------|
| `lint-ansible` | `.ansible-lint` |
| `lint-bash` | `.shellcheckrc` |
| `lint-containerfile` | `.hadolint.yaml` |
| `lint-css` | `.stylelintrc.json`, `biome.json` |
| `lint-html` | `.tidyrc` |
| `lint-javascript` | `eslint.config.js`, `biome.json` |
| `lint-markdown` | `.markdownlint-cli2.yaml`, `.markdownlint.yaml` |
| `lint-python` | `ruff.toml`, `pyproject.toml`, `mypy.ini`, `setup.cfg` |
| `lint-vim` | `.vintrc.yaml` |
| `lint-yaml` | `.yamllint.yaml`, `.yamllint` |

### Config files stored outside the repo

If your config lives somewhere else (e.g., a shared company config), mount it explicitly:

```bash
# Mount a ruff config from your home directory
podman run --rm \
  -v "$(pwd)":/workspace \
  -v "${HOME}/.config/ruff/ruff.toml":/workspace/ruff.toml:ro \
  ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest \
  /usr/local/bin/lint
```

The `:ro` flag mounts it read-only so the container can't modify your config.

In GitHub Actions, use an extra step to copy the config before linting:

```yaml
steps:
  - uses: actions/checkout@v4
  - name: Fetch shared lint config
    run: curl -o ruff.toml https://example.com/shared/ruff.toml
  - run: /usr/local/bin/lint
```

In GitLab CI, use `before_script`:

```yaml
lint-python:
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest
  before_script:
    - curl -o ruff.toml https://example.com/shared/ruff.toml
  script:
    - /usr/local/bin/lint
```

---

## License

AGPL-3.0-or-later. See [COPYING](COPYING).
