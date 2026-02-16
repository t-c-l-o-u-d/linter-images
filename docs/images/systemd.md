# Systemd

Runs `systemd-analyze verify` on `*.service`, `*.timer`,
`*.socket`, `*.path`, `*.mount`, `*.target`, and
`*.slice` files.

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-systemd:latest \
    /usr/local/bin/lint
```
