# HTML

Runs tidy in syntax-check mode on `*.html` files.

## Configuration

| Priority | Path               | Tool |
| -------- | ------------------ | ---- |
| 1        | `.linter/.tidyrc`  | tidy |
| 2        | `.tidyrc`          | tidy |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-html:latest \
    /usr/local/bin/lint
```
