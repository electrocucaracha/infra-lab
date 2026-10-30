---
layout: default
title: Configuration
parent: Reference
nav_order: 1
---

# Configuration Reference

Paths in this reference are relative to the repository root.

## Node Topology

The Vagrantfile loads `config/default.yml`
unless `config/pdf.yml` exists, in which case the local override replaces it.
Both files contain a YAML sequence of node objects.
The override is ignored by Git.

| Field                                | Description                                                              |
| ------------------------------------ | ------------------------------------------------------------------------ |
| `name`                               | Vagrant machine name and inventory hostname                              |
| `os.name`                            | Operating system key in `distros_supported.yml`                          |
| `os.release`                         | Release key under the selected operating system                          |
| `networks[].name`                    | Provider network name                                                    |
| `networks[].ip`                      | Guest private address; the first address is used in the Kubean inventory |
| `memory`                             | Guest memory allocation in MiB                                           |
| `cpus`                               | Guest virtual CPU count                                                  |
| `roles[]`                            | Inventory memberships: `kube_control_plane`, `kube_node`, or `etcd`      |
| `volumes[].name`                     | Guest disk device name, without `/dev/`                                  |
| `volumes[].size`                     | Additional disk size in GiB                                              |
| `volumes[].mount`                    | Mount point for a disk that node preparation partitions and formats      |
| `volumes[].volume_group`             | LVM volume group created from the dedicated disk                         |
| `volumes[].port`, `volumes[].device` | VirtualBox storage attachment coordinates                                |

`mount` and `volume_group` are mutually exclusive on a volume.
The default topology assigns `csi-vgs` to each worker's additional disk.

| Default Machine | Address      | Memory    | CPUs | Roles                                                |
| --------------- | ------------ | --------- | ---- | ---------------------------------------------------- |
| `controller01`  | `10.10.16.3` | 8192 MiB  | 2    | Control plane, etcd                                  |
| `controller02`  | `10.10.16.4` | 8192 MiB  | 2    | Control plane, etcd                                  |
| `controller03`  | `10.10.16.5` | 8192 MiB  | 2    | Control plane, etcd                                  |
| `compute01`     | `10.10.16.6` | 32768 MiB | 16   | Worker                                               |
| `compute02`     | `10.10.16.7` | 32768 MiB | 4    | Worker                                               |
| `installer`     | `10.10.16.2` | 8192 MiB  | 4    | Management VM, defined separately in the Vagrantfile |

Each default worker has one additional 200 GiB disk.
All default workload nodes use Ubuntu Jammy.
The installer does not autostart with an untargeted `vagrant up`.

## Environment Settings

| Setting                   | Default                                                         | Scope                                                               |
| ------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| `DEBUG` in `defaults.env` | `ACTIONS_RUNNER_DEBUG`, then `ACTIONS_STEP_DEBUG`, then `false` | Node preparation shell tracing                                      |
| `HUGEPAGES_ENABLED`       | `false`                                                         | Hugepage preparation in `node.sh`                                   |
| `PROVISION_PHASES`        | `install configure`                                             | Ordered phases executed by `scripts/main.sh`                        |
| `VAGRANT_NFS_VERSION`     | `3`                                                             | libvirt shared-folder NFS version                                   |
| `HOST_INSTALLER`          | `false`                                                         | Run the installer on the host instead of an installer VM            |
| `INFRA_COMPONENTS`        | All platform applications                                       | Space-separated application selection; adds required dependencies   |
| `INFRA_REVISION`          | Application manifest revision                                   | Git revision for CDI, Tekton, and KubeVirt Tekton task applications |

The Vagrantfile separately defaults its guest `DEBUG` setting to `true`
when the host does not supply `DEBUG`.
`scripts/main.sh` enables its own shell tracing unconditionally.
These tracing settings are not a single global logging switch.
`KRD_ARC_TOKEN` is not an input to platform bootstrap.

## Git Sources

| Declaration                                               | Git Path Watched                             |
| --------------------------------------------------------- | -------------------------------------------- |
| `scripts/resources/bootstrap.yaml`                        | `scripts/resources/in-cluster`               |
| `scripts/resources/in-cluster/cdi.yaml`                   | `scripts/resources/ci/cdi`                   |
| `scripts/resources/in-cluster/tekton.yaml`                | `scripts/resources/ci/tekton`                |
| `scripts/resources/in-cluster/kubevirt-tekton-tasks.yaml` | `scripts/resources/ci/kubevirt-tekton-tasks` |

These sources use `https://github.com/electrocucaracha/infra-lab.git`
and `targetRevision: HEAD`.
`HEAD` follows the repository's default branch.
The Helm-backed applications instead select chart versions;
the Kustomizations select pinned upstream release URLs.
CI sets `INFRA_REVISION` to the PR head commit before applying Git-backed applications.
See [Validate platform updates](../how-to-guides/connect-runner-workloads.md#validate-platform-updates)
for scheduled updates and self-hosted runner requirements.

## Runtime Release Pins

Helm-backed applications pin chart releases in `spec.source.targetRevision`.
The component Kustomizations pin upstream release URLs.
`scripts/resources/management/kind.yaml` pins the management-cluster node image,
and `scripts/resources/management/argocd/kustomization.yaml` pins the Argo CD server release.
The management CLI installers are separate from these runtime pins.

`ci/update_versions.sh` discovers newer stable releases and changes the resource pins.
PR validation checks those pins offline, then deploys the checked-out versions;
it does not query upstream services to choose versions.
Git-backed Application revisions identify repository commits, not component releases,
so `INFRA_REVISION` still selects the PR's Kustomizations during validation.

## Kubernetes Settings

`scripts/resources/overcloud/config.yaml` contains the Kubean Cluster,
ClusterOperation, and Kubespray variable ConfigMap.
The declared runtime is containerd.
Networking uses Flannel with `host-gw`, IPVS kube-proxy,
and node-local DNS.
The configuration enables cert-manager and disables the local-volume provisioner.
TopoLVM does not install a second cert-manager instance.

## Entry Points And Generated Files

| Path Or Object                                  | Purpose                                                                         |
| ----------------------------------------------- | ------------------------------------------------------------------------------- |
| `Vagrantfile`                                   | VM definitions, guest preparation, and inventory generation                     |
| `node.sh`                                       | Guest packages, swap, kernel settings, configured mounts, and LVM groups        |
| `scripts/main.sh`                               | Installer phase dispatcher; runs from `scripts`                                 |
| `scripts/install.sh`                            | Management CLI and Docker installation                                          |
| `scripts/configure.sh`                          | Management bootstrap, Kubean operation, and ordered application synchronization |
| `scripts/resources/overcloud/hosts.yaml`        | Inventory ConfigMap rewritten when the Vagrantfile is evaluated                 |
| `insecure_keys/key` and `insecure_keys/key.pub` | Generated lab SSH key pair, ignored by Git                                      |
| `infra-lab-kubeconf` in `kubean-system`         | ConfigMap holding the generated workload kubeconfig                             |
| `/tmp/kubeconfig.yml` on the installer          | Administrative workload kubeconfig exported during bootstrap                    |
| `~/node.log` on each node                       | Guest preparation output                                                        |
| `~/vagrant_init.log` on the installer           | Installer provisioning output                                                   |

For procedures, see [Configure the nodes](../how-to-guides/configure-nodes.md)
and [Troubleshoot provisioning](../how-to-guides/troubleshooting.md).
