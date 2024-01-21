#!/usr/bin/env zsh

#
# dont-commit-secrets.sh
#
# Scans the git diff for secrets and fails the commit if any are found.
#

[ ! -z "${HOOK_DEBUG}" ] && set -x
[ "$1" != "pre-commit" ] && exit 101

this_script="$(basename $(readlink -fn $0))"
hooks_dir="$(dirname $(readlink -fn $0))"
script_name="${this_script%.*}"

YQ_VERSION=v4.35.1

source "${hooks_dir}/../lib-log.sh"
source "${hooks_dir}/../lib-yq.sh"

GITLEAKS_VERSION=v8.18.1

function gitleaks::download() {
    local bin_path="${GITLEAKS_STAGING_DIR}/${GITLEAKS_VERSION}"
    if [ -d "${bin_path}" ]
    then
        echo "${bin_path}/gitleaks"
        return 0
    fi

    mkdir -p "${bin_path}"

    local os=$(uname -s | tr '[A-Z]' '[a-z]')
    local arch=x64
    case "$(uname -m)" in
        x86_64)
            arch=x64
            ;;
        x86|i386)
            arch=x86
            ;;
        armv6*)
            arch=armv6
            ;;
        armv7*)
            arch=armv7
            ;;
        aarch64)
            arch=arm64
            ;;
    esac

    curl -sL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz" \
        | tar xz -C "${bin_path}"
    mv "${bin_path}/gitleaks_${os}_${arch}" "${bin_path}/gitleaks"
    chmod +x "${bin_path}/gitleaks"

    echo "${bin_path}/gitleaks"
}

function gitleaks() {
    local gitleaks_bin=${commands[gitleaks]}
    if test -z ${commands[gitleaks]} ; then
        gitleaks_bin=$(gitleaks::download)
    fi

    "${gitleaks_bin}" "$*"
}

detect_command=( "gitleaks" "protect" "--source" "${REPO_ROOT_DIR}" "--no-banner" )

exitcode=$?
case $exitcode in
    0)
        exit 0
        ;;
    1)
        log::debug "Secrets found"
        exit 1
        ;;
    *)
        log::error "gitleaks failed with exit code ${exitcode}"
        exit 1
        ;;
esac