#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export KUBECONFIG=${KUBECONFIG:-/tmp/kubeconfig.yml}
case "$KUBECONFIG" in
/*) ;;
*) export KUBECONFIG="$PWD/$KUBECONFIG" ;;
esac
components=${INFRA_COMPONENTS:?Set INFRA_COMPONENTS to the components to validate}
ci_dir="$(cd "$(dirname "$0")" && pwd)"
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
    if ! (
        cd "$kuttl_dir"
        kubectl kuttl test --test-run-labels "component=$component"
    ); then
        printf '::group::Cluster state after %s KUTTL failure\n' "$component" >&2
        kubectl get events -A --sort-by=.lastTimestamp | tail -n 60 || true
        kubectl get pods -A -o wide || true
        kubectl get pvc -A || true
        if ! kubectl get vmi -A -o wide; then
            echo "::notice::VMI diagnostics unavailable; KubeVirt may not be installed for this component"
        fi
        kubectl get namespaces || true
        printf '::endgroup::\n' >&2
        exit 1
    fi
done
