# Todo

## aio script: route to existing linters

- [x] Add `.bash`, `.sh` to detection rules (lint-bash)
- [x] Add `.bashrc`, `.bash_profile` to detection rules (lint-bash)
- [ ] Add `.network`, `.nspawn` to detection rules (lint-systemd)
      — verify `systemd-analyze verify` supports these subsystem configs
- [ ] Fix extensionless file detection: dotfile paths like
      `.config/git/secrets/hooks/post-merge` confuse the ext parser
      (`${f##*.}` returns `config/git/...` instead of empty)

## aio script: add to skip lists

- [x] Skip extensions: `.mp3`, `.pdf`, `.bak`, `.crt`, `.pub`,
      `.sixel`, `.bu`, `.build`, `.in`, `.gotemplate`, `.internal`,
      `.webp`, `.locale`, `.placeholder`, `.j2`
- [x] Skip filenames: `.ansible-lint`, `.yamllint`
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
