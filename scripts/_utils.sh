#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
[[ ${DEBUG:-false} != "true" ]] || set -o xtrace

function debug {
    _print_msg "DEBUG" "$1"
    echo "::debug::$1"
}

function info {
    _print_msg "INFO" "$1"
    echo "::notice::$1"
}

function warn {
    _print_msg "WARN" "$1"
    echo "::warning::$1"
}

function error {
    _print_msg "ERROR" "$1"
    echo "::error::$1"
    exit 1
}

function _print_msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}
