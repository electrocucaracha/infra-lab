---
layout: default
title: Configure the nodes
parent: How-to guides
nav_order: 1
---

# Configure The Nodes

Use this guide before provisioning a new lab
or when preparing a reviewed replacement topology.
It assumes you have read the [installation prerequisites](../tutorials/first-ci-platform.md#before-you-begin).

## 1. Select The Topology File

Edit `config/default.yml` for a shared baseline,
or copy it to the ignored local override:

```bash
cp config/default.yml config/pdf.yml
```

If the override already exists, inspect it instead of overwriting it.
The Vagrantfile always prefers `config/pdf.yml` when present.

## 2. Set Node Resources And Roles

For each node, set a unique name, an operating system listed in `distros_supported.yml`,
CPU and memory allocations, and a reachable private address.
The first entry in `networks` supplies the Kubean inventory address.
Use `kube_control_plane` and `etcd` for control-plane nodes,
and `kube_node` for workers.

The following is a worker entry, not a complete cluster topology:

```yaml
- name: compute01
  os:
    name: ubuntu
    release: jammy
  networks:
    - name: public-net
      ip: "10.10.16.6"
  memory: 32768
  cpus: 16
  volumes:
    - name: sdb
      size: 200
      volume_group: csi-vgs
      port: 1
      device: 0
  roles:
    - kube_node
```

Keep the installer address, `10.10.16.2`, separate from node addresses.
The installer address is defined in the Vagrantfile, not the topology file.

## 3. Align Worker Storage

Give each worker a dedicated disk assigned to `volume_group: csi-vgs`.
TopoLVM uses that group through its `lvmd.deviceClasses` values.
If you rename the group, update both the node topology
and `scripts/resources/in-cluster/topolvm.yaml` before provisioning.

Do not assign both `mount` and `volume_group` to the same disk.
Confirm device names inside the guest match the configured names.
Leave enough space for golden images, simultaneous runner clones, and free capacity.
TopoLVM storage is node-local; it is not replicated across workers.

## 4. Review And Provision

```bash
ruby -c Vagrantfile
git diff -- config/default.yml scripts/resources/in-cluster/topolvm.yaml
```

Review the ignored `config/pdf.yml` separately if you use it.
Then follow the node and installer stages in the [tutorial](../tutorials/first-ci-platform.md).

Changing a topology file does not reconcile existing machines through Argo CD.
For an existing cluster, plan node replacement and storage recovery explicitly.
Do not treat another bootstrap run as a nondestructive upgrade procedure.

For field definitions, see [Node topology](../references/configuration.md#node-topology).
