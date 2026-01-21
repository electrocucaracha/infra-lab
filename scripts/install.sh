#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2026
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
    export PKG_DEBUG=true
fi

export PKG_KREW_PLUGINS_LIST="konfig,virt"

# Install dependencies
# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="kind,kubectl,helm" PKG="docker" bash

if ! command -v argocd; then
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
    sudo install -m 555 argocd /usr/local/bin/argocd
    rm argocd
fi
