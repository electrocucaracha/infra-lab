#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

resources="$(cd "$(dirname "$0")" && pwd)/resources"
export KUBECONFIG=${KUBECONFIG:-/tmp/kubeconfig.yml}
components=${INFRA_COMPONENTS:?Set INFRA_COMPONENTS to the components to validate}
for component in $components; do
    case "$component" in
    topolvm | kubevirt | cdi | tekton | kubevirt-tekton-tasks | arc) ;;
    *)
        printf 'Unknown component: %s\n' "$component" >&2
        exit 1
        ;;
    esac
done

kubectl create namespace infra-lab-ci
trap 'kubectl delete namespace infra-lab-ci --wait=false' EXIT
for component in $components; do
    printf 'Validating %s\n' "$component"
    case "$component" in
    topolvm)
        kubectl -n infra-lab-ci apply -f "$resources/$component.yaml"
        kubectl -n infra-lab-ci wait --for=jsonpath='{.status.phase}'=Bound pvc/storage-smoke --timeout=5m
        kubectl -n infra-lab-ci wait --for=jsonpath='{.status.phase}'=Succeeded pod/storage-smoke --timeout=5m
        ;;
    kubevirt)
        kubectl -n infra-lab-ci apply -f "$resources/$component.yaml"
        kubectl -n infra-lab-ci wait --for=condition=Ready vmi/vm-smoke --timeout=10m
        ;;
    cdi)
        kubectl -n infra-lab-ci apply -f "$resources/$component.yaml"
        kubectl -n infra-lab-ci wait --for=jsonpath='{.status.phase}'=Succeeded datavolume/import-smoke --timeout=10m
        ;;
    tekton)
        kubectl -n infra-lab-ci apply -f "$resources/$component.yaml"
        kubectl -n infra-lab-ci wait --for=condition=Succeeded taskrun/task-smoke --timeout=5m
        ;;
    kubevirt-tekton-tasks)
        kubectl get tasks.tekton.dev -n default -o name | grep -q .
        ;;
    arc)
        deployments=$(kubectl -n arc-system get deployments -o name)
        [[ -n $deployments ]]
        for deployment in $deployments; do
            kubectl -n arc-system rollout status "$deployment" --timeout=5m
        done
        ;;
    esac
done
