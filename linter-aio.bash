#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

REGISTRY="ghcr.io/t-c-l-o-u-d/linter-images"

# images that support fix mode
declare -A FIX_SUPPORTED=(
    [lint-bash]=1
    [lint-css]=1
    [lint-javascript]=1
    [lint-python]=1
)

# extensions we have linters for
SUPPORTED_EXT_RE="^(py|css|scss|html|js|mjs|cjs|json|yml|yaml|vim|service|timer|socket|path|mount|target|slice|md)$"
# mimetypes we have linters for (bash is detected via shebang + mimetype)
SUPPORTED_MIME_RE="^text/x-shellscript$"
# non-code files to silently skip
SKIP_EXT_RE="^(txt|lock|toml|cfg|ini|conf|gitignore|gitattributes|editorconfig|trivyignore|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot)$"
# known filenames we handle
SUPPORTED_NAMES_RE="^(Containerfile|vimrc|ansible\.cfg|site\.yml|site\.yaml)$"
# non-code filenames to silently skip
SKIP_NAMES_RE="^(COPYING|LICENSE|LICENCE|AUTHORS|CHANGELOG|Makefile)$"

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
    local -A needed=()

    # python
    if git ls-files '*.py' | grep --quiet .; then
        needed[lint-python]=1
    fi

    # bash
    local bash_found=0
    while IFS= read -r f; do
        if [[ "$(file --brief --mime-type "$f")" == "text/x-shellscript" ]]; then
            bash_found=1
            break
        fi
    done < <(git ls-files | while IFS= read -r gf; do
        head --lines=1 "$gf" 2>/dev/null | grep --quiet '^#!.*bash' && echo "$gf"
    done)
    if [[ "$bash_found" -eq 1 ]]; then
        needed[lint-bash]=1
    fi

    # css
    if git ls-files '*.css' '*.scss' | grep --quiet .; then
        needed[lint-css]=1
    fi

    # html
    if git ls-files '*.html' | grep --quiet .; then
        needed[lint-html]=1
    fi

    # javascript
    if git ls-files '*.js' '*.mjs' '*.cjs' | grep --quiet .; then
        needed[lint-javascript]=1
    fi

    # json
    if git ls-files '*.json' | grep --quiet .; then
        needed[lint-json]=1
    fi

    # yaml
    if git ls-files '*.yml' '*.yaml' | grep --quiet .; then
        needed[lint-yaml]=1
    fi

    # vim
    if git ls-files '*.vim' 'vimrc' '*/vimrc' | grep --quiet .; then
        needed[lint-vim]=1
    fi

    # systemd
    if git ls-files '*.service' '*.timer' '*.socket' '*.path' '*.mount' '*.target' '*.slice' | grep --quiet .; then
        needed[lint-systemd]=1
    fi

    # markdown
    if git ls-files '*.md' | grep --quiet .; then
        needed[lint-markdown]=1
    fi

    # containerfile
    if git ls-files 'Containerfile' '**/Containerfile' | grep --quiet .; then
        needed[lint-containerfile]=1
    fi

    # ansible
    if [[ -d "roles" ]] || [[ -f "ansible.cfg" ]] || [[ -f "site.yml" ]] || [[ -f "site.yaml" ]] || git ls-files 'playbooks/*.yml' 'playbooks/*.yaml' | grep --quiet .; then
        needed[lint-ansible]=1
    fi

    while IFS= read -r image; do
        echo "$image"
    done < <(printf '%s\n' "${!needed[@]}" | sort)
}

detect_unsupported() {
    local -A unsupported=()

    while IFS= read -r f; do
        local base
        base="$(basename "$f")"

        # skip known supported filenames
        if [[ "$base" =~ ${SUPPORTED_NAMES_RE} ]]; then
            continue
        fi

        # skip known non-code filenames
        if [[ "$base" =~ ${SKIP_NAMES_RE} ]]; then
            continue
        fi

        # check extension
        local ext=""
        if [[ "$f" == *.* ]]; then
            ext="${f##*.}"
        fi

        # skip if extension is supported
        if [[ -n "$ext" ]] && [[ "$ext" =~ ${SUPPORTED_EXT_RE} ]]; then
            continue
        fi

        # skip known non-code extensions
        if [[ -n "$ext" ]] && [[ "$ext" =~ ${SKIP_EXT_RE} ]]; then
            continue
        fi

        # check mimetype
        local mime
        mime="$(file --brief --mime-type "$f" 2>/dev/null)" || continue

        # skip if mimetype is supported (e.g. extensionless shell scripts)
        if [[ "$mime" =~ ${SUPPORTED_MIME_RE} ]]; then
            continue
        fi

        # skip binary files
        if [[ "$mime" == application/octet-stream ]] || [[ "$mime" == inode/* ]] || [[ "$mime" == image/* ]]; then
            continue
        fi

        # check shebang for extensionless scripts
        if [[ -z "$ext" ]]; then
            local shebang
            shebang="$(head --lines=1 "$f" 2>/dev/null)" || continue
            if [[ "$shebang" =~ ^#!.*bash ]]; then
                continue
            fi
            # flag other interpreters we don't support
            if [[ "$shebang" =~ ^#! ]]; then
                local interp
                interp="${shebang##*[\\/]}"
                interp="${interp%% *}"
                unsupported["${base} (${interp})"]=1
                continue
            fi
        fi

        # report by extension or filename
        if [[ -n "$ext" ]]; then
            unsupported[".${ext}"]=1
        else
            unsupported["${base} (${mime})"]=1
        fi
    done < <(git ls-files)

    if [[ ${#unsupported[@]} -gt 0 ]]; then
        echo ""
        echo "Note: no linter available for these file types:"
        while IFS= read -r desc; do
            echo "  - ${desc}"
        done < <(printf '%s\n' "${!unsupported[@]}" | sort)
    fi
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

    if [[ -f "$hook_path" ]]; then
        local backup
        backup="${hook_path}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$hook_path" "$backup"
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

detect_unsupported

errors=0
passed=0

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
