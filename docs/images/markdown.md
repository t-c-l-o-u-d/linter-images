# Markdown

Runs markdownlint-cli2 on `*.md` files.

## Configuration

| Priority | Path                               | Tool              |
| -------- | ---------------------------------- | ----------------- |
| 1        | `.linter/.markdownlint-cli2.yaml`  | markdownlint-cli2 |
| 2        | `.linters/markdownlint-cli2.yaml`  | markdownlint-cli2 |
| 3        | `.markdownlint-cli2.yaml`          | markdownlint-cli2 |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-markdown:latest \
    /usr/local/bin/lint
```
