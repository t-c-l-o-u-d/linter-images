# Todo

## aio script: route to existing linters

- [ ] Add `.network`, `.nspawn` to detection rules (lint-systemd)
      — verify `systemd-analyze verify` supports these subsystem configs
- [ ] Fix extensionless file detection: dotfile paths like
      `.config/git/secrets/hooks/post-merge` confuse the ext parser
      (`${f##*.}` returns `config/git/...` instead of empty)

## aio script: add to skip lists

- [ ] Skip `.ssh/*`, `.config/git/*`, `.config/dunst/*`,
      `.config/sway/*`, extensionless `config`, `inventory`
      — these are dotfile configs, not project source code

## New linter images

- [ ] lint-xml — `xmllint` from `libxml2` (pacman). Covers `.xml`
      and `.ui` (GTK builder files)
- [ ] lint-ruby — `rubocop` from `rubocop` (pacman). Covers
      `Gemfile`, `.rb`, `Rakefile`, `Gemfile.lock`
- [ ] lint-lua — covers `.lua` files

## Features

- [ ] OpenShift linting
- [ ] Kustomize linting
- [ ] Kubernetes linting
- [ ] Go linting

## Never lint

- [ ] Key files `application/x-pem-file`
