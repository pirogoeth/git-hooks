#!/usr/bin/env zsh

set -eo pipefail

[ ! -d .git ] && {
    echo "Please run from the root of the git repo"
    exit 127
}

mkdir -p .git/hooks
for hook in "pre-commit"
do
    location="$(readlink -f git-hooks/hook-entrypoint.sh)"
    ln -s "${location}" ".git/hooks/${hook}"
    chmod +x ".git/hooks/${hook}"
done