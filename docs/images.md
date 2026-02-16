# Images

## Available Images

| Image                | Tools                                          | Auto-fix? |
| -------------------- | ---------------------------------------------- | --------- |
| `lint-ansible`       | ansible-lint                                   | No        |
| `lint-bash`          | shellcheck, shellharden                        | Yes       |
| `lint-containerfile` | hadolint                                       | No        |
| `lint-csv`           | csvclean, qsv validate                         | No        |
| `lint-css`           | stylelint, biome                               | Yes       |
| `lint-html`          | tidy                                           | No        |
| `lint-javascript`    | eslint, biome                                  | Yes       |
| `lint-json`          | python json.tool                               | No        |
| `lint-markdown`      | markdownlint-cli2                              | No        |
| `lint-python`        | ruff, mypy, bandit                             | Yes       |
| `lint-rust`          | cargo fmt, clippy, audit, deny, test, check    | Yes       |
| `lint-systemd`       | systemd-analyze                                | No        |
| `lint-vim`           | vint                                           | No        |
| `lint-yaml`          | yamllint                                       | No        |

Every image has a `/usr/local/bin/lint` script. Images
marked **Yes** also have a `/usr/local/bin/fix` script
that auto-formats your code.
