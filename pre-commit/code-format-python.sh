#!/usr/bin/env zsh

#
# code-format.sh
#
# Checks and formats all code with `black`
# Commit will be failed if changes are made.
#

[ ! -z "${HOOK_DEBUG}" ] && set -x
[ "$1" != "pre-commit" ] && exit 101

this_script="$(basename $(readlink -fn $0))"
hooks_dir="$(dirname $(readlink -fn $0))"
script_name="${this_script%.*}"

YQ_VERSION=v4.35.1

source "${hooks_dir}/../lib-log.sh"
source "${hooks_dir}/../lib-yq.sh"

hook_config=$(readlink -f "${hooks_dir}/../../.hook-config.yml")
declare -a black_args=()

log::debug "Looking for config at ${hook_config}"
if [ -f "${hook_config}" ]
then
    log::debug "Reading hook config from ${hook_config}"

    line_length="$(yq '.black.lineLength // ""' < ${hook_config})"
    if [ ! -z "${line_length}" ]
    then
        black_args+="--line-length=${line_length}"
    fi

    yq '.black.targetVersions[]' < ${hook_config} | while read target_version
    do
        black_args+="--target-version=${target_version}"
    done
fi

declare -a format_command=()
exitcode=0

changed_files="$(git diff --name-only HEAD | egrep '.*\.py' | paste -sd ' ')"
if [ -z "${changed_files}" ]
then
    log::debug "No files to format"
    exit 0
fi

log::debug "Prepared black args: ${black_args}"

declare -a input_files=( "${=changed_files[@]}" )
log::debug "Running on files: ${input_files[@]}"

if [ -z $commands[black] ]
then
    log::debug "Black not found, falling back to Poetry"

    if [ -z $commands[poetry] ]
    then
        log::debug "Poetry not found, falling back to Python3"

        if [ -z $commands[python3] ]
        then
            log::debug "Python3 not found, falling back to Python"

            if [ -z $commands[python] ]
            then
                log::error "Python not found, no fallbacks remaining"
                exit 127
            else
                format_command=( "python" "-m" "black" "--" )
            fi
        else
            format_command=( "python3" "-m" "black" "--" )
        fi
    else
        format_command=( "poetry" "run" "black" )
    fi
else
    format_command=( "black" )
fi

format_command+=("${black_args[@]}" "${input_files[@]}" )
"${format_command[@]}"
exitcode=$?

case "${exitcode}" in
    0)
        # Success!
        exit 0
        ;;
    1)
        # Black changed files, kill commit?
        exit 1
        ;;
    127)
        # Command not found
        log::error "Command not found: ${format_command}"
        exit 1
        ;;
    *)
        log::error "Unknown exit code ${exitcode} from command: ${format_command}"
        exit 1
        ;;
esac
