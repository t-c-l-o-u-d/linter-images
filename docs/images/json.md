# JSON

Validates JSON syntax for all `*.json` files. Supports
JSONC (JSON with comments) via `json5` as a fallback
parser. Standard JSON is parsed first with `json.loads`;
only files that fail standard parsing are retried with
`json5`. This handles `devcontainer.json`,
`tsconfig.json`, and other Microsoft-ecosystem files
that use JSONC without mangling URLs or other strings
that contain `//`.

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-json:latest \
    /usr/local/bin/lint
```
