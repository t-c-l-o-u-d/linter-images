#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)

# scan.bash -- sourced by lint.bash and fix.bash
# Detects which linter images are needed based on workspace file types.

REGISTRY="ghcr.io/t-c-l-o-u-d/linter-images"

# detect if running inside a container
RUNNING_IN_CONTAINER=0
if [[ -f /.containerenv ]] || [[ -f /run/.containerenv ]]; then
    RUNNING_IN_CONTAINER=1
fi

validate_runtime() {
    if ! podman --version > /dev/null 2>&1; then
        echo "ERROR: podman is not available."
        echo "The orchestrator requires a container runtime."
        exit 1
    fi

    if [[ "${RUNNING_IN_CONTAINER}" -eq 1 ]]; then
        if [[ ! -S /run/podman/podman.sock ]]; then
            echo "ERROR: Container runtime socket not found."
            echo "Mount the host's podman socket:"
            echo "  --volume /run/podman/podman.sock:/run/podman/podman.sock"
            exit 1
        fi

        if [[ -z "${WORKSPACE_HOST_PATH:-}" ]]; then
            echo "WARNING: WORKSPACE_HOST_PATH is not set."
            echo "Child containers may not see the workspace correctly."
            echo "Set it with: --env WORKSPACE_HOST_PATH=\"\$(pwd)\""
        fi

        export CONTAINER_HOST="unix:///run/podman/podman.sock"
    fi
}

detect_images() {
    # Prints a newline-separated list of image names to stdout.
    # Uses git ls-files for discovery (workspace must be a git repo).

    local -A needed=()

    # python: *.py
    if git ls-files '*.py' | grep --quiet .; then
        needed[lint-python]=1
    fi

    # bash: shebang detection, filtered by mimetype to exclude non-scripts
    local bash_found=0
    while IFS= read -r f; do
        if [[ "$(file --brief --mime-type "$f")" == "text/x-shellscript" ]]; then
            bash_found=1
            break
        fi
    done < <(grep --recursive --files-with-matches --exclude-dir=.git '^#!.*bash' . 2>/dev/null)
    if [[ "${bash_found}" -eq 1 ]]; then
        needed[lint-bash]=1
    fi

    # css: *.css, *.scss
    if git ls-files '*.css' '*.scss' | grep --quiet .; then
        needed[lint-css]=1
    fi

    # html: *.html
    if git ls-files '*.html' | grep --quiet .; then
        needed[lint-html]=1
    fi

    # javascript: *.js, *.mjs, *.cjs
    if git ls-files '*.js' '*.mjs' '*.cjs' | grep --quiet .; then
        needed[lint-javascript]=1
    fi

    # json: *.json
    if git ls-files '*.json' | grep --quiet .; then
        needed[lint-json]=1
    fi

    # yaml: *.yml, *.yaml
    if git ls-files '*.yml' '*.yaml' | grep --quiet .; then
        needed[lint-yaml]=1
    fi

    # vim: *.vim, vimrc
    if git ls-files '*.vim' 'vimrc' '*/vimrc' | grep --quiet .; then
        needed[lint-vim]=1
    fi

    # systemd: unit files
    if git ls-files '*.service' '*.timer' '*.socket' '*.path' '*.mount' '*.target' '*.slice' | grep --quiet .; then
        needed[lint-systemd]=1
    fi

    # markdown: *.md
    if git ls-files '*.md' | grep --quiet .; then
        needed[lint-markdown]=1
    fi

    # containerfile: Containerfile (not Dockerfile)
    if git ls-files 'Containerfile' '**/Containerfile' | grep --quiet .; then
        needed[lint-containerfile]=1
    fi

    # ansible: structural heuristics
    if [[ -d "roles" ]] || [[ -f "ansible.cfg" ]] || [[ -f "site.yml" ]] || [[ -f "site.yaml" ]] || git ls-files 'playbooks/*.yml' 'playbooks/*.yaml' | grep --quiet .; then
        needed[lint-ansible]=1
    fi

    # print detected images, sorted for deterministic ordering
    for image in $(printf '%s\n' "${!needed[@]}" | sort); do
        echo "${image}"
    done
}

run_container() {
    # arguments: $1 = image name, $2 = command (e.g. /usr/local/bin/lint)
    local image_name="$1"
    local command="$2"
    local full_image="${REGISTRY}/${image_name}:latest"
    local host_path="${WORKSPACE_HOST_PATH:-/workspace}"

    echo ""
    echo "-------------------------------------------"
    echo "  ${image_name} :: ${command##*/}"
    echo "-------------------------------------------"

    if ! podman pull --quiet "${full_image}" > /dev/null 2>&1; then
        echo "ERROR: Failed to pull ${full_image}"
        return 1
    fi

    if ! podman run \
        --rm \
        --volume "${host_path}":/workspace \
        --workdir /workspace \
        "${full_image}" \
        "${command}"; then
        return 1
    fi

    return 0
}
