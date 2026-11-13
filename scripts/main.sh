#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset

cd "$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=scripts/_utils.sh
source ./_utils.sh

for step in ${PROVISION_PHASES:-install configure}; do
    case "$step" in
    install | configure) ;;
    *)
        printf 'Unknown provisioning phase: %s\n' "$step" >&2
        exit 1
        ;;
    esac
    info "Running $step process"
    bash "./$step.sh"
done
