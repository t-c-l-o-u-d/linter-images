# Python

Runs ruff (check + format), mypy (strict mode), and
bandit (security analysis) on `*.py` files.

## Configuration

| Priority | Path                 | Tool   |
| -------- | -------------------- | ------ |
| 1        | `.linter/ruff.toml`  | ruff   |
| 2        | `ruff.toml`          | ruff   |
| 1        | `.linter/mypy.ini`   | mypy   |
| 2        | `mypy.ini`           | mypy   |
| 1        | `.linter/.bandit`    | bandit |
| 2        | `.bandit`            | bandit |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-python:latest \
    /usr/local/bin/lint
```
