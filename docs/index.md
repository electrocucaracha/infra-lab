---
layout: default
title: Home
nav_order: 1
---

# Infra Lab

Provision a Kubernetes platform for virtual machine (VM)-based GitHub Actions runners,
then reconcile its platform services through Git with Argo CD.
Infra Lab uses Kubean and Kubespray to install the workload cluster,
TopoLVM to provision runner disks,
and KubeVirt to run isolated VMs.

## What You Can Achieve

- Replace the infrastructure installation steps in
  [KRD's recreation script](https://github.com/electrocucaracha/krd/blob/master/recreate.sh)
  with declarative platform applications.
- Import and clone VM disks with Containerized Data Importer (CDI).
- Provide Tekton Pipelines and KubeVirt tasks for building runner images.
- Install the Actions Runner Controller (ARC) scale-set controller
  without embedding GitHub credentials or repository registrations in the platform.

The default platform excludes QAT, SR-IOV, persistent-memory preparation,
Ceph, and hugepages.
It does not register runners or execute image-building pipelines.
Those workloads belong in your separate values project.

## Find Your Starting Point

| Your Goal                                 | Start Here                                                            |
| ----------------------------------------- | --------------------------------------------------------------------- |
| Understand the platform boundary          | [Architecture and ownership](explanations/architecture.md)            |
| Provision your first CI platform          | [First CI platform](tutorials/first-ci-platform.md)                   |
| Set node capacity and storage             | [Configure the nodes](how-to-guides/configure-nodes.md)               |
| Connect a future values repository        | [Connect runner workloads](how-to-guides/connect-runner-workloads.md) |
| Diagnose a failed bootstrap               | [Troubleshoot provisioning](how-to-guides/troubleshooting.md)         |
| Look up files, settings, and applications | [Reference](references/index.md)                                      |

## Documentation Map

The documentation follows [Diataxis](https://diataxis.fr/):

- [Tutorials](tutorials/index.md) guide your first installation.
- [How-to guides](how-to-guides/index.md) help you complete specific tasks.
- [Reference](references/index.md) describes configuration and platform components.
- [Explanations](explanations/index.md) describe design decisions
  and lifecycle boundaries.

## Before You Provision

Use a trusted private lab with dedicated worker storage
and nested hardware virtualization.
The node preparation scripts format configured volumes
and create logical volume groups.
The example topology is not a capacity guarantee for your CI workload.

GitOps reconciliation covers the declared platform applications.
It does not automatically rebuild nodes,
rerun Kubean cluster operations,
or preserve runner disks when you destroy the underlying machines.
