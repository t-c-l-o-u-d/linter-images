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

# detection rules: image|match_type|pattern
# match types: ext, file, prefix, shebang, dir, glob
# image "skip" silently ignores a file type
LINTER_RULES=(
    # ansible (project-level markers)
    "lint-ansible|dir|roles"
    "lint-ansible|file|ansible.cfg"
    "lint-ansible|file|site.yml"
    "lint-ansible|file|site.yaml"
    "lint-ansible|glob|playbooks/*.yml"
    "lint-ansible|glob|playbooks/*.yaml"

    # bash (shebang-based)
    "lint-bash|shebang|bash"

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
    "skip|ext|cfg"
    "skip|ext|conf"
    "skip|ext|editorconfig"
    "skip|ext|eot"
    "skip|ext|gif"
    "skip|ext|gitattributes"
    "skip|ext|gitignore"
    "skip|ext|ico"
    "skip|ext|ini"
    "skip|ext|jpg"
    "skip|ext|jpeg"
    "skip|ext|lock"
    "skip|ext|png"
    "skip|ext|svg"
    "skip|ext|toml"
    "skip|ext|trivyignore"
    "skip|ext|ttf"
    "skip|ext|txt"
    "skip|ext|woff"
    "skip|ext|woff2"

    # --- skip: known non-code filenames ---
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
    # preprocess rules into typed lookup tables
    local -A rule_ext=()
    local -A rule_file=()
    local -a rule_prefix=()
    local -a rule_shebang=()
    local -a rule_dir=()
    local -a rule_glob=()
    local -A needed=()
    local -A unsupported=()
    local rule image match_type pattern entry
    local f base ext matched img shebang interp mime desc

    for rule in "${LINTER_RULES[@]}"; do
        IFS='|' read -r image match_type pattern <<< "$rule"
        case "$match_type" in
            ext)     rule_ext["$pattern"]="$image" ;;
            file)    rule_file["$pattern"]="$image" ;;
            prefix)  rule_prefix+=("$image|$pattern") ;;
            shebang) rule_shebang+=("$image|$pattern") ;;
            dir)     rule_dir+=("$image|$pattern") ;;
            glob)    rule_glob+=("$image|$pattern") ;;
        esac
    done

    # project-level detection (dir and glob rules)
    for entry in "${rule_dir[@]}"; do
        IFS='|' read -r image pattern <<< "$entry"
        [[ -d "$pattern" ]] && needed["$image"]=1
    done
    for entry in "${rule_glob[@]}"; do
        IFS='|' read -r image pattern <<< "$entry"
        git ls-files "$pattern" | grep --quiet . && needed["$image"]=1
    done

    # single-pass file walk
    while IFS= read -r f; do
        base="$(basename "$f")"
        ext=""
        [[ "$f" == *.* ]] && ext="${f##*.}"
        matched=0

        # 1. exact filename (O(1) lookup)
        if [[ -n "${rule_file[$base]+x}" ]]; then
            img="${rule_file[$base]}"
            [[ "$img" != "skip" ]] && needed["$img"]=1
            matched=1
        fi

        # 2. filename prefix (e.g. Containerfile, Containerfile.alpine)
        for entry in "${rule_prefix[@]}"; do
            IFS='|' read -r img pattern <<< "$entry"
            if [[ "$base" == "$pattern" || "$base" == "$pattern".* ]]; then
                [[ "$img" != "skip" ]] && needed["$img"]=1
                matched=1
                break
            fi
        done

        # 3. extension (O(1) lookup)
        if [[ -n "$ext" && -n "${rule_ext[$ext]+x}" ]]; then
            img="${rule_ext[$ext]}"
            [[ "$img" != "skip" ]] && needed["$img"]=1
            matched=1
        fi

        # 4. shebang (only if unmatched — avoids reading every file)
        if [[ $matched -eq 0 ]]; then
            shebang="$(head --lines=1 "$f" 2>/dev/null)" || shebang=""
            if [[ "$shebang" =~ ^#! ]]; then
                for entry in "${rule_shebang[@]}"; do
                    IFS='|' read -r img pattern <<< "$entry"
                    if [[ "$shebang" =~ ^#!.*${pattern} ]]; then
                        needed["$img"]=1
                        matched=1
                        break
                    fi
                done

                # unmatched shebang — flag interpreter as unsupported
                if [[ $matched -eq 0 ]]; then
                    interp="${shebang##*[\\/]}"
                    interp="${interp%% *}"
                    unsupported["${base} (${interp})"]=1
                    matched=1
                fi
            fi
        fi

        # 5. unsupported (still unmatched after all checks)
        if [[ $matched -eq 0 ]]; then
            mime="$(file --brief --mime-type "$f" 2>/dev/null)" || continue

            # skip binary and image files silently
            if [[ "$mime" == application/octet-stream ]] \
                || [[ "$mime" == inode/* ]] \
                || [[ "$mime" == image/* ]]; then
                continue
            fi

            # skip non-bash shell scripts silently
            if [[ "$mime" == text/x-shellscript ]]; then
                continue
            fi

            if [[ -n "$ext" ]]; then
                unsupported[".${ext}"]=1
            else
                unsupported["${base} (${mime})"]=1
            fi
        fi
    done < <(git ls-files)

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
