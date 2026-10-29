---
layout: default
title: Architecture and ownership
parent: Explanations
nav_order: 1
---

# Architecture And Ownership

Infra Lab separates the infrastructure needed for CI
from the runner workloads that use it.
Its starting point is the infrastructure portion of
[KRD's recreation script](https://github.com/electrocucaracha/krd/blob/master/recreate.sh),
not a declarative copy of that entire destructive recreation workflow.

## Management And Workload Clusters

The installer VM hosts a Kind management cluster named `in-cluster`.
Its kubeconfig context is `kind-in-cluster`.
Argo CD and Kubean run there,
outside the workload cluster whose lifecycle they manage.
The cloud-provider-kind service supplies load-balancer support
used to reach the Argo CD server during bootstrap.

Kubean runs Kubespray against the Vagrant-provisioned nodes.
The resulting workload cluster is registered in Argo CD as `infra-lab`.
It hosts TopoLVM, KubeVirt, CDI, Tekton, and the ARC controller.
The management and workload clusters have separate kubeconfigs and responsibilities.

## Bootstrap And Continuous Reconciliation

Some infrastructure must exist before GitOps can run.
Vagrant creates the VMs and prepares their disks,
and shell scripts create Kind, install Argo CD,
and submit the Kubean installation operation.
The bootstrap sequence explicitly waits for dependencies
before installing their consumers.

After bootstrap, the `ci-infrastructure` parent application watches
the platform Application manifests in Git.
Its children reconcile charts and pinned upstream bundles.
The workload platform applications enable automated synchronization and self-healing.
Manual changes to their managed resources can therefore be overwritten by reconciliation.

That reconciliation does not manage every lifecycle boundary.
The parent does not watch Vagrant topology files or the Kubean operation directory.
A commit changing node addresses does not create replacement VMs,
and applying an existing ClusterOperation does not guarantee a fresh Kubespray run.
The bootstrap's ordered waits are not a general upgrade orchestrator.

## Ownership Boundary

| Infra Lab Owns                                                 | The Future Values Project Owns                                  |
| -------------------------------------------------------------- | --------------------------------------------------------------- |
| Example node topology and guest preparation                    | CI capacity requirements and environment-specific choices       |
| Management cluster, Argo CD, and Kubean bootstrap              | Workload application declarations                               |
| Kubernetes runtime, networking, DNS, and cert-manager settings | GitHub repository registrations and credential references       |
| Storage, VM, pipeline, and runner controllers                  | Runner scale sets, namespaces, templates, and RBAC              |
| KubeVirt Tekton Task definitions                               | Golden-image pipelines, execution requests, and image promotion |
| Platform reconciliation policy                                 | Runner and image cleanup policy                                 |

This boundary keeps GitHub credentials and repository choices
out of the platform baseline.
It also allows runner workloads to change without forcing cluster reinstallation.
The values project remains a planned integration point,
not a project generated or deployed by Infra Lab.

## Storage And Recovery

TopoLVM allocates logical volumes from worker-local `csi-vgs` groups.
CDI uses persistent storage for image imports and cloning,
and KubeVirt attaches those disks to runner VMs.
Local storage ties recovery to the worker and its backing disk;
the platform does not provide replication or an image backup service.

Automatic pruning is disabled for the parent and workload applications.
Removing a declaration from Git is not intended to delete operator CRDs
or runner storage automatically.
This reduces one accidental-deletion path,
but it does not prevent explicit deletion, storage-class reclamation,
or data loss when the VMs and disks are destroyed.

## Lab Security Boundary

The Vagrant configuration uses lab SSH access
and the bootstrap uses administrative kubeconfigs.
The Argo CD login accepts the bootstrap server's self-signed certificate.
The cloud-provider-kind container accesses the host Docker socket.
These choices require a trusted host and private network;
they do not constitute a hardened production deployment.

Runner credentials should use a separate encrypted or out-of-band delivery mechanism.
Neither the platform repository nor the values repository
should contain plaintext tokens.

For installation steps,
use [First CI platform](../tutorials/first-ci-platform.md).
For exact declarations,
use [Platform components](../references/components.md).
