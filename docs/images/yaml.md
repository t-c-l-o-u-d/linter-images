# YAML

Runs yamllint on `*.yml` and `*.yaml` files.

## Configuration

| Priority | Path                      | Tool     |
| -------- | ------------------------- | -------- |
| 1        | `.linter/.yamllint.yaml`  | yamllint |
| 2        | `.yamllint.yaml`          | yamllint |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-yaml:latest \
    /usr/local/bin/lint
```
