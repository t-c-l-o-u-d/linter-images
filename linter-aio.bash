#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

REGISTRY="ghcr.io/t-c-l-o-u-d/linter-images"

# images that support fix mode
declare -A FIX_SUPPORTED=(
    [lint-bash]=1
    [lint-css]=1
    [lint-javascript]=1
    [lint-json]=1
    [lint-python]=1
    [lint-rust]=1
    [lint-yaml]=1
)

# --- Consensus scoring weights ---
# Every detection method votes for a linter. Highest total score wins.
# Content-based methods (MIME, shebang, heuristics) at weight 3;
# name-based methods (extension, filename, prefix) at weight 1.
readonly W_CONTENT=3
readonly W_MIME=3
readonly W_SHEBANG=3
readonly W_EXT=1
readonly W_FILE=1
readonly W_PREFIX=1

# --- MIME type → linter mapping ---
# Both file (libmagic) and mimetype (XDG MIME) results are looked up here.
declare -A MIME_RULES=(
    # file --brief --mime-type detects these from content:
    [application/json]=lint-json
    [text/html]=lint-html
    [text/x-shellscript]=lint-bash
    [application/x-shellscript]=lint-bash
    [text/x-script.python]=lint-python
    [text/x-python]=lint-python

    # mimetype (XDG MIME, --magic-only) adds these:
    [application/yaml]=lint-yaml
    [text/markdown]=lint-markdown
    [text/css]=lint-css
    [text/csv]=lint-csv
    [text/xml]=skip
    [application/xml]=skip
)

# --- Shebang interpreter → linter mapping ---
declare -A SHEBANG_RULES=(
    [bash]=lint-bash
    [python]=lint-python
    [python3]=lint-python
)

# --- Pattern rules (name-based detection) ---
# Extension, filename, and prefix patterns. Each contributes W_EXT,
# W_FILE, or W_PREFIX. match types: ext, file, prefix, dir, glob
PATTERN_RULES=(
    # ansible (project-level markers)
    "lint-ansible|dir|roles"
    "lint-ansible|file|ansible.cfg"
    "lint-ansible|file|site.yml"
    "lint-ansible|file|site.yaml"
    "lint-ansible|glob|playbooks/*.yml"
    "lint-ansible|glob|playbooks/*.yaml"

    # bash
    "lint-bash|ext|bash"
    "lint-bash|ext|sh"
    "lint-bash|file|.bashrc"
    "lint-bash|file|.bash_profile"

    # containerfile (prefix-based)
    "lint-containerfile|prefix|Containerfile"
    "lint-containerfile|prefix|Dockerfile"

    # css
    "lint-css|ext|css"
    "lint-css|ext|scss"

    # csv
    "lint-csv|ext|csv"

    # html
    "lint-html|ext|html"

    # javascript
    "lint-javascript|ext|js"
    "lint-javascript|ext|mjs"
    "lint-javascript|ext|cjs"

    # json
    "lint-json|ext|json"

    # markdown
    "lint-markdown|ext|md"

    # python
    "lint-python|ext|py"

    # rust
    "lint-rust|ext|rs"
    "lint-rust|file|Cargo.toml"

    # systemd
    "lint-systemd|ext|service"
    "lint-systemd|ext|timer"
    "lint-systemd|ext|socket"
    "lint-systemd|ext|path"
    "lint-systemd|ext|mount"
    "lint-systemd|ext|target"
    "lint-systemd|ext|slice"

    # vim
    "lint-vim|ext|vim"
    "lint-vim|file|vimrc"

    # yaml
    "lint-yaml|ext|yml"
    "lint-yaml|ext|yaml"

    # --- skip: known non-code extensions ---
    "skip|ext|bak"
    "skip|ext|bu"
    "skip|ext|build"
    "skip|ext|cfg"
    "skip|ext|conf"
    "skip|ext|crt"
    "skip|ext|editorconfig"
    "skip|ext|eot"
    "skip|ext|gif"
    "skip|ext|gitattributes"
    "skip|ext|gitignore"
    "skip|ext|gotemplate"
    "skip|ext|ico"
    "skip|ext|in"
    "skip|ext|ini"
    "skip|ext|internal"
    "skip|ext|j2"
    "skip|ext|jpg"
    "skip|ext|jpeg"
    "skip|ext|locale"
    "skip|ext|lock"
    "skip|ext|mp3"
    "skip|ext|pdf"
    "skip|ext|placeholder"
    "skip|ext|png"
    "skip|ext|pub"
    "skip|ext|sixel"
    "skip|ext|svg"
    "skip|ext|toml"
    "skip|ext|trivyignore"
    "skip|ext|ttf"
    "skip|ext|txt"
    "skip|ext|webp"
    "skip|ext|woff"
    "skip|ext|woff2"

    # --- skip: known non-code filenames ---
    "skip|file|.ansible-lint"
    "skip|file|.yamllint"
    "skip|file|AUTHORS"
    "skip|file|CHANGELOG"
    "skip|file|COPYING"
    "skip|file|LICENCE"
    "skip|file|LICENSE"
    "skip|file|Makefile"
)

# --- Content heuristic rules ---
# Domain-specific patterns searched in file content. Only run when the
# file's MIME context matches (yaml or plain). Each match adds W_CONTENT.
# Format: "context|linter|extended-regex-pattern"
CONTENT_RULES=(
    # ansible heuristics (context: yaml)
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*become[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*gather_facts[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*tasks[[:space:]]*:"
    "yaml|lint-ansible|^[[:space:]]*-?[[:space:]]*handlers[[:space:]]*:"
    # containerfile heuristics (context: plain)
    "plain|lint-containerfile|^FROM[[:space:]]+[^[:space:]]"
    "plain|lint-containerfile|^(RUN|COPY|ADD|CMD|ENTRYPOINT|EXPOSE|WORKDIR|ENV|ARG|LABEL)[[:space:]]"
)

detect_runtime() {
    if command -v podman > /dev/null 2>&1; then
        echo "podman"
    elif command -v docker > /dev/null 2>&1; then
        echo "docker"
    else
        echo "ERROR: No container runtime found." >&2
        echo "Install podman or docker and try again." >&2
        exit 1
    fi
}

detect_images() {
    # preprocess pattern rules into typed lookup tables
    local -A pat_ext=()
    local -A pat_file=()
    local -a pat_prefix=()
    local -a pat_dir=()
    local -a pat_glob=()
    local -A needed=()
    local -A unsupported=()
    local -A scores=()
    local -A max_w=()
    local rule image match_type pattern entry
    local f base ext img mime xdg_mime shebang interp desc context sample
    local env_arg rule_ctx rule_linter rule_pattern
    local winner best_score best_max_w linter score
    local has_mimetype=0

    # check if mimetype (perl-file-mimeinfo) is available
    command -v mimetype > /dev/null 2>&1 && has_mimetype=1

    for rule in "${PATTERN_RULES[@]}"; do
        IFS='|' read -r image match_type pattern <<< "$rule"
        case "$match_type" in
            ext)    pat_ext["$pattern"]="$image" ;;
            file)   pat_file["$pattern"]="$image" ;;
            prefix) pat_prefix+=("$image|$pattern") ;;
            dir)    pat_dir+=("$image|$pattern") ;;
            glob)   pat_glob+=("$image|$pattern") ;;
        esac
    done

    # project-level detection (dir and glob rules)
    for entry in "${pat_dir[@]}"; do
        IFS='|' read -r image pattern <<< "$entry"
        [[ -d "$pattern" ]] && needed["$image"]=1
    done
    for entry in "${pat_glob[@]}"; do
        IFS='|' read -r image pattern <<< "$entry"
        git -c core.quotePath=false ls-files "$pattern" | grep --quiet . && needed["$image"]=1
    done

    # single-pass file walk with per-file consensus scoring
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        ext=""
        [[ "$base" == *.* ]] && ext="${base##*.}"
        xdg_mime=""

        # reset per-file accumulators
        scores=()
        max_w=()

        # --- MIME vote ---
        mime="$(file --brief --mime-type "$f" 2>/dev/null)" || mime=""

        # skip binary, image, and inode types silently
        case "$mime" in
            application/octet-stream|application/gzip|application/zip) continue ;;
            inode/*|image/*|audio/*|video/*) continue ;;
        esac

        if [[ -n "$mime" && -n "${MIME_RULES[$mime]+x}" ]]; then
            img="${MIME_RULES[$mime]}"
            scores["$img"]=$(( ${scores[$img]:-0} + W_MIME ))
            [[ $W_MIME -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_MIME
        fi

        # --- XDG MIME vote (only when libmagic had no match) ---
        if [[ -z "${MIME_RULES[$mime]+x}" && $has_mimetype -eq 1 ]]; then
            xdg_mime="$(mimetype --brief --magic-only "$f" 2>/dev/null)" || xdg_mime=""
            if [[ -n "$xdg_mime" && -n "${MIME_RULES[$xdg_mime]+x}" ]]; then
                img="${MIME_RULES[$xdg_mime]}"
                scores["$img"]=$(( ${scores[$img]:-0} + W_MIME ))
                [[ $W_MIME -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_MIME
            fi
        fi

        # --- Shebang vote ---
        shebang="$(head --lines=1 "$f" 2>/dev/null)" || shebang=""
        if [[ "$shebang" =~ ^#! ]]; then
            interp="${shebang##*[\\/]}"
            interp="${interp%% *}"
            # handle #!/usr/bin/env wrapper
            if [[ "$interp" == "env" ]]; then
                local -a env_parts=()
                read -ra env_parts <<< "${shebang#*env}"
                for env_arg in "${env_parts[@]}"; do
                    [[ "$env_arg" == -* ]] && continue
                    interp="$env_arg"
                    break
                done
            fi
            if [[ -n "${SHEBANG_RULES[$interp]+x}" ]]; then
                img="${SHEBANG_RULES[$interp]}"
                scores["$img"]=$(( ${scores[$img]:-0} + W_SHEBANG ))
                [[ $W_SHEBANG -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_SHEBANG
            fi
        fi

        # --- Content heuristic votes ---
        context=""
        if [[ "$mime" == "application/yaml" ]]; then
            context="yaml"
        elif [[ "$mime" == "text/plain" ]]; then
            context="plain"
        fi
        # context upgrades: plain → yaml when a stronger signal exists
        if [[ "$context" == "plain" ]]; then
            if [[ "$xdg_mime" == "application/yaml" ]]; then
                context="yaml"
            elif [[ "$ext" == "yml" || "$ext" == "yaml" ]]; then
                context="yaml"
                # MIME tools failed to detect YAML — give lint-yaml
                # the W_MIME vote the format detection would have provided
                scores["lint-yaml"]=$(( ${scores["lint-yaml"]:-0} + W_MIME ))
                [[ $W_MIME -gt ${max_w["lint-yaml"]:-0} ]] && max_w["lint-yaml"]=$W_MIME
            fi
        fi
        if [[ -n "$context" ]]; then
            sample="$(head --lines=50 "$f" 2>/dev/null)" || sample=""
            for rule in "${CONTENT_RULES[@]}"; do
                IFS='|' read -r rule_ctx rule_linter rule_pattern <<< "$rule"
                if [[ "$rule_ctx" == "$context" ]]; then
                    if grep --quiet --extended-regexp "$rule_pattern" <<< "$sample"; then
                        scores["$rule_linter"]=$(( ${scores[$rule_linter]:-0} + W_CONTENT ))
                        [[ $W_CONTENT -gt ${max_w[$rule_linter]:-0} ]] && max_w["$rule_linter"]=$W_CONTENT
                    fi
                fi
            done
        fi

        # --- Pattern votes (extension, filename, prefix) ---
        if [[ -n "${pat_file[$base]+x}" ]]; then
            img="${pat_file[$base]}"
            scores["$img"]=$(( ${scores[$img]:-0} + W_FILE ))
            [[ $W_FILE -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_FILE
        fi
        if [[ -n "$ext" && -n "${pat_ext[$ext]+x}" ]]; then
            img="${pat_ext[$ext]}"
            scores["$img"]=$(( ${scores[$img]:-0} + W_EXT ))
            [[ $W_EXT -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_EXT
        fi
        for entry in "${pat_prefix[@]}"; do
            IFS='|' read -r img pattern <<< "$entry"
            if [[ "$base" == "$pattern" || "$base" == "$pattern".* ]]; then
                scores["$img"]=$(( ${scores[$img]:-0} + W_PREFIX ))
                [[ $W_PREFIX -gt ${max_w[$img]:-0} ]] && max_w["$img"]=$W_PREFIX
                break
            fi
        done

        # --- Pick winner by highest score with tiebreakers ---
        winner=""
        best_score=0
        best_max_w=0
        for linter in "${!scores[@]}"; do
            score="${scores[$linter]}"
            if (( score > best_score )); then
                winner="$linter"
                best_score=$score
                best_max_w=${max_w[$linter]:-0}
            elif (( score == best_score )); then
                # tiebreaker 1: skip always loses to a real linter
                if [[ "$winner" == "skip" && "$linter" != "skip" ]]; then
                    winner="$linter"
                    best_max_w=${max_w[$linter]:-0}
                elif [[ "$linter" != "skip" ]]; then
                    # tiebreaker 2: highest individual vote weight wins
                    if (( ${max_w[$linter]:-0} > best_max_w )); then
                        winner="$linter"
                        best_max_w=${max_w[$linter]:-0}
                    fi
                fi
            fi
        done

        if [[ -n "$winner" && "$winner" != "skip" ]]; then
            needed["$winner"]=1
        elif [[ ${#scores[@]} -eq 0 ]]; then
            # no votes — flag as unsupported
            if [[ -n "$ext" ]]; then
                unsupported[".${ext}"]=1
            else
                unsupported["${base} (${mime})"]=1
            fi
        fi
    done < <(git -c core.quotePath=false ls-files)

    # print unsupported warnings to stderr
    if [[ ${#unsupported[@]} -gt 0 ]]; then
        echo "" >&2
        echo "Note: no linter available for these file types:" >&2
        while IFS= read -r desc; do
            echo "  - ${desc}" >&2
        done < <(printf '%s\n' "${!unsupported[@]}" | sort)
    fi

    # return sorted list of needed images
    [[ ${#needed[@]} -gt 0 ]] && printf '%s\n' "${!needed[@]}" | sort
}

run_container() {
    local image_name="$1"
    local command="$2"
    local full_image="${REGISTRY}/${image_name}:latest"

    # fix needs read-write; lint is normally read-only
    local vol_opts="ro,z"
    if [[ "$command" == "/usr/local/bin/fix" ]]; then
        vol_opts="z"
    fi
    # rust needs rw even for lint (cargo writes Cargo.lock)
    if [[ "$image_name" == "lint-rust" ]]; then
        vol_opts="z"
    fi

    echo ""
    echo "-------------------------------------------"
    echo "  ${image_name} :: ${command##*/}"
    echo "-------------------------------------------"

    "$RUNTIME" run \
        --rm \
        --pull always \
        --volume "$PWD":/workspace:"$vol_opts" \
        "$full_image" \
        "$command"
}

install_hook() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || {
        echo "ERROR: Not a git repository."
        exit 1
    }

    local hooks_dir="${git_dir}/hooks"
    local hook_path="${hooks_dir}/pre-commit"

    echo "Scanning workspace for file types..."
    mapfile -t images < <(detect_images)

    if [[ ${#images[@]} -eq 0 ]]; then
        echo "No recognized file types found. Nothing to install."
        exit 0
    fi

    echo ""
    echo "Detected linter images:"
    for img in "${images[@]}"; do
        echo "  - ${img}"
    done

    # build the hook script with targeted container commands
    local hook_body
    hook_body="#!/usr/bin/env bash
set -euo pipefail
# generated by linter-aio.bash install

REGISTRY=\"${REGISTRY}\"

# detect container runtime
if command -v podman > /dev/null 2>&1; then
    RUNTIME=\"podman\"
elif command -v docker > /dev/null 2>&1; then
    RUNTIME=\"docker\"
else
    echo \"ERROR: No container runtime found.\"
    echo \"Install podman or docker and try again.\"
    exit 1
fi
"

    # fix section: auto-fix images
    local has_fix=0
    for img in "${images[@]}"; do
        if [[ -n "${FIX_SUPPORTED[${img}]+x}" ]]; then
            if [[ ${has_fix} -eq 0 ]]; then
                hook_body+="
# --- Fix ---"
                has_fix=1
            fi
            hook_body+="
\"\$RUNTIME\" run \\
    --rm \\
    --pull always \\
    --volume \"\$(pwd)\":/workspace:z \\
    \"\${REGISTRY}/${img}:latest\" \\
    /usr/local/bin/fix"
        fi
    done

    # lint section: all images (read-only mount)
    hook_body+="

# --- Lint ---"
    for img in "${images[@]}"; do
        hook_body+="
\"\$RUNTIME\" run \\
    --rm \\
    --pull always \\
    --volume \"\$(pwd)\":/workspace:ro,z \\
    \"\${REGISTRY}/${img}:latest\" \\
    /usr/local/bin/lint"
    done
    hook_body+="
"

    mkdir --parents "$hooks_dir"

    if [[ -L "$hook_path" || -f "$hook_path" ]]; then
        local backup
        backup="${hook_path}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$hook_path" "$backup"
        echo ""
        echo "Existing pre-commit hook backed up to: ${backup}"
    fi

    printf '%s' "$hook_body" > "$hook_path"
    chmod +x "$hook_path"
    echo ""
    echo "Pre-commit hook installed at: ${hook_path}"
    exit 0
}

# --- Main ---
# Wrapped in a function so `curl | bash` reads the entire script before
# executing anything — prevents partial-read failures over the pipe.

main() {
    MODE="${1:-lint}"

    if [[ "$MODE" == "install" ]]; then
        install_hook
    fi

    if [[ "$MODE" != "lint" && "$MODE" != "fix" ]]; then
        echo "Usage: linter-aio.bash [lint|fix|install]"
        echo "  lint    — run all detected linters (default)"
        echo "  fix     — auto-fix with supported linters"
        echo "  install — install a pre-commit hook in the current repo"
        exit 1
    fi

    git rev-parse --git-dir > /dev/null 2>&1 || {
        echo "ERROR: Not a git repository." >&2
        echo "Run this script from inside a git-managed project." >&2
        exit 1
    }

    RUNTIME="$(detect_runtime)"

    cat << 'EOF'
===========================================
========= linter-images: tcloud ==========
===========================================
       _       _                 _
      | |_ ___| | ___  _   _  __| |
      | __/ __| |/ _ \| | | |/ _` |
      | || (__| | (_) | |_| | (_| |
       \__\___|_|\___/ \__,_|\__,_|
===========================================
===== https://github.com/t-c-l-o-u-d =====
===========================================
EOF
    echo ""

    echo "Scanning workspace for file types..."
    mapfile -t images < <(detect_images)

    if [[ ${#images[@]} -eq 0 ]]; then
        echo "No recognized file types found."
        exit 0
    fi

    echo ""
    echo "Detected linter images:"
    for img in "${images[@]}"; do
        echo "  - ${img}"
    done

    local errors=0
    local passed=0

    if [[ "$MODE" == "fix" ]]; then
        for img in "${images[@]}"; do
            if [[ -n "${FIX_SUPPORTED[${img}]+x}" ]]; then
                if run_container "$img" "/usr/local/bin/fix"; then
                    echo "PASS: ${img} fix"
                    passed=$((passed + 1))
                else
                    echo "FAIL: ${img} fix"
                    errors=$((errors + 1))
                fi
            fi
        done

        echo ""
        echo "==========================================="
        echo "  Fix Summary"
        echo "==========================================="
        echo "  Fixed:   ${passed}"
        echo "  Errors:  ${errors}"
        echo "==========================================="
    else
        for img in "${images[@]}"; do
            if run_container "$img" "/usr/local/bin/lint"; then
                echo "PASS: ${img}"
                passed=$((passed + 1))
            else
                echo "FAIL: ${img}"
                errors=$((errors + 1))
            fi
        done

        echo ""
        echo "==========================================="
        echo "  Lint Summary"
        echo "==========================================="
        echo "  Passed:  ${passed}"
        echo "  Failed:  ${errors}"
        echo "  Total:   ${#images[@]}"
        echo "==========================================="
    fi

    if [[ ${errors} -gt 0 ]]; then
        echo ""
        echo "${MODE^} failed with ${errors} error(s)"
        exit 1
    fi

    if [[ "$MODE" == "fix" ]]; then
        echo ""
        echo "Done. Run lint to verify."
    fi
}

main "$@"
