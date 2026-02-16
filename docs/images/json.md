# JSON

Validates JSON syntax for all `*.json` files. Supports
JSONC (JSON with comments) by stripping `//` and `/* */`
comments before parsing. This handles
`devcontainer.json`, `tsconfig.json`, and other
Microsoft-ecosystem files that use JSONC.

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-json:latest \
    /usr/local/bin/lint
```
