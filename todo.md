# Todo

## New linter images

- [ ] lint-ssh — `ssh -G -F <file> localhost` validates SSH config
      syntax and unknown options (exit 255 on error)
- [ ] lint-git-config — `git config --list --file <file>` validates
      git config syntax (exit 128 on error)

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
