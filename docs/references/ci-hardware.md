---
layout: default
title: CI hardware
parent: Reference
nav_order: 3
---

# CI Hardware Requirements

This page lists the CPU, memory, and disk budgets used by the on-demand
validation workflow in `.github/workflows/on-demand.yml`.
Use it to check whether a runner can host the nested AIO VM and the KUTTL checks.

## Runner Host

The workflow runs on the `vm-self-hosted` label with a 90 minute job timeout.
The repository does not define the host's CPU, memory, or disk size.
The host must provide at least the nested AIO VM budget below plus host overhead.

## Nested AIO VM

The workflow provisions a single `aio` VM through `ci/bootstrap.sh`.
These values are the CI topology, not the default lab topology in `config/default.yml`.

| Resource          | Value                                      | Source            |
| ----------------- | ------------------------------------------ | ----------------- |
| Memory (request)  | 6144 MiB, overridable with `MEMORY`        | `ci/bootstrap.sh` |
| vCPUs             | 3, mapped to NUMA node 0 cpus `0-2`        | `ci/bootstrap.sh` |
| Docker disk       | 25 GiB, mounted at `/var/lib/docker/`      | `ci/bootstrap.sh` |
| LVM disk          | 50 GiB, volume group `csi-vgs` for TopoLVM | `ci/bootstrap.sh` |
| SR-IOV            | 6 virtual functions                        | `ci/bootstrap.sh` |
| Persistent memory | 6144 MiB, two slots, maximum 128 GiB       | `ci/bootstrap.sh` |

Keep these constraints when changing the values:

- The NUMA memory must equal the VM memory, and `MEMORY` sets both,
  so `MEMORY` changes the NUMA and persistent memory sizes too.
- The NUMA `cpus` range must match the `cpus` count.
  Changing `cpus` requires updating the NUMA range.
- The default CI VM is smaller than the lab defaults, so do not use
  `config/default.yml` values as a CI sizing reference.

## Test Workloads

The KUTTL checks create small workloads inside the AIO cluster.
Only memory and storage requests are declared; none of them declare CPU requests or limits.

| Component               | Workload                                      | Declared request | Limits |
| ----------------------- | --------------------------------------------- | ---------------- | ------ |
| `topolvm`               | `storage-smoke` PVC and Alpine pod            | 128 MiB storage  | None   |
| `cdi`                   | `import-smoke` blank DataVolume               | 128 MiB storage  | None   |
| `kubevirt`              | `vm-smoke` VirtualMachineInstance (CirrOS)    | 128 MiB memory   | None   |
| `tekton`                | `TaskRun` smoke test                          | None declared    | None   |
| `kubevirt-tekton-tasks` | Task definition assertion                     | None declared    | None   |
| `arc`                   | Actions Runner Controller Deployment rollouts | None declared    | None   |

The VMI memory request is only a scheduling hint. Its memory limit is not set, so it can use more than 128 MiB while it runs.

## Time Budgets

These KUTTL timeouts bound how long each check waits before failing.
Slow nested hardware usually shows up as one of these timeouts.

| Component               | Assertion timeout       | Argo CD wait | Readiness wait              |
| ----------------------- | ----------------------- | ------------ | --------------------------- |
| `topolvm`               | 300 s                   | 600 s        | None                        |
| `kubevirt`              | 600 s                   | 600 s        | KubeVirt `Available` 10 min |
| `cdi`                   | 600 s                   | 600 s        | CDI `Available` 10 min      |
| `tekton`                | 300 s                   | 600 s        | TektonConfig `Ready` 10 min |
| `kubevirt-tekton-tasks` | Not set (KUTTL default) | 600 s        | None                        |
| `arc`                   | 300 s                   | 600 s        | None                        |

The Argo CD and readiness waits are in `scripts/configure.sh`.
The KUTTL timeouts are in `ci/kuttl/tests/<component>/00-assert.yaml`.
The `arc` smoke test also waits up to 5 minutes per rollout in `ci/kuttl/tests/arc/00-smoke.yaml`.

## Troubleshooting Hardware Limits

When a check times out, the workflow prints diagnostics:

- Argo CD application status, events, and unhealthy/restarted pod details and
  current/previous container logs, from `scripts/configure.sh`.
- Non-running pods and recent events in the infrastructure cluster, from `scripts/configure.sh`.
- Cluster events, pods, PVCs, VMIs, and namespaces after a failing KUTTL component,
  from `ci/validate_components.sh`.

Look for `Insufficient memory`, `Insufficient cpu`, pending PVCs,
or `OutOfSync`/`Progressing` applications in those logs.
If they appear, increase the AIO VM memory with `MEMORY`
or raise the runner host's capacity before changing the test timeouts.
