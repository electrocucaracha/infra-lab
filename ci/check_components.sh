#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")/.."
log=$(mktemp)
home=$(mktemp -d)
trap 'rm -f "$log"; rm -rf "$home"' EXIT

function source {
    case "$1" in
    _common.sh | _utils.sh) ;;
    *) builtin source "$@" ;;
    esac
}
function get_status { return 1; }
function kubectl {
    printf 'kubectl %s\n' "$*" >>"$log"
    [[ ${CHECK_SMOKE_MANIFESTS:-false} == true ]] || return 0
    case "$*" in
    *' apply -f '*)
        local manifest=${!#}
        [[ -f $manifest && ${MOCK_APPLY_FAILURE:-false} == false ]]
        ;;
    'get tasks.tekton.dev -n default -o name') printf 'task.tekton.dev/fixture\n' ;;
    '-n arc-system get deployments -o name') printf 'deployment.apps/fixture\n' ;;
    esac
}
function argocd { printf 'argocd %s\n' "$*" >>"$log"; }
function sudo { printf 'sudo %s\n' "$*" >>"$log"; }
function sleep { :; }

__name__=check source scripts/configure.sh
HOME=$home _create_in_cluster
grep -q 'kind create cluster --config resources/management/kind.yaml' "$log"
grep -q 'kubectl apply --server-side -n argocd -k resources/management/argocd' "$log"
if grep -q '/stable/\|/latest/' "$log"; then
    printf 'Management components must use pinned resource files\n' >&2
    exit 1
fi
for selection in tekton kubevirt cdi kubevirt-tekton-tasks arc default; do
    : >"$log"
    unset INFRA_COMPONENTS INFRA_REVISION
    [[ $selection == default ]] || export INFRA_COMPONENTS=$selection
    _deploy_infra_apps
    actual=$(awk '$1 == "argocd" && $3 == "sync" {print $4}' "$log" | paste -sd ' ' -)
    case "$selection" in
    cdi) expected="topolvm kubevirt cdi" ;;
    kubevirt-tekton-tasks) expected="topolvm kubevirt cdi tekton kubevirt-tekton-tasks" ;;
    default) expected="topolvm kubevirt cdi tekton kubevirt-tekton-tasks arc" ;;
    *) expected=$selection ;;
    esac
    [[ $actual == "$expected" ]] || {
        printf 'Expected [%s], got [%s]\n' "$expected" "$actual" >&2
        exit 1
    }
done

export INFRA_COMPONENTS="tekton kubevirt"
_deploy_infra_apps
export INFRA_COMPONENTS=unknown
if _deploy_infra_apps; then
    printf 'Unknown components must be rejected\n' >&2
    exit 1
fi
for selection in cdi tekton kubevirt-tekton-tasks; do
    : >"$log"
    export INFRA_COMPONENTS=$selection INFRA_REVISION=0123456789012345678901234567890123456789
    _deploy_infra_apps
    grep -q "targetRevision.*$INFRA_REVISION" "$log"
    if grep -q "apply -f resources/in-cluster/$selection.yaml" "$log"; then
        printf 'Unpinned Git source applied for %s\n' "$selection" >&2
        exit 1
    fi
done

repo=$PWD
export CHECK_SMOKE_MANIFESTS=true
export log
export -f kubectl
: >"$log"
pushd "$home" >/dev/null
INFRA_COMPONENTS='topolvm kubevirt cdi tekton kubevirt-tekton-tasks arc' bash "$repo/ci/validate_components.sh"
popd >/dev/null
for component in topolvm kubevirt cdi tekton; do
    grep -Fq -- "apply -f $repo/ci/resources/$component.yaml" "$log"
done
grep -q 'delete namespace infra-lab-ci --wait=false' "$log"
: >"$log"
if INFRA_COMPONENTS=tekton MOCK_APPLY_FAILURE=true bash ci/validate_components.sh; then
    printf 'Manifest application failures must fail validation\n' >&2
    exit 1
fi
grep -q 'delete namespace infra-lab-ci --wait=false' "$log"

printf 'Component selection, PR revision, and smoke manifest checks passed\n'
