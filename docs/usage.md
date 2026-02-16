# Details

## How It Works

Each container expects your repo mounted at `/workspace`.
Most scripts use `git ls-files` to discover files, so
the mount should be a git repo. Exceptions like
`lint-rust` and `lint-ansible` use their own
project-level discovery (`Cargo.toml`, playbook
scanning).

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
