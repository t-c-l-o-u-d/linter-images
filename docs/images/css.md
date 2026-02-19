# CSS

Runs stylelint on `*.css` and `*.scss` files, and biome
on `*.css` files only (biome does not support SCSS).

When no project config is found, stylelint uses
[stylelint-config-standard](https://github.com/stylelint/stylelint-config-standard)
as the default ruleset.

## Configuration

| Priority | Path                         | Tool      |
| -------- | ---------------------------- | --------- |
| 1        | `.linter/.stylelintrc.json`  | stylelint |
| 2        | `.linters/stylelintrc.json`  | stylelint |
| 3        | `.stylelintrc.json`          | stylelint |
| 1        | `.linter/biome.json`         | biome     |
| 2        | `.linters/biome.json`        | biome     |
| 3        | `biome.json`                 | biome     |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-css:latest \
    /usr/local/bin/lint
```
