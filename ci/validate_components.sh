#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export KUBECONFIG=${KUBECONFIG:-/tmp/kubeconfig.yml}
components=${INFRA_COMPONENTS:?Set INFRA_COMPONENTS to the components to validate}
ci_dir="$(cd "$(dirname "$0")" && pwd)"
INFRA_LAB_ROOT="$(dirname "$ci_dir")"
export INFRA_LAB_ROOT
kuttl_dir="$ci_dir/kuttl"
for component in $components; do
    case "$component" in
    topolvm | kubevirt | cdi | tekton | kubevirt-tekton-tasks | arc) ;;
    *)
        printf 'Unknown component: %s\n' "$component" >&2
        exit 1
        ;;
    esac
done

for component in $components; do
    printf 'Validating %s with KUTTL\n' "$component"
    (
        cd "$kuttl_dir"
        kubectl kuttl test --test-run-labels "component=$component"
    )
done
