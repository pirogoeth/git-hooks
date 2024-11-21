#!/usr/bin/env zsh

this_script=$(readlink -fn $0)
script_mode=$(basename $0)
script_dir="$(dirname $this_script)"
repo_dir="$(dirname $script_dir)"
hook_scripts="${script_dir}/${script_mode}"

SHOW_ALL_HOOKS_OUTPUT="${SHOW_ALL_HOOKS_OUTPUT:-}"
HOOK_DEBUG="${HOOK_DEBUG:-}"
BASE_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/git-hooks"
DATA_DIR="${BASE_DATA_DIR}"
YQ_VERSION=v4.35.1
export REPO_ROOT_DIR="$(git rev-parse --show-toplevel)"
export LOG_FILE="${BASE_DATA_DIR}/log.txt"

mkdir -p "${BASE_DATA_DIR}"

source "${script_dir}/lib-log.sh"
source "${script_dir}/lib-yq.sh"

log::debug "Git hooks running in ${script_mode} mode"
log::debug "Running scripts from ${hook_scripts}"
log::debug "Base data dir: ${BASE_DATA_DIR}"

success_msg=$(echo -e "\033[48:5:83msuccess\033[0m")
failure_msg=$(echo -e "\033[48:5:160mfailure\033[0m")
error_msg=$(echo -e "\033[48:5:209merror\033[0m")

function configured_hooks() {
    hook_config="${repo_dir}/.hook-config.yml"
    [ ! -f "${hook_config}" ] && {
        log::info "No hook configuration file, running all hooks for ${script_mode}"
        return 99
    }

    hook_files=$(yq -r "(.gitHooks // {})[\"${script_mode}\"][]" < "${hook_config}")
    [ -z "${hook_files}" ] && {
        log::info "No hook files defined at .gitHooks[\"${script_mode}\"], not running any hooks"
        return 0
    }

    echo "${hook_files}" | while read hook_filename
    do
        [ -z "${hook_filename}" ] && continue
        hook_path="${hook_scripts}/${hook_filename}"
        log::debug "Checking for ${hook_filename} (${hook_path})"
        [ ! -f "${hook_path}" ] && {
            log::error "Hook ${hook_filename} configured to run, but doesn't exist"
            return 127
        }

        echo "${hook_path}"
    done
}

function all_hooks_for_mode() {
    ls ${hook_scripts}/*.sh 2>/dev/null
}

function get_hooks() {
    hooks="$(configured_hooks)"
    exitcode=$?
    case $exitcode in
        0)
            # Pass on the hooks and return
            echo "${hooks}"
            return 0
            ;;
        99)
            # Fall back to all hooks when no configuration
            echo "$(all_hooks_for_mode)"
            return 0
            ;;
        127)
            # Configured hook(s) does not exist
            return 1
            ;;
        *)
            log::error "Unknown hooks detection code: ${exitcode}"
            return 1
            ;;
    esac
}

hooks="$(get_hooks)"
[ "$?" -ne "0" ] && exit 1

echo "${hooks}" | while read script
do
    script_name="$(basename ${script})"
    printf "%-60s" "${script_name}"
    hook_outfile=$(mktemp /tmp/git-hook-${script_name%.*}.XXX)
    (
        cd "${repo_dir}" ; \
        [ ! -z "${HOOK_DEBUG}" ] && set -x \ 
        env \
            DATA_DIR="${BASE_DATA_DIR}/${script_name%.*}" \
            HOOK_DEBUG="${HOOK_DEBUG}" \
            "${script}" "${script_mode}" 2>&1 1>${hook_outfile}
    )
    ec=$?
    case "${ec}" in
        0)
            printf "%20s\n" "[${success_msg}]"
            if [ ! -z "$SHOW_ALL_HOOKS_OUTPUT" ]
            then
                printf -- '-%.0s' $(seq $(tput cols))
                echo
                while read line ; do echo "> ${line}" ; done < ${hook_outfile}
            fi
            ;;
        1)
            printf "%20s\n" "[${failure_msg}]"
            printf -- '-%.0s' $(seq $(tput cols))
            echo
            echo "hook ${script_name} failed. output:"
            echo
            while read line ; do echo "> ${line}" ; done < ${hook_outfile}
            exit 1
            ;;
        101)
            printf "%16s\n" "[${error_msg}]"
            printf -- '-%.0s' $(seq $(tput cols))
            echo
            echo "Hook ${script_name} doesn't support mode ${script_mode}"
            exit 1
            ;;
        *)
            printf "%16s\n" "[${error_msg}]"
            printf -- '-%.0s' $(seq $(tput cols))
            echo
            echo "Unknown exit code: ${ec}"
            exit 1
            ;;
    esac
done
