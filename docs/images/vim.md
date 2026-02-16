# Vim

Runs vint on `*.vim` files and files named `vimrc`.

## Configuration

| Priority | Path                    | Tool |
| -------- | ----------------------- | ---- |
| 1        | `.linter/.vintrc.yaml`  | vint |
| 2        | `.vintrc.yaml`          | vint |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-vim:latest \
    /usr/local/bin/lint
```
