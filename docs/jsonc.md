# JSONC (JSON with Comments)

## What is JSONC?

JSONC extends JSON by permitting annotations within JSON data.
Microsoft informally introduced JSONC for VS Code configuration
files. The specification is now maintained by the JSONC-org
GitHub organization and formalized at <https://jsonc.org/>.

## Features over standard JSON

- **Single-line comments**: `// comment`
- **Multi-line comments**: `/* comment */`
- **Trailing commas**: optional, disabled by default in the
  reference parser (`allowTrailingComma: false`)

Comments are ignored during parsing and do not affect data
structure or content.

## File extension

The recommended extension is `.jsonc`. Using `.json` for JSONC
content should be avoided unless a mode line appears at the start
of the file (e.g. `// -*- jsonc -*-`).

In practice, many VS Code/TypeScript files use `.json` despite
containing comments:

- `.vscode/settings.json`
- `.vscode/extensions.json`
- `.vscode/launch.json`
- `.vscode/tasks.json`
- `.vscode/keybindings.json`
- `devcontainer.json` / `.devcontainer/devcontainer.json`
- `tsconfig.json` / `jsconfig.json`

Tools outside the Microsoft ecosystem (Deno, Biome) use the
`.jsonc` extension, making detection trivial.

## Parsers by language

- **JavaScript/TypeScript**: microsoft/node-jsonc-parser
  (reference implementation)
- **C++**: stephenberry/glaze
- **Elixir**: massivefermion/jsonc
- **Go**: tidwall/jsonc
- **Python**: n-takumasa/json-with-comments
- **PHP**: otar/jsonc
- **Rust**: dprint/jsonc-parser
- **Java**: Jackson (JsonReadFeature.ALLOW_JAVA_COMMENTS)
- **Kotlin**: kotlinx.serialization.json

## Impact on lint-json

`jq` does not support JSONC. The lint-json image uses
`python-json5` (which parses both JSON5 and JSONC) as a
fallback for validation. JSONC files are validated but not
formatted, since no comment-preserving formatter is available
in the Arch repos.

```bash
cd ~/git/linter-images
claude --resume 4e3086f3-565a-41d9-b4d6-6bd91b1dea1c
```
