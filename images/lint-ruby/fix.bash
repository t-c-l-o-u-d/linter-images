#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

# shellcheck source=/dev/null
source /usr/local/lib/linter-header.bash
header

mapfile -t ruby_files < <(git ls-files '*.rb' '*.gemspec' '*.rake' 'Gemfile' 'Rakefile')

if [[ ${#ruby_files[@]} -eq 0 ]]; then
    echo "No Ruby files found, skipping."
    exit 0
fi

echo "Running rubocop --autocorrect..."
rubocop_args=(
    --require rubocop-performance
    --require rubocop-rake
    --require rubocop-rspec
    --autocorrect
)
if [[ -f .linter/.rubocop.yml ]]; then
    rubocop_args+=(--config .linter/.rubocop.yml)
elif [[ -f .rubocop.yml ]]; then
    rubocop_args+=(--config .rubocop.yml)
fi
for f in "${ruby_files[@]}"; do
    printf "  %s\n" "$f"
    rubocop "${rubocop_args[@]}" "$f" || true
done

echo "Done. Run lint to verify."
