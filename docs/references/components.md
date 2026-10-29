---
layout: default
title: Platform components
parent: Reference
nav_order: 2
---

# Platform Components

All Argo CD Application objects reside in `argocd` on the management cluster.
Kubean targets that management cluster.
The CI services target the workload cluster registered as `infra-lab`.

## Applications And Version Pins

| Application             | Destination Namespace         | Declared Version   | Responsibility                                               |
| ----------------------- | ----------------------------- | ------------------ | ------------------------------------------------------------ |
| `ci-infrastructure`     | `argocd` on management        | Repository `HEAD`  | Parent application for the platform application declarations |
| `kubean`                | `kubean-system` on management | Chart `v0.32.1`    | Kubernetes installation and lifecycle operations             |
| `topolvm`               | `topolvm-system`              | Chart `15.9.0`     | Node-local LVM-backed persistent volumes                     |
| `kubevirt`              | `kubevirt-system`             | Chart `0.1.2`      | VM control plane and worker virtualization                   |
| `cdi`                   | `cdi`                         | Upstream `v1.66.1` | VM disk imports and clones                                   |
| `tekton`                | `tekton-operator`             | Operator `v0.81.2` | Tekton `lite` profile; Pipelines run in `tekton-pipelines`   |
| `kubevirt-tekton-tasks` | `default`                     | Upstream `v0.26.0` | Namespaced Tasks used by image-building pipelines            |
| `arc`                   | `arc-system`                  | Chart `0.10.1`     | GitHub Actions runner scale-set controller                   |

Chart versions are not necessarily component image versions.
Argo CD itself is bootstrapped from its upstream `stable` installation manifest,
and its CLI installation uses the upstream latest release.
Those bootstrap inputs are not pinned by the platform applications.

## Storage Contract

| Property            | Declared Value                            |
| ------------------- | ----------------------------------------- |
| Storage class       | `topolvm-provisioner`                     |
| Default class       | `true`                                    |
| Filesystem          | `ext4`                                    |
| Reclaim policy      | `Delete`                                  |
| Binding mode        | `WaitForFirstConsumer`                    |
| Volume expansion    | Enabled                                   |
| LVM device class    | `ssd`                                     |
| Volume group        | `csi-vgs`                                 |
| Reserved free space | `spare-gb: 1` per configured device class |

`Delete` applies to the provisioned backing storage when a claim is released.
Disabling Argo CD automatic pruning does not change this reclaim policy.

## Runner Compatibility Settings

The KubeVirt declaration enables `EnableVirtioFsConfigVolumes`
and `EnableVirtioFsStorageVolumes`.
The reference runner VM uses VirtioFS to receive its runtime configuration.
`permitBridgeInterfaceOnPodNetwork: true` supports its bridge interface.
Host-device passthrough is not enabled by the platform declaration.

## Bootstrap Readiness Gates

Bootstrap synchronizes Kubean before applying the workload cluster resources.
It then processes the workload applications in this order:
`topolvm`, `kubevirt`, `cdi`, `tekton`, `kubevirt-tekton-tasks`, `arc`.

Each application receives an Argo CD synchronization and health wait.
Additional waits check `Available` on KubeVirt and CDI,
and `Ready` on the TektonConfig before installing dependent Tasks.
The parent application is installed after that sequence completes.

## Excluded Workloads

The platform does not declare runner scale sets, GitHub tokens,
repository registrations, VM templates, image-building pipelines or PipelineRuns,
or garbage-collector jobs.
Tekton Triggers and Dashboard are not part of the `lite` profile.

See [Connect runner workloads](../how-to-guides/connect-runner-workloads.md)
for the integration boundary,
or [Architecture and ownership](../explanations/architecture.md)
for lifecycle context.
