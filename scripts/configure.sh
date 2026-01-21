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
fi

trap get_status ERR

# shellcheck source=scripts/_common.sh
source _common.sh
# shellcheck source=./scripts/_utils.sh
source _utils.sh

# NOTE: this env var is used by kind tool
export KIND_CLUSTER_NAME=in-cluster

export PATH="$PATH:${KREW_ROOT:-${_REMOTE_USER_HOME-$HOME}/.krew}/bin"

function _create_in_cluster {
    if ! sudo "$(command -v kind)" get clusters | grep -e "$KIND_CLUSTER_NAME"; then
        sudo -E kind create cluster
        mkdir -p "$HOME/.kube"
        sudo chown -R "$USER": "$HOME/.kube"
        sudo -E kind get kubeconfig | tee "$HOME/.kube/config"
        kubectl wait --for=condition=Ready --all pods -n kube-system
    fi

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    sleep 5
    kubectl wait --for=condition=Ready --all pods -n argocd --timeout 10m
}

function _deploy_in_cluster_apps {
    kubectl apply -f resources/in-cluster/

    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' -n argocd service/argocd-server
    argocd login $(kubectl get svc argocd-server -n argocd -o=jsonpath='{.status.loadBalancer.ingress[0].ip}') --insecure --username admin --password $(argocd admin initial-password -n argocd | head -n 1)

    for app in $(argocd app list -c "$(argocd cluster list | grep in-cluster | awk '{print $1}')" -o name); do
        argocd app sync "${app#*/}"
    done
}

function _create_infra {
    kubectl apply -f resources/overcloud/
    sleep 5m
    kubectl wait --for=condition=Complete job.batch/kubean-install-ops-job -n kubean-system --timeout 10m
    kubectl -n kubean-system get configmap infra-lab-kubeconf -o jsonpath='{.data.config}' >/tmp/kubeconfig.yml
    kubectl konfig import --save /tmp/kubeconfig.yml
    argocd cluster add "$(kubectl config current-context --kubeconfig /tmp/kubeconfig.yml)" -y --project infra-lab
}

function _deploy_infra_apps {
    local cluster=$(argocd cluster list | grep infra-lab | awk '{print $2}')

    # TopoLVM
    cert_manager_deployed="true"
    kubectl get deployments cert-manager -n cert-manager --context "$cluster" >/dev/null && cert_manager_deployed="false"
    argocd app set topolvm -p "cert-manager.enabled=$cert_manager_deployed"
    replica_count=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' --context "$cluster" | wc -l)
    argocd app set topolvm -p "controller.replicaCount=$replica_count"

    for app in $(argocd app list -c "$cluster" -o name); do
        argocd app sync "${app#*/}"
    done
}

function main {
    sudo docker compose up -d
    _create_in_cluster
    _deploy_in_cluster_apps

    _create_infra
    _deploy_infra_apps
}

if [[ ${__name__:-"__main__"} == "__main__" ]]; then
    main
fi
