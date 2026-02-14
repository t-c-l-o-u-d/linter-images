# linter-images

OCI linter images built on Arch Linux. Pull them, mount
your repo, done. Works with podman or docker.

Registry: `ghcr.io/t-c-l-o-u-d/linter-images`

## Quickstart

The fastest way to get started. One script detects your
file types and runs the right linters automatically.

### Lint everything

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash
```

### Fix and lint everything

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s fix
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s lint
```

### Install as a pre-commit hook

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s install
```

This backs up any existing pre-commit hook and installs
one that runs fix + lint before every commit.

---

## Available Images

| Image                | Tools                     | Auto-fix? |
| -------------------- | ------------------------- | --------- |
| `lint-ansible`       | ansible-lint              | No        |
| `lint-bash`          | shellcheck, shellharden   | Yes       |
| `lint-containerfile` | hadolint                  | No        |
| `lint-css`           | stylelint, biome          | Yes       |
| `lint-html`          | tidy                      | No        |
| `lint-javascript`    | eslint, biome             | Yes       |
| `lint-json`          | python json.tool          | No        |
| `lint-markdown`      | markdownlint-cli2         | No        |
| `lint-python`        | ruff, mypy                | Yes       |
| `lint-systemd`       | systemd-analyze           | No        |
| `lint-vim`           | vint                      | No        |
| `lint-yaml`          | yamllint                  | No        |

Every image has a `/usr/local/bin/lint` script. Images
marked **Yes** also have a `/usr/local/bin/fix` script
that auto-formats your code.

## How It Works

Each container expects your repo mounted at `/workspace`.
The scripts use `git ls-files` to find files, so the
mount **must** be a git repo.

```bash
podman run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  IMAGE \
  /usr/local/bin/lint
```

That's it. It exits `0` on pass, `1` on fail. Works the
same way with `docker` instead of `podman`.

---

## Pre-commit Hook

The easiest way to install a pre-commit hook:

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s install
```

This auto-detects your file types, generates targeted
container commands for each linter, and backs up any
existing hook. The generated hook supports both podman
and docker.

For manual setup, create `.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io/t-c-l-o-u-d/linter-images"

# detect container runtime
if command -v podman > /dev/null 2>&1; then
    RUNTIME="podman"
elif command -v docker > /dev/null 2>&1; then
    RUNTIME="docker"
else
    echo "ERROR: No container runtime found."
    exit 1
fi

# Add one block per language your project uses.

# --- Python (fix + lint) ---
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:z \
  "${REGISTRY}/lint-python:latest" \
  /usr/local/bin/fix
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-python:latest" \
  /usr/local/bin/lint

# --- Bash (fix + lint) ---
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:z \
  "${REGISTRY}/lint-bash:latest" \
  /usr/local/bin/fix
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-bash:latest" \
  /usr/local/bin/lint

# --- Lint-only ---
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-yaml:latest" \
  /usr/local/bin/lint
"$RUNTIME" run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-json:latest" \
  /usr/local/bin/lint
```

Then `chmod +x .git/hooks/pre-commit`. If any linter
fails, the commit is blocked.

> **Tip:** Remove lines for languages your project
> doesn't use.

---

## GitHub Actions (Lint Only)

Add this to `.github/workflows/lint.yaml` in your
project:

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

### Single language (GitLab)

```yaml
lint-python:
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest
  script:
    - /usr/local/bin/lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Multiple languages (GitLab)

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

The linters look for config files in the working directory
(`/workspace`). Since your repo is mounted there, **any
config file in your repo root is picked up automatically**
-- no extra steps needed.

For example, if your repo has a `ruff.toml` at the root,
the Python linter uses it.

### Common config files by linter

Place config files in `.linter/` (preferred) or the
repo root. The `.linter/` path takes priority.

| Image                | Config files                         |
| -------------------- | ------------------------------------ |
| `lint-ansible`       | `.ansible-lint`                      |
| `lint-bash`          | `.shellcheckrc`                      |
| `lint-containerfile` | `.hadolint.yaml`                     |
| `lint-css`           | `.stylelintrc.json`, `biome.json`    |
| `lint-html`          | `.tidyrc`                            |
| `lint-javascript`    | `eslint.config.js`, `biome.json`     |
| `lint-markdown`      | `.markdownlint-cli2.yaml`            |
| `lint-python`        | `ruff.toml`, `mypy.ini`              |
| `lint-vim`           | `.vintrc.yaml`                       |
| `lint-yaml`          | `.yamllint.yaml`                     |

### Config files stored outside the repo

If your config lives somewhere else (e.g., a shared
company config), mount it explicitly:

```bash
# Mount a ruff config from your home directory
podman run \
  --rm \
  --pull always \
  --volume "$(pwd)":/workspace:ro,z \
  --volume "$HOME/.config/ruff/ruff.toml":/workspace/ruff.toml:ro,z \
  ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest \
  /usr/local/bin/lint
```

The `:ro` flag mounts it read-only so the container
can't modify your config. Replace `podman` with `docker`
if needed.

In GitHub Actions, use an extra step to copy the config
before linting:

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
