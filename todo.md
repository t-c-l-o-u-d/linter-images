# Todo

## New linter images

- [ ] lint-ssh — `ssh -G -F <file> localhost` validates SSH config
      syntax and unknown options (exit 255 on error)
- [ ] lint-git-config — `git config --list --file <file>` validates
      git config syntax (exit 128 on error)
- [ ] lint-xml — `xmllint` from `libxml2` (pacman). Covers `.xml`
      and `.ui` (GTK builder files)
- [ ] lint-lua — covers `.lua` files
- [ ] lint-go — Go linting
- [ ] lint-openshift — OpenShift linting
- [ ] lint-kustomize — Kustomize linting
- [ ] lint-kubernetes — Kubernetes linting
