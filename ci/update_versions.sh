#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")/.."
for path in scripts/resources/ci/{tekton,cdi,kubevirt-tekton-tasks}/kustomization.yaml \
    scripts/resources/management/argocd/kustomization.yaml scripts/resources/management/kind.yaml; do
    [[ -f $path ]] || {
        printf 'Missing required managed version file: %s\n' "$path" >&2
        exit 1
    }
done
exec uv --quiet run --script ci/update_versions.py
