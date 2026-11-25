#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
    export PKG_DEBUG=true
fi

export PKG_KREW_PLUGINS_LIST="konfig,virt"

curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 https://raw.githubusercontent.com/electrocucaracha/pkg-mgr_scripts/master/install.sh | PKG_COMMANDS_LIST="kind,kubectl,helm" PKG="docker unzip" bash

if ! command -v argocd; then
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -o argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
    sudo install -m 555 argocd /usr/local/bin/argocd
    rm argocd
fi
