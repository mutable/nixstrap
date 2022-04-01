#! /usr/bin/env bash
set -eu
args=()


for arg in "$@"; do
    [[ $arg =~ -.* ]] || break
    args+=("$1")
    shift
done


if [ $# -ne 0 ]; then
    case "$1" in
    apply|console|destroy|import|plan|refresh)
        # build with nice progress UI
        nix build -f .. nixstrap.deploy --no-link
        # but nix(1) doesn't output paths
        path=$(nix-build .. -A nixstrap.deploy --no-out-link)
        args+=("$1" -var-file "$path")
        shift
    ;;
    esac
fi

terraform "${args[@]}" "$@"
