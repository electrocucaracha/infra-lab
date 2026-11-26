#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
    export PKG_DEBUG=true
fi

export PKG_KREW_PLUGINS_LIST="konfig,virt"

apt_config=$(mktemp)
trap 'rm -f "$apt_config"' EXIT
cat >"$apt_config" <<'EOF'
Acquire::ForceIPv4 "true";
Acquire::Retries "5";
EOF

for attempt in 1 2 3; do
    if curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
        https://raw.githubusercontent.com/electrocucaracha/pkg-mgr_scripts/master/install.sh |
        APT_CONFIG="$apt_config" PKG_COMMANDS_LIST="kind,kubectl,helm" PKG="docker unzip" bash; then
        break
    fi
    if [[ $attempt == 3 ]]; then
        printf 'ERROR: Package installation failed after %s attempts\n' "$attempt" >&2
        exit 1
    fi
    printf 'WARN: Package installation attempt %s/3 failed; retrying in 10 seconds\n' "$attempt" >&2
    sleep 10
done

if ! command -v argocd; then
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -o argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
    sudo install -m 555 argocd /usr/local/bin/argocd
    rm argocd
fi
