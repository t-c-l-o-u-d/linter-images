# linter-images

OCI linter images built on Arch Linux. Pull them, mount
your repo, done. Works with `podman` (preferred) or `docker`.

Registry: `ghcr.io/t-c-l-o-u-d/linter-images`

## Quickstart

The fastest way to get started. One script detects your
file types and runs the correct linters automatically.

### Lint everything

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash
```

### Fix and lint everything

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s fix

curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s lint
```

### Install as a pre-commit hook

```bash
curl -sL https://github.com/t-c-l-o-u-d/linter-images/raw/main/linter-aio.bash | bash -s install
```

This backs up any existing pre-commit hook and installs
one that runs fix + lint before every commit.

## Linter Config Overrides

The linters look for config files in the repository root or `.linter/`.

---

## GitHub Actions (Lint Only)

Add this to `.github/workflows/lint.yaml` in your
project:

```yaml
name: Lint

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        linter:
          - python
          - bash
          - yaml
          - javascript
          # add or remove as needed
    container:
      image: ghcr.io/t-c-l-o-u-d/linter-images/lint-${{ matrix.linter }}:latest
    steps:
      - uses: actions/checkout@v6
      - run: /usr/local/bin/lint
```

---

## GitLab CI (Lint Only)

Add this to `.gitlab-ci.yml` in your project:

```yaml
stages:
  - lint

lint:
  stage: lint
  image: ghcr.io/t-c-l-o-u-d/linter-images/lint-${LINTER}:latest
  script:
    - /usr/local/bin/lint
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  parallel:
    matrix:
      - LINTER:
          - python
          - bash
          - yaml
          # add more as needed
```

## License

AGPL-3.0-or-later. See [COPYING](COPYING).
