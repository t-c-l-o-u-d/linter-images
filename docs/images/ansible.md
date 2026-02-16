# Ansible

## Galaxy Collections

The `lint-ansible` image automatically detects and
installs Galaxy collections before linting. It checks
for a `requirements.yml` file in these locations (first
match wins):

1. `.linter/requirements.yml`
2. `collections/requirements.yml`
3. `requirements.yml`

If found, the linter runs
`ansible-galaxy collection install` before
`ansible-lint`. Collections install to
`~/.ansible/collections/` inside the container, so the
workspace mount can stay read-only.

### Example requirements.yml

```yaml
collections:
  - name: community.general
  - name: ansible.posix
    version: ">=1.4.0"
```

## Configuration

ansible-lint config is resolved the same way as other
linter images:

| Priority | Path                    |
| -------- | ----------------------- |
| 1        | `.linter/.ansible-lint` |
| 2        | `.ansible-lint`         |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-ansible:latest \
    /usr/local/bin/lint
```
