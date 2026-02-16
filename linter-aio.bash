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

# --- Supersession rules ---
# When a domain-specific linter is detected, it supersedes the generic
# format linter.  e.g. ansible-lint runs yamllint internally, so
# running lint-yaml separately is redundant and may conflict.
declare -A SUPERSEDES=(
    [lint-ansible]=lint-yaml
)

# --- MIME-based detection (content is truth) ---
# Maps MIME types to linter images. Checked FIRST so that file content
# always wins over filename patterns.
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

# --- Shebang-based detection ---
# Maps shebang interpreters to linter images. Checked SECOND, after MIME.
declare -A SHEBANG_RULES=(
    [bash]=lint-bash
    [python]=lint-python
    [python3]=lint-python
)

# --- Pattern-based detection (LAST RESORT for text/plain files) ---
# Only consulted when MIME detection and shebang detection both fail.
# match types: ext, file, prefix, dir, glob
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
    local rule image match_type pattern entry
    local f base ext matched img mime xdg_mime shebang interp desc
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

    # single-pass file walk
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        ext=""
        [[ "$base" == *.* ]] && ext="${base##*.}"
        matched=0

        # --- STEP 1: MIME detection (content-based, always runs) ---
        mime="$(file --brief --mime-type "$f" 2>/dev/null)" || mime=""

        # skip binary, image, and inode types silently
        case "$mime" in
            application/octet-stream|application/gzip|application/zip) continue ;;
            inode/*|image/*|audio/*|video/*) continue ;;
        esac

        # check file's MIME against content rules
        if [[ -n "$mime" && -n "${MIME_RULES[$mime]+x}" ]]; then
            img="${MIME_RULES[$mime]}"
            [[ "$img" != "skip" ]] && needed["$img"]=1
            matched=1
        fi

        # try mimetype --magic-only for additional content detection
        if [[ $matched -eq 0 && $has_mimetype -eq 1 ]]; then
            xdg_mime="$(mimetype --brief --magic-only "$f" 2>/dev/null)" || xdg_mime=""
            if [[ -n "$xdg_mime" && -n "${MIME_RULES[$xdg_mime]+x}" ]]; then
                img="${MIME_RULES[$xdg_mime]}"
                [[ "$img" != "skip" ]] && needed["$img"]=1
                matched=1
            fi
        fi

        # --- STEP 2: shebang detection ---
        if [[ $matched -eq 0 ]]; then
            shebang="$(head --lines=1 --bytes=256 "$f" 2>/dev/null)" || shebang=""
            if [[ "$shebang" =~ ^#! ]]; then
                # extract interpreter name (e.g. /usr/bin/env bash → bash)
                interp="${shebang##*[\\/]}"
                interp="${interp%% *}"
                if [[ -n "${SHEBANG_RULES[$interp]+x}" ]]; then
                    needed["${SHEBANG_RULES[$interp]}"]=1
                    matched=1
                else
                    unsupported["${base} (${interp})"]=1
                    matched=1
                fi
            fi
        fi

        # --- STEP 3: pattern fallback (LAST RESORT for text/plain) ---
        if [[ $matched -eq 0 ]]; then
            # 3a. exact filename
            if [[ -n "${pat_file[$base]+x}" ]]; then
                img="${pat_file[$base]}"
                [[ "$img" != "skip" ]] && needed["$img"]=1
                matched=1
            fi

            # 3b. extension
            if [[ $matched -eq 0 && -n "$ext" && -n "${pat_ext[$ext]+x}" ]]; then
                img="${pat_ext[$ext]}"
                [[ "$img" != "skip" ]] && needed["$img"]=1
                matched=1
            fi

            # 3c. filename prefix (e.g. Containerfile, Containerfile.alpine)
            if [[ $matched -eq 0 ]]; then
                for entry in "${pat_prefix[@]}"; do
                    IFS='|' read -r img pattern <<< "$entry"
                    if [[ "$base" == "$pattern" || "$base" == "$pattern".* ]]; then
                        [[ "$img" != "skip" ]] && needed["$img"]=1
                        matched=1
                        break
                    fi
                done
            fi
        fi

        # --- STEP 4: flag unrecognized text files ---
        if [[ $matched -eq 0 ]]; then
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

    # apply supersession rules: domain-specific linters replace generic ones
    local specific generic
    for specific in "${!SUPERSEDES[@]}"; do
        if [[ -n "${needed[$specific]+x}" ]]; then
            generic="${SUPERSEDES[$specific]}"
            unset "needed[$generic]"
        fi
    done

    # return sorted list of needed images
    [[ ${#needed[@]} -gt 0 ]] && printf '%s\n' "${!needed[@]}" | sort
}

run_container() {
    local image_name="$1"
    local command="$2"
    local full_image="${REGISTRY}/${image_name}:latest"

    # fix needs read-write; lint is read-only
    local vol_opts="ro,z"
    if [[ "$command" == "/usr/local/bin/fix" ]]; then
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
