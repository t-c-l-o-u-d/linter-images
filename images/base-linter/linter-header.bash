#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
#
# Shared banner function for all linter/fixer images.
# Source this file and call header() at the top of each script.
#
# Requires:
#   - LINTER_IMAGE env var (set in each child Containerfile)
#   - figlet (installed in base-linter)

header() {
    local image="${LINTER_IMAGE:?LINTER_IMAGE not set}"
    local mode
    mode=$(basename "$0")
    local label
    case "$mode" in
        fix) label="Fixer" ;;
        *)   label="Linter" ;;
    esac
    local lang="${image#lint-}"

    local line1="${label}: ${lang}"
    local line2="ghcr.io/t-c-l-o-u-d/linter-images/${image}"
    local line3="https://github.com/t-c-l-o-u-d"

    local width=${#line1}
    (( ${#line2} > width )) && width=${#line2}
    (( ${#line3} > width )) && width=${#line3}

    local sep
    sep=$(printf '%*s' "$width" '' | tr ' ' '=')
    echo "$sep"
    echo "$line1"
    echo "$line2"
    echo "$sep"
    figlet "tcloud"
    echo "$line3"
    echo "$sep"
}
