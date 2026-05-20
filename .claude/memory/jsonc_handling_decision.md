---
name: jsonc-handling-decision
description: Design notes for handling JSONC files in lint-json — captures the four options considered and the open question on which to ship
type: project
---

# JSONC handling decision

## Problem

`fix.bash` in lint-json runs `jq .` on all `*.json` files.
JSONC files (JSON with Comments) cause `jq` parse errors.
`lint.bash` already handles JSONC via a `json5.loads()` fallback.

## Where JSONC actually lives

JSONC is almost entirely a Microsoft/VS Code/TypeScript thing:

- `.vscode/settings.json`
- `.vscode/extensions.json`
- `.vscode/launch.json`
- `.vscode/tasks.json`
- `.vscode/keybindings.json`
- `devcontainer.json` / `.devcontainer/devcontainer.json`
- `tsconfig.json` / `jsconfig.json`

Tools outside that ecosystem use `.jsonc` or `.json5` extensions
(Deno, Biome), making detection trivial.

## User concerns

- The AIO must "just work" with zero user configuration.
  No config files, no pattern files, no setup burden.
- Solution must be extensible for future formats/tools.
- Approach should be proportional to the actual problem scope.

## Options considered

### 1. Config-driven JSONC patterns (rejected)

A `.linter/.jsonc-patterns` file where projects declare JSONC globs.
Rejected: violates "just works" principle. Imposes configuration
burden on users before they get value.

### 2. Shared Python classifier (considered)

A `json-classify.py` that auto-detects format by parsing content.
Both scripts consume classified file lists. Extensible for new
formats.

Pros: automatic, no config, extensible.
Cons: new file, more infrastructure than the problem may warrant.

### 3. Path-based exclusion in fix.bash (considered)

Exclude known VS Code/TypeScript JSONC paths from `jq` formatting.
`lint.bash` already handles them via json5 fallback.

Pros: simplest change, covers real-world cases, no new files.
Cons: new JSONC paths require updating the exclusion list.

### 4. Separate lint-jsonc image (considered)

Dedicated image for JSONC with its own discovery, validation,
and future formatting hook.

Pros: clean separation, dedicated tooling.
Cons: significant infrastructure for a narrow problem.

## Open question

Which approach (or combination) best balances simplicity,
extensibility, and the "just works" principle?
