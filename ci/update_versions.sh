#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

trap "make fmt" EXIT

for path in scripts/resources/ci/{tekton,cdi,kubevirt-tekton-tasks}/kustomization.yaml \
    scripts/resources/management/argocd/kustomization.yaml scripts/resources/management/kind.yaml; do
    [[ -f $path ]] || {
        printf 'Missing required managed version file: %s\n' "$path" >&2
        exit 1
    }
done

if [ ! command -v uv ] >/dev/null 2>&1; then
    curl -sSL https://install.astral.sh/uv | sh
fi
./ci/update_versions.py
uvx pre-commit autoupdate
uv run --no-project --with git+https://github.com/electrocucaracha/gh-updater.git gh-updater .