# CSV

Runs csvclean on all `*.csv` files. Optionally validates
against a JSON schema with qsv if a schema file exists.

## Configuration

| Priority | Path                      | Tool         |
| -------- | ------------------------- | ------------ |
| 1        | `.linter/csv-schema.json` | qsv validate |
| 2        | `csv-schema.json`         | qsv validate |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-csv:latest \
    /usr/local/bin/lint
```
