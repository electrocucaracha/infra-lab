---
layout: default
title: First CI platform
parent: Tutorials
nav_order: 1
---

# Provision Your First CI Platform

In this tutorial, you provision worker and control-plane VMs,
create the management cluster,
and inspect the services that support VM-based CI.
You do not need a GitHub runner token.

## Before You Begin

- Use a Linux virtualization host with Vagrant and a configured libvirt provider.
  The Vagrantfile also contains VirtualBox settings;
  this walkthrough uses libvirt.
- Confirm nested hardware virtualization is available to the worker VMs.
  The runner workload can itself run VirtualBox inside KubeVirt VMs.
- Provide passwordless `sudo` inside the provisioned guests.
- Allow outbound access to GitHub, upstream chart and image registries,
  Ubuntu package repositories, and the Kubean image mirror.
- Reserve capacity for the topology and the management VM.
  The checked-in configuration requests 96 GiB of guest memory in total,
  plus host overhead, and two additional 200 GiB worker disks.
- Use a trusted private network with the example addresses available,
  or [configure your own nodes](../how-to-guides/configure-nodes.md).

> Node preparation formats configured mounted volumes and creates volume groups.
> Use disposable lab VMs and dedicated disks, never disks containing data you need.

## 1. Prepare Your Checkout

```bash
git clone https://github.com/electrocucaracha/infra-lab.git
cd infra-lab
git status --short
```

Review `config/default.yml` and check whether `config/pdf.yml` exists.
The local override takes precedence over the default topology.
Do not use `ci/bootstrap.sh` for this walkthrough:
it destroys named lab VMs and generates a legacy hardware-oriented override.

Publish your platform manifests before provisioning.
Argo CD reads committed content from Git, not your working directory.
For a fork or feature branch, update `repoURL` and `targetRevision`
in the parent application and the Git-backed child applications.
See the [configuration reference](../references/configuration.md#git-sources).

## 2. Provision The Workload Nodes

With the checked-in topology and no local override, run:

```bash
vagrant up controller01 controller02 controller03 compute01 compute02 --provider=libvirt
vagrant status
```

Vagrant prepares the nodes and generates the Kubean inventory.
At this point, Kubernetes is not installed yet.
If you changed the node names, use those names in the command instead.

## 3. Start The Installer

```bash
vagrant up installer --provider=libvirt
```

The installer VM runs `scripts/main.sh` from `/vagrant/scripts`.
It installs management tools and starts the Kind management cluster,
Argo CD, and Kubean.
Kubean then installs Kubernetes on the workload nodes.
Bootstrap registers that cluster in Argo CD as `infra-lab`
and synchronizes TopoLVM, KubeVirt, CDI, Tekton, KubeVirt tasks, and ARC in order.

Provisioning downloads images and packages and can take several minutes per stage.
Inspect progress from another terminal:

```bash
vagrant ssh installer -- 'tail -n 60 ~/vagrant_init.log'
```

## 4. Inspect The Platform

Run the following inside the installer:

```bash
vagrant ssh installer
kubectl --context kind-in-cluster get applications -n argocd
kubectl --kubeconfig /tmp/kubeconfig.yml get nodes
kubectl --kubeconfig /tmp/kubeconfig.yml get storageclass topolvm-provisioner
kubectl --kubeconfig /tmp/kubeconfig.yml get kubevirt -n kubevirt-system
kubectl --kubeconfig /tmp/kubeconfig.yml get cdi
kubectl --kubeconfig /tmp/kubeconfig.yml get tektonconfig
kubectl --kubeconfig /tmp/kubeconfig.yml get tasks -n default
kubectl --kubeconfig /tmp/kubeconfig.yml get deployments -n arc-system
```

The workload nodes should report `Ready`.
The storage class should be the default and use `WaitForFirstConsumer`.
KubeVirt and CDI should report availability,
and Tekton should report readiness.
The KubeVirt task list should include `modify-data-object`,
`create-vm-from-manifest`, and `wait-for-vmi-status`.

The administrative kubeconfig in `/tmp/kubeconfig.yml` is generated during bootstrap.
Keep it private; do not commit it or share it in diagnostic logs.

## What You Built

You now have a management cluster and a workload cluster
with the platform services for CI.
No runner scale sets, golden-image PipelineRuns,
or repository registrations are created.

Next, read [Connect runner workloads](../how-to-guides/connect-runner-workloads.md).
If a stage failed, use [Troubleshoot provisioning](../how-to-guides/troubleshooting.md).
