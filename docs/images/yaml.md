# YAML

Runs yamllint on `*.yml` and `*.yaml` files.

## Ansible project handling

In fix mode, yamlfmt skips YAML files that contain Ansible
keywords (`tasks:`, `become:`, `gather_facts:`,
`handlers:`) when the workspace has a `roles/` directory
or `ansible.cfg`. Those files belong to `lint-ansible` and
yamlfmt could break their structure. Lint mode (yamllint)
still checks all YAML files for defense in depth.

## Configuration

| Priority | Path                      | Tool     |
| -------- | ------------------------- | -------- |
| 1        | `.linter/.yamlfmt`        | yamlfmt  |
| 2        | `.linters/yamlfmt`        | yamlfmt  |
| 3        | `.yamlfmt`                | yamlfmt  |
| 1        | `.linter/.yamllint.yaml`  | yamllint |
| 2        | `.linters/yamllint`       | yamllint |
| 3        | `.yamllint.yaml`          | yamllint |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-yaml:latest \
    /usr/local/bin/lint
```
