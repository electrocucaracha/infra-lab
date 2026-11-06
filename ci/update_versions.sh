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

if ! command -v uv >/dev/null; then
    export UV_INSTALL_DIR="$HOME/.local/bin"
    curl -fsSL https://astral.sh/uv/install.sh | sh
    export PATH="$UV_INSTALL_DIR:$PATH"
fi
uv --quiet run --script ./ci/update_versions.py
uvx pre-commit autoupdate
uv run --no-project --with git+https://github.com/electrocucaracha/gh-updater.git gh-updater .
