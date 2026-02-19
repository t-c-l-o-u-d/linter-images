# Rust

Runs cargo fmt, clippy (pedantic), audit, deny, test,
and check (debug + release).

Requires a read-write volume mount because cargo writes
`Cargo.lock` during dependency resolution. Use `:z`
instead of `:ro,z`. The AIO script handles this
automatically.

## Configuration

| Priority | Path                  | Tool       |
| -------- | --------------------- | ---------- |
| 1        | `.linter/deny.toml`   | cargo deny |
| 2        | `.linters/deny.toml`  | cargo deny |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-rust:latest \
    /usr/local/bin/lint
```
