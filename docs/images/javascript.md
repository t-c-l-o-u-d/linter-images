# JavaScript

Runs eslint and biome on `*.js`, `*.mjs`, and `*.cjs`
files.

## Configuration

| Priority | Path                         | Tool   |
| -------- | ---------------------------- | ------ |
| 1        | `.linter/eslint.config.js`   | eslint |
| 2        | `.linters/eslint.config.js`  | eslint |
| 3        | `eslint.config.js`           | eslint |
| 1        | `.linter/biome.json`         | biome  |
| 2        | `.linters/biome.json`        | biome  |
| 3        | `biome.json`                 | biome  |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-javascript:latest \
    /usr/local/bin/lint
```
