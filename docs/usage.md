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
  --userns=keep-id:uid=9001,gid=9001 \
  --volume "$(pwd)":/workspace:ro,z \
  IMAGE \
  /usr/local/bin/lint
```

That's it. It exits `0` on pass, `1` on fail. Containers
run as unprivileged UID 9001. The `--userns=keep-id`
flag maps your host user to that UID so volume mounts
are accessible. For `docker`, replace the flag with
`--user "$(id -u):$(id -g)"`.

> **Note:** `lint-rust` requires a read-write mount
> (`:z` instead of `:ro,z`) because cargo writes
> `Cargo.lock` during dependency resolution. The AIO
> script handles this automatically.

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

# run as unprivileged user inside the container
if [[ "$RUNTIME" == "podman" ]]; then
    USER_ARGS="--userns=keep-id:uid=9001,gid=9001"
else
    USER_ARGS="--user $(id -u):$(id -g)"
fi

# Add one block per language your project uses.

# --- Python (fix + lint) ---
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:z \
  "${REGISTRY}/lint-python:latest" \
  /usr/local/bin/fix
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-python:latest" \
  /usr/local/bin/lint

# --- Bash (fix + lint) ---
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:z \
  "${REGISTRY}/lint-bash:latest" \
  /usr/local/bin/fix
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-bash:latest" \
  /usr/local/bin/lint

# --- Lint-only ---
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-yaml:latest" \
  /usr/local/bin/lint
"$RUNTIME" run \
  --rm \
  --pull always \
  $USER_ARGS \
  --volume "$(pwd)":/workspace:ro,z \
  "${REGISTRY}/lint-json:latest" \
  /usr/local/bin/lint
```

Then `chmod +x .git/hooks/pre-commit`. If any linter
fails, the commit is blocked.

> **Tip:** Remove lines for languages your project
> doesn't use.
