# Ruby

Runs rubocop with the performance, rake, and rspec
plugins on `*.rb`, `*.gemspec`, `*.rake`, `Gemfile`,
and `Rakefile` files.

## Configuration

| Priority | Path                    | Tool    |
| -------- | ----------------------- | ------- |
| 1        | `.linter/.rubocop.yml`  | rubocop |
| 2        | `.linters/rubocop.yml`  | rubocop |
| 3        | `.rubocop.yml`          | rubocop |

## Usage

```bash
podman run \
    --rm \
    --pull always \
    --volume "$(pwd)":/workspace:ro,z \
    ghcr.io/t-c-l-o-u-d/linter-images/lint-ruby:latest \
    /usr/local/bin/lint
```
