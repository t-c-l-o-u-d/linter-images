# Bash

Runs `bash -n` (syntax check), shellcheck, and
shellharden. Discovers scripts by scanning for `#!.*bash`
shebangs and verifying with `file --mime-type`.

## Configuration

| Priority | Path                     | Tool       |
| -------- | ------------------------ | ---------- |
| 1        | `.linter/.shellcheckrc`  | shellcheck |
| 2        | `.linters/shellcheckrc`  | shellcheck |
| 3        | `.shellcheckrc`          | shellcheck |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-bash:latest \
    /usr/local/bin/lint
```
