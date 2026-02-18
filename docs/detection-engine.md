# Detection Engine Design: Weighted Consensus

## Problem Statement

The `linter-aio.bash` script must determine which linter container
images to run for a given repository. This requires identifying the
**type** of every tracked file so it can be routed to the correct
linter.

The original implementation used a strict waterfall:

1. Exact filename match
2. Extension match
3. Filename prefix match
4. Shebang match
5. Give up

This is fragile. A bash script named `Containerfile.bu` gets caught
by the prefix rule (`Containerfile*`) and routed to
`lint-containerfile` — wrong. The file's **content** is bash, but
its **name** looks like a Containerfile. Name-based detection should
be a method of absolute last resort.

The second iteration flipped to MIME-first:

1. MIME type (`file --brief --mime-type`)
2. XDG MIME (`mimetype --brief --magic-only`)
3. Shebang
4. Pattern fallback (ext/filename/prefix)

Better, but introduced a new problem: MIME tells you the **format**
(YAML, JSON, shell) but not the **domain** (ansible, kubernetes,
docker-compose). Every ansible playbook returns `application/yaml`,
same as a CI config or a docker-compose file. The MIME-first
waterfall routes all YAML to `lint-yaml`, ignoring the fact that
ansible-lint is the correct tool for playbooks.

A post-hoc "supersession" rule (`lint-ansible` removes `lint-yaml`)
was added as a band-aid, but this is a separate concern (container
scheduling) duct-taped onto the detection engine.

## The Consensus Approach

Instead of a waterfall where the first match wins, **every detection
method runs on every file** and casts a weighted vote. The linter
with the highest total score wins.

This is how the approach works:

1. For each tracked file, run ALL applicable detection methods.
2. Each method casts a vote for a linter image, weighted by the
   method's reliability.
3. Tally the votes per linter image.
4. The linter with the highest score wins.
5. That linter is added to the `needed` set.
6. After all files are processed, run the `needed` set of images.

### Why Consensus?

- **No single method is authoritative.** MIME is great for format
  but blind to domain. Extensions are great for domain but trivially
  spoofed. Shebangs only apply to scripts. Content heuristics are
  powerful but can false-positive. By combining signals, we get
  robust identification that degrades gracefully when any single
  method is wrong.

- **Naturally handles conflicts.** The `Containerfile.bu` case:
  MIME says bash (strong signal), prefix says containerfile (weak
  signal), extension says skip (weak signal). Bash wins by weight,
  no special-case logic needed.

- **Scales to new linters.** Adding a kubernetes linter means adding
  content heuristic patterns (`apiVersion:`, `kind:`) and MIME
  context rules. No waterfall reordering, no supersession entries.
  The scoring system handles priority automatically.

- **Self-documenting confidence.** A file matching 3 methods at high
  weight is a confident identification. A file matching 1 method at
  low weight is uncertain. The scores tell you how sure the engine
  is.

## Detection Methods and Weights

### Weight Assignments

| Method             | Weight |
| ------------------ | ------ |
| Content heuristics | 3      |
| MIME type          | 3      |
| XDG MIME           | 3      |
| Shebang            | 3      |
| Extension          | 1      |
| Filename           | 1      |
| Prefix             | 1      |

**Content heuristics** (W=3): Domain-specific patterns in file
content. Strongest individual signal but can false-positive on
isolated keywords. Equal weight to MIME means a single heuristic
match cannot override MIME — you need 2+ for consensus.

**MIME type** (W=3): `file --brief --mime-type` uses libmagic to
identify format from content. Very reliable for what it detects,
but limited vocabulary (doesn't know YAML, CSS, Markdown from
content alone).

**XDG MIME** (W=3): `mimetype --brief --magic-only` from
perl-file-mimeinfo. Detects YAML, Markdown, CSS, CSV that libmagic
misses. Only runs when libmagic had no match — so at most one MIME
vote per file, not two.

**Shebang** (W=3): First line `#!` interpreter detection. Definitive
for scripts. Equal weight to MIME because both are content-based and
equally reliable in their domain.

**Extension** (W=1): File extension (`.py`, `.yml`, etc.). Weakest
signal — trivially misleading (`.bu` extension on a Containerfile).

**Filename** (W=1): Exact filename match (`.bashrc`, `Cargo.toml`).
Weak but useful for extensionless config files.

**Prefix** (W=1): Filename prefix match (`Containerfile`,
`Dockerfile`). Weakest — the source of the original bug.

### Why W_CONTENT = W_MIME = W_SHEBANG = 3?

Equal weights for all content-based methods creates a critical
property: **a single content heuristic match (3 points) cannot
override MIME + extension (3 + 1 = 4 points)**. You need at least
two heuristic matches (6 points) to beat MIME + extension. This
prevents a single keyword like `hosts:` from incorrectly reclassifying
a generic YAML file as ansible.

If content heuristics had weight 5, a single `hosts:` match (5
points) would override MIME (3) + extension (1) = 4. That's too
aggressive — `hosts:` alone is not definitive evidence of ansible.

If content heuristics had weight 4, a single match (4 points) would
tie with MIME + extension (4 points), requiring tiebreaker logic for
common cases. Undesirable.

At weight 3, the math works out cleanly:

| Scenario | lint-yaml score | lint-ansible score | Winner |
| ---------- | ---------------- | -------------------- | -------- |
| YAML file, no ansible keywords | 3 (MIME) + 1 (ext) = 4 | 0 | lint-yaml |
| YAML file, 1 ansible keyword | 3 + 1 = 4 | 3 | lint-yaml |
| YAML file, 2 ansible keywords | 3 + 1 = 4 | 6 | lint-ansible |
| YAML file, 3 ansible keywords | 3 + 1 = 4 | 9 | lint-ansible |

This means **a file must contain at least 2 ansible-specific
keywords to be classified as ansible**. One keyword is ambiguous;
two is consensus. This is exactly the confidence level we want.

## Content Heuristic Rules

Content heuristics are domain-specific patterns searched within
file content. They only run when the file's MIME type matches a
known context, limiting unnecessary I/O.

### Context Derivation

The "context" for content heuristics is derived from the file's
MIME type:

| MIME type | Context |
| ----------- | --------- |
| `application/yaml` | `yaml` |
| `text/plain` (when XDG MIME says `application/yaml`) | `yaml` |
| `text/plain` (otherwise) | `plain` |
| Everything else | (no context — heuristics skip) |

Note: `text/x-shellscript` does NOT get a context. If MIME
definitively identifies a file as a shell script, content heuristics
do not run. There is nothing to disambiguate — it IS a shell script.
A Containerfile with a bash shebang is detected as shell by MIME,
and content heuristics correctly do not attempt to reclassify it.

Content heuristics only run for ambiguous formats:

- **YAML**: Format is known, domain is not. Could be ansible,
  kubernetes, docker-compose, GitHub Actions, or generic YAML.
- **Plain text**: Format itself is unknown. Could be a
  Containerfile, systemd unit, INI file, or truly plain text.

### Ansible Heuristics (context: yaml)

These patterns are searched in the first 50 lines / 4 KB of the
file. Each match adds W_CONTENT (3) to `lint-ansible`.

| Pattern | Rationale |
| --- | --- |
| `^[[:space:]]*-?[[:space:]]*become[[:space:]]*:` | Privilege escalation. Unique. |
| `^[[:space:]]*-?[[:space:]]*gather_facts[[:space:]]*:` | Fact gathering. Unique. |
| `^[[:space:]]*-?[[:space:]]*tasks[[:space:]]*:` | Task list. Rare outside ansible. |
| `^[[:space:]]*-?[[:space:]]*handlers[[:space:]]*:` | Handler declaration. Unique. |

The `-?` in each pattern handles YAML list items (`- tasks:` vs
`tasks:`). The `[[:space:]]*:` ensures we match YAML keys, not
values or comments.

**Why these four keywords?** They were chosen for specificity:

- `hosts:` was considered but rejected — too generic. Docker
  compose, various configs, and even plain YAML documentation
  might have `hosts:` as a key.
- `roles:` was considered but rejected — generic enough to appear
  in RBAC configs, database schemas, etc.
- `become:` and `gather_facts:` are the most ansible-specific
  keywords in existence. They appear in virtually no other context.
- `tasks:` and `handlers:` are slightly less specific but still
  strongly indicative of ansible when found in a YAML file.

**Scoring scenarios for a typical ansible playbook:**

A minimal playbook (`- hosts: all, become: true, tasks: [...]`)
would match `become` and `tasks` = 6 points for lint-ansible,
beating lint-yaml's 4 points (MIME + ext).

A complex playbook with `become`, `gather_facts`, `tasks`, and
`handlers` would score 12 points for lint-ansible. Overwhelmingly
confident.

A YAML file with only `tasks:` (ambiguous — could be a generic
config) scores 3 for lint-ansible vs 4 for lint-yaml. lint-yaml
wins. This is the correct conservative choice — a single keyword
is not enough evidence.

### Containerfile Heuristics (context: plain)

These patterns detect Dockerfile syntax in files that MIME
identifies as `text/plain` (i.e., files without a shebang or
other identifying magic bytes).

- `^FROM[[:space:]]+[^[:space:]]` — The FROM directive. Every
  Containerfile starts with or contains at least one FROM. Rare in
  natural language text at the start of a line.
- `^(RUN|COPY|ADD|...)[[:space:]]` — Other Dockerfile directives. A
  real Containerfile will have multiple of these. A text file randomly
  containing "FROM something" is unlikely to also contain
  "RUN something".

**Two patterns required for confidence:**

A single `FROM` match gives lint-containerfile 3 points. With a
prefix match (`Containerfile` name), that's 4 total. A second
directive match (`RUN`, `COPY`, etc.) adds another 3, giving
7 total. This high score reflects genuine confidence.

A random text file that happens to start a line with "FROM " would
get 3 points for lint-containerfile. Without a Containerfile prefix
(1 point) or other signals, it would need to also match a second
Dockerfile directive to reach 6 points. False positives require
two independent coincidences.

**Why context: plain and not context: shellscript?**

A file with a bash shebang is definitively a shell script. MIME
returns `text/x-shellscript`, which maps to `lint-bash` at weight
3. The shebang adds another 3 for `lint-bash`, totaling 6. Content
heuristics for Containerfile should NOT run because:

1. The file IS a shell script. MIME said so. The shebang confirms.
2. A bash script may legitimately contain `FROM` in a variable,
   heredoc, or string — not because it's a Containerfile.
3. Even if heuristics ran, `lint-bash` at 6 points would beat
   `lint-containerfile` at 3-4 points. But not running them avoids
   the noise entirely.

This is why context is derived from MIME type. `text/x-shellscript`
produces no context. `text/plain` produces context `plain`. Content
heuristics only run when MIME says "I don't know what this is"
(text/plain) or "I know the format but not the domain" (YAML).

## Tiebreaker Rules

Ties are rare with the weight system described above, but they
can occur. The tiebreaker rules are applied in order:

### Rule 1: Skip Always Loses

If one tied linter is `skip` (the pseudo-linter for ignored file
types) and the other is a real linter, the real linter wins.

**Example:** `Cargo.toml`

- Extension `.toml` → `skip` (1 point)
- Filename `Cargo.toml` → `lint-rust` (1 point)
- Tie at 1 point. `lint-rust` wins because `skip` always loses.

**Rationale:** The point of `skip` is to suppress noise for known
non-code files. If ANY detection method thinks a file needs linting,
we should lint it. False positives (linting a file unnecessarily)
are much less harmful than false negatives (silently ignoring a
file that should be linted).

### Rule 2: Highest Individual Vote Weight

Between two real linters tied on total score, the linter that
received a vote from the highest-weighted method wins.

**Example (hypothetical):** A file scores:

- `lint-foo`: 4 points (MIME 3 + ext 1), max individual weight = 3
- `lint-bar`: 4 points (content 3 + file 1), max individual weight = 3

Still tied on max weight. This scenario is theoretically possible
but extremely unlikely in practice because:

- MIME and content heuristics don't run in the same context (if MIME
  identifies the format, content heuristics for that format don't
  add a competing vote)
- A file matching one linter by MIME and a different linter by
  content would need to match yet another method to tie

If this edge case occurs, the iteration order of the associative
array determines the winner (non-deterministic in bash, but
consistent within a single run).

## Complete Scoring Walkthrough: All Test Cases

### Case 1: `Containerfile.bu` (bash script with misleading name)

File content: starts with `#!/usr/bin/env bash`, contains bash code.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-shellscript`) | lint-bash | 3 | bash=3 |
| Shebang (`bash`) | lint-bash | 3 | bash=6 |
| Content heuristics | (no context for shellscript) | — | — |
| Extension (`.bu`) | skip | 1 | skip=1 |
| Prefix (`Containerfile`) | lint-containerfile | 1 | containerfile=1 |

**Result:** lint-bash wins with 6 points. Correct.

The misleading `Containerfile` prefix contributes only 1 point.
MIME + shebang at 6 points completely overwhelms it.

### Case 2: `Containerfile` (real, no shebang)

File content: `FROM archlinux:base`, `RUN pacman ...`, etc.
No shebang line.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/plain`) | (no match) | 0 | — |
| Shebang | (none) | — | — |
| Content: `^FROM\s+\S` | lint-containerfile | 3 | containerfile=3 |
| Content: `^RUN\s` | lint-containerfile | 3 | containerfile=6 |
| Prefix (`Containerfile`) | lint-containerfile | 1 | containerfile=7 |

**Result:** lint-containerfile wins with 7 points. Correct.

Even without the prefix match, content heuristics alone give 6
points — enough to win against any other contestant.

### Case 3: `Containerfile.alpine` (multi-stage variant)

Same as Case 2 but with `.alpine` extension.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/plain`) | (no match) | 0 | — |
| Content: `^FROM\s+\S` | lint-containerfile | 3 | containerfile=3 |
| Content: `^RUN\s` | lint-containerfile | 3 | containerfile=6 |
| Extension (`.alpine`) | (no match) | — | — |
| Prefix (`Containerfile`) | lint-containerfile | 1 | containerfile=7 |

**Result:** lint-containerfile wins with 7 points. Correct.

### Case 4: `playbook.yml` (ansible with become + tasks)

File content: YAML with `become: true` and `tasks:` sections.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`application/yaml`) | lint-yaml | 3 | yaml=3 |
| Content: `become:` | lint-ansible | 3 | ansible=3 |
| Content: `tasks:` | lint-ansible | 3 | ansible=6 |
| Extension (`.yml`) | lint-yaml | 1 | yaml=4 |

**Result:** lint-ansible wins with 6 vs 4. Correct.

Two ansible keywords create consensus that overrides the generic
YAML identification.

### Case 5: `config.yml` (generic YAML, no ansible keywords)

File content: Plain YAML key-value pairs, no ansible keywords.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`application/yaml`) | lint-yaml | 3 | yaml=3 |
| Content heuristics | (no ansible keywords match) | — | — |
| Extension (`.yml`) | lint-yaml | 1 | yaml=4 |

**Result:** lint-yaml wins with 4 points. Correct.

### Case 6: `config.yml` with one ansible keyword (`tasks:`)

File content: YAML with `tasks:` key but no other ansible signals.
Could be a CI config or a generic task list.

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`application/yaml`) | lint-yaml | 3 | yaml=3 |
| Content: `tasks:` | lint-ansible | 3 | ansible=3 |
| Extension (`.yml`) | lint-yaml | 1 | yaml=4 |

**Result:** lint-yaml wins with 4 vs 3. Correct.

A single keyword is not enough to reclassify a YAML file. The
engine conservatively keeps it as generic YAML. This is the key
advantage of equal weights (W_CONTENT = W_MIME = 3): one heuristic
match is never decisive.

### Case 7: `script.sh` (standard bash script)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-shellscript`) | lint-bash | 3 | bash=3 |
| Shebang (`bash`) | lint-bash | 3 | bash=6 |
| Extension (`.sh`) | lint-bash | 1 | bash=7 |

**Result:** lint-bash wins with 7 points. Correct.

All methods agree — maximum consensus.

### Case 8: `myscript` (extensionless bash script)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-shellscript`) | lint-bash | 3 | bash=3 |
| Shebang (`bash`) | lint-bash | 3 | bash=6 |
| Extension | (none) | — | — |
| Filename | (no match) | — | — |

**Result:** lint-bash wins with 6 points. Correct.

No extension or filename match, but MIME + shebang provide enough
confidence.

### Case 9: `Cargo.toml` (Rust project manifest)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/plain`) | (no match) | 0 | — |
| Extension (`.toml`) | skip | 1 | skip=1 |
| Filename (`Cargo.toml`) | lint-rust | 1 | rust=1 |

**Result:** Tie at 1 point. Tiebreaker: skip loses to real
linter. lint-rust wins. Correct.

### Case 10: `settings.toml` (generic TOML, no linter)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/plain`) | (no match) | 0 | — |
| Extension (`.toml`) | skip | 1 | skip=1 |

**Result:** skip wins with 1 point. File silently ignored. Correct.

### Case 11: `.bashrc` (dotfile, no extension)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-shellscript`) | lint-bash | 3 | bash=3 |
| Shebang | (typically none in .bashrc) | — | — |
| Filename (`.bashrc`) | lint-bash | 1 | bash=4 |

**Result:** lint-bash wins with 4 points. Correct.

Note: the old code had a bug where `ext="${f##*.}"` was computed
from the full path, causing dotfiles in subdirectories (like
`.config/git/hooks/post-merge`) to produce bogus extensions. The
fix (`ext="${base##*.}"`) and the check `[[ "$base" == *.* ]]`
ensure that dotfiles without a real extension get `ext=""`.

### Case 12: `photo.webp` (binary image)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`image/webp`) | (binary skip) | — | *continue* |

**Result:** Skipped before scoring. The binary/image/inode skip
runs before any votes are cast.

### Case 13: `index.html` (HTML file)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/html`) | lint-html | 3 | html=3 |
| Extension (`.html`) | lint-html | 1 | html=4 |

**Result:** lint-html wins with 4 points. Correct.

### Case 14: `script.py` (Python file with shebang)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-python` or `text/x-script.python`) | lint-python | 3 | python=3 |
| Shebang (`python3`) | lint-python | 3 | python=6 |
| Extension (`.py`) | lint-python | 1 | python=7 |

**Result:** lint-python wins with 7 points. Correct.

### Case 15: `main.rs` (Rust source)

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-c` or `text/plain`) | (no match) | 0 | — |
| Extension (`.rs`) | lint-rust | 1 | rust=1 |

**Result:** lint-rust wins with 1 point (sole voter). Correct.

libmagic doesn't understand Rust syntax, so MIME falls through.
The extension is the only signal, but it's sufficient because
there's no competing vote.

### Case 16: Extensionless perl script

| Method | Linter | Weight | Running Total |
| -------- | -------- | -------- | --------------- |
| MIME (`text/x-perl`) | (no match in MIME_RULES) | 0 | — |
| Shebang (`perl`) | (no match in SHEBANG_RULES) | 0 | — |

**Result:** No votes. Flagged as unsupported:
`scriptname (text/x-perl)`. Correct — we don't have a perl linter.

## Project-Level Detection

Some linters operate at the project level, not the file level.
ansible-lint needs to see the entire project structure (roles/,
inventory, playbooks/) to understand context. Detecting "is this an
ansible project?" cannot be done per-file — it requires examining
directory structure.

Project-level detection runs BEFORE the per-file scoring loop and
directly adds images to the `needed` set. Each match is also
recorded in `LINTER_FILES` with a `(project: ...)` annotation:

| Rule Type | Pattern | Image |
| ----------- | --------- | ------- |
| `dir` | `roles` | lint-ansible |
| `file` | `ansible.cfg` | lint-ansible |
| `file` | `site.yml` | lint-ansible |
| `file` | `site.yaml` | lint-ansible |
| `glob` | `playbooks/*.yml` | lint-ansible |
| `glob` | `playbooks/*.yaml` | lint-ansible |

This is complementary to per-file scoring. Project-level detection
says "this project needs ansible-lint." Per-file scoring says "this
specific YAML file is ansible, not generic YAML." Both contribute
to the `needed` set, and duplicate additions are idempotent.

**Why not use project-level signals in per-file scoring?**

We considered adding a W_PROJECT weight to every YAML file in an
ansible project. But this would bias ALL YAML files toward ansible,
including CI configs (`ci.yml`), docker-compose files, and other
non-ansible YAML. Project structure tells you "this project uses
ansible" — it doesn't tell you "this specific file is an ansible
playbook." Per-file content heuristics handle the per-file question.

## Supersession: Removed

The previous implementation had a `SUPERSEDES` map:

```bash
declare -A SUPERSEDES=(
    [lint-ansible]=lint-yaml
)
```

This removed `lint-yaml` from `needed` whenever `lint-ansible` was
detected, because ansible-lint runs yamllint internally.

With consensus scoring, supersession is no longer needed in the
detection engine. The per-file scoring correctly routes:

- Ansible playbooks → `lint-ansible` (via content heuristics)
- Generic YAML configs → `lint-yaml` (via MIME + extension)

Both images may end up in `needed` for a project that has both
types of files. This is correct — they serve different files.

If redundant yamllint output on ansible files is a concern (since
ansible-lint already runs yamllint internally), that's a
**configuration concern**, not a detection concern. The detection
engine's job is to correctly identify what needs linting. Suppressing
redundant runs is a scheduling optimization that belongs in a
separate layer.

## Implementation: Data Structures

### Weight Constants

```bash
readonly W_CONTENT=3
readonly W_MIME=3
readonly W_SHEBANG=3
readonly W_EXT=1
readonly W_FILE=1
readonly W_PREFIX=1
```

### MIME_RULES (unchanged)

```bash
declare -A MIME_RULES=(
    [application/json]=lint-json
    [text/html]=lint-html
    [text/x-shellscript]=lint-bash
    [application/x-shellscript]=lint-bash
    [text/x-script.python]=lint-python
    [text/x-python]=lint-python
    [application/yaml]=lint-yaml
    [text/markdown]=lint-markdown
    [text/css]=lint-css
    [text/csv]=lint-csv
    [text/xml]=skip
    [application/xml]=skip
)
```

### SHEBANG_RULES (unchanged)

```bash
declare -A SHEBANG_RULES=(
    [bash]=lint-bash
    [python]=lint-python
    [python3]=lint-python
)
```

### CONTENT_RULES (new)

```bash
CONTENT_RULES=(
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*become[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*gather_facts[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*tasks[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*handlers[[:space:]]*:"
    "plain|lint-containerfile|^FROM[[:space:]]+[^[:space:]]"
    "plain|lint-containerfile|^(RUN|COPY|ADD|CMD|ENTRYPOINT|EXPOSE|WORKDIR|ENV|ARG|LABEL)[[:space:]]"
)
```

### PATTERN_RULES (unchanged)

Same as current. Extension, filename, and prefix patterns that each
contribute W_EXT / W_FILE / W_PREFIX to the scoring.

### Output Globals

`detect_images()` communicates results through two global arrays
instead of stdout (avoiding subshell loss of state):

```bash
declare -A LINTER_FILES=()   # linter → newline-separated file list
declare -a DETECTED_IMAGES=() # sorted list of needed image names
```

`LINTER_FILES` is populated during detection so callers can display
the exact file list associated with each linter. Project-level
matches are annotated (e.g. `(project: roles/)`), and per-file
matches record the file path.

## Implementation: Per-File Scoring Loop

Pseudocode for the file walk inside `detect_images()`:

```text
for each tracked file f:
    skip if not a regular file (broken symlinks)
    extract basename and extension

    reset scores={} and max_weight={} for this file
    xdg_mime=""

    # --- MIME vote ---
    mime = file --brief --mime-type f
    skip if binary/image/inode (continue to next file)
    if mime in MIME_RULES:
        linter = MIME_RULES[mime]
        scores[linter] += W_MIME
        update max_weight[linter]

    # --- XDG MIME vote (only if MIME had no match) ---
    if mime NOT in MIME_RULES and mimetype available:
        xdg_mime = mimetype --brief --magic-only f
        if xdg_mime in MIME_RULES:
            linter = MIME_RULES[xdg_mime]
            scores[linter] += W_MIME
            update max_weight[linter]

    # --- Shebang vote ---
    first_line = head --lines=1 --bytes=256 f
    if first_line starts with #!:
        interp = extract interpreter name
        if interp in SHEBANG_RULES:
            scores[SHEBANG_RULES[interp]] += W_SHEBANG
            update max_weight

    # --- Content heuristic votes ---
    context = derive from mime / xdg_mime
    if context is set:
        sample = head --lines=50 --bytes=4096 f
        for each rule in CONTENT_RULES:
            if rule.context == context:
                if sample matches rule.pattern:
                    scores[rule.linter] += W_CONTENT
                    update max_weight

    # --- Pattern votes ---
    if basename in pat_file:
        scores[pat_file[basename]] += W_FILE
        update max_weight

    if ext in pat_ext:
        scores[pat_ext[ext]] += W_EXT
        update max_weight

    for each prefix rule:
        if basename matches prefix:
            scores[prefix.linter] += W_PREFIX
            update max_weight
            break

    # --- Pick winner ---
    winner = linter with highest score
    tiebreakers:
        1. skip always loses to real linter
        2. higher max_weight wins
    if winner exists and != skip:
        needed[winner] = 1
        LINTER_FILES[winner] += f
    elif no votes at all:
        flag as unsupported
```

## Context Upgrades and Synthetic MIME Votes

When `file` returns `text/plain`, the content heuristic context starts
as `plain`. Stronger signals can upgrade it to a more specific context:

1. **XDG MIME upgrade**: If `mimetype --magic-only` returns
   `application/yaml`, context becomes `yaml`. The XDG MIME vote
   already gives `lint-yaml` its W_MIME points, so no synthetic vote
   is needed.
2. **Extension upgrade**: If the file extension is `.yml` or `.yaml`,
   context becomes `yaml`. This is critical because both `file` and
   `mimetype` frequently return `text/plain` for small YAML files
   that lack sufficient magic bytes.

### The Synthetic MIME Vote Problem

When context is upgraded from extension alone (both MIME tools returned
`text/plain`), lint-yaml only has W_EXT (1 point). A single content
heuristic match for lint-ansible (W_CONTENT = 3) would beat it. This
violates the design principle that **a single keyword cannot override
format detection** — the entire weight system assumes lint-yaml gets
W_MIME (3) + W_EXT (1) = 4 points for YAML files.

The fix: when extension upgrades the context to `yaml`, also give
`lint-yaml` a synthetic W_MIME vote. This compensates for the MIME
tools' failure and restores the intended scoring balance:

| Scenario | lint-yaml | lint-ansible | Winner |
| ---------- | ----------- | ------------- | -------- |
| MIME works, 1 keyword | 3 (MIME) + 1 (ext) = 4 | 3 | lint-yaml |
| MIME fails, 1 keyword, no synthetic | 1 (ext) | 3 | lint-ansible (wrong!) |
| MIME fails, 1 keyword, with synthetic | 3 (synth) + 1 (ext) = 4 | 3 | lint-yaml (correct) |
| MIME fails, 2 keywords, with synthetic | 4 | 6 | lint-ansible (correct) |

```text
context = ""
if mime == application/yaml:      context = "yaml"
elif mime == text/plain:          context = "plain"

# upgrade if stronger signal exists
if context == "plain":
    if xdg_mime == application/yaml:
        context = "yaml"
    elif ext in (yml, yaml):
        context = "yaml"
        scores[lint-yaml] += W_MIME   # synthetic MIME vote
```

## Future Extensions

### Kubernetes Detection

When `lint-kubernetes` is added:

```bash
CONTENT_RULES+=(
    "yaml|lint-kubernetes|^apiVersion:\\s+\\S"
    "yaml|lint-kubernetes|^kind:\\s+\\S"
)
```

Two matches (apiVersion + kind in the same file) would give 6
points for lint-kubernetes, beating lint-yaml's 4 points. Correct.

### Docker Compose Detection

When `lint-docker-compose` is added:

```bash
CONTENT_RULES+=(
    "yaml|lint-docker-compose|^services:\\s*$"
    "yaml|lint-docker-compose|^\\s+image:\\s+\\S"
)
```

### Systemd Unit Detection by Content

Currently, systemd units are detected purely by extension
(`.service`, `.timer`, etc.). If extensionless systemd files become
common, content heuristics can be added:

```bash
CONTENT_RULES+=(
    "plain|lint-systemd|^\\[(Unit|Service|Timer|Socket|Mount|Path|Slice|Install)\\]"
)
```

### New Shebang Interpreters

Adding a Ruby linter:

```bash
SHEBANG_RULES[ruby]=lint-ruby
MIME_RULES[text/x-ruby]=lint-ruby
PATTERN_RULES+=("lint-ruby|ext|rb")
```

All three detection methods participate in scoring automatically.
No waterfall reordering needed.

## Performance Considerations

The consensus approach runs more detection methods per file than
the waterfall:

- **Waterfall**: stops at first match (average ~1.5 methods/file)
- **Consensus**: runs all applicable methods (average ~3 methods/file)

Additional I/O per file:

- `file --brief --mime-type`: always runs (same as waterfall)
- `mimetype --magic-only`: only if MIME had no match (same)
- `head --lines=1`: always for shebang (was conditional in waterfall)
- `head --lines=50`: only for yaml/plain context files

For a repository with 500 files, the extra cost is roughly:

- 500 additional `head --lines=1` calls (negligible — first line
  is always in page cache after `file` already read the file)
- ~100 `head --lines=50` calls (for YAML and plain text files)
- ~100 `grep` calls per content rule (6 rules x 100 files = 600
  grep invocations on small buffers)

Total additional wall time: under 2 seconds on a modern system.
The user explicitly stated "correctness is more important than
speed."

## Summary

The weighted consensus detection engine replaces both the fragile
name-first waterfall and the incomplete MIME-first waterfall with a
robust scoring system where every detection method contributes
evidence and the most-supported linter wins.

Key properties:

1. **Content wins over names.** MIME + shebang at weight 3 each
   will always outscore extension + prefix at weight 1 each.
2. **Single heuristic is not decisive.** W_CONTENT = W_MIME = 3
   means one keyword match cannot override format detection.
3. **Consensus required for domain reclassification.** Moving a
   file from lint-yaml to lint-ansible requires 2+ keyword matches.
4. **No supersession needed.** Per-file scoring naturally routes
   files to the correct domain-specific linter.
5. **Extensible.** Adding new linters means adding rules to existing
   data structures. No waterfall reordering or supersession entries.
6. **Deterministic tiebreakers.** Skip loses. Higher max weight wins.
