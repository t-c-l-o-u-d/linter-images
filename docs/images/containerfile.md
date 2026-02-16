# Containerfile

Runs hadolint against `Containerfile*` and `Dockerfile*`
patterns.

## Configuration

| Priority | Path                     | Tool     |
| -------- | ------------------------ | -------- |
| 1        | `.linter/.hadolint.yaml` | hadolint |
| 2        | `.hadolint.yaml`         | hadolint |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-containerfile:latest \
    /usr/local/bin/lint
```
