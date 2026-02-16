# Images

## Available Images

| Image                | Tools                                       | Auto-fix? |
| -------------------- | ------------------------------------------- | --------- |
| `lint-ansible`       | ansible-lint                                | No        |
| `lint-bash`          | shellcheck, shellharden                     | Yes       |
| `lint-containerfile` | hadolint                                    | No        |
| `lint-csv`           | csvclean, qsv validate                      | No        |
| `lint-css`           | stylelint, biome                            | Yes       |
| `lint-html`          | tidy                                        | No        |
| `lint-javascript`    | eslint, biome                               | Yes       |
| `lint-json`          | python json (JSONC-aware), jq               | Yes       |
| `lint-markdown`      | markdownlint-cli2                           | No        |
| `lint-python`        | ruff, mypy, bandit                          | Yes       |
| `lint-rust`          | cargo fmt, clippy, audit, deny, test, check | Yes       |
| `lint-systemd`       | systemd-analyze                             | No        |
| `lint-vim`           | vint                                        | No        |
| `lint-yaml`          | yamllint, yamlfmt                           | Yes       |

Every image has a `/usr/local/bin/lint` script. Images
marked **Yes** also have a `/usr/local/bin/fix` script
that auto-formats your code.

## Per-Image Details

- [lint-ansible](images/ansible.md)
- [lint-bash](images/bash.md)
- [lint-containerfile](images/containerfile.md)
- [lint-css](images/css.md)
- [lint-csv](images/csv.md)
- [lint-html](images/html.md)
- [lint-javascript](images/javascript.md)
- [lint-json](images/json.md)
- [lint-markdown](images/markdown.md)
- [lint-python](images/python.md)
- [lint-rust](images/rust.md)
- [lint-systemd](images/systemd.md)
- [lint-vim](images/vim.md)
- [lint-yaml](images/yaml.md)
