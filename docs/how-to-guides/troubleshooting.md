---
layout: default
title: Troubleshoot provisioning
parent: How-to guides
nav_order: 3
---

# Troubleshoot Provisioning

Run these commands inside the installer VM after following the
[platform tutorial](../tutorials/first-ci-platform.md).
Use the management context for Argo CD and Kubean,
and the generated workload kubeconfig for CI platform services.

## Find The Failing Stage

```bash
tail -n 100 ~/vagrant_init.log
kubectl --context kind-in-cluster get applications -n argocd
kubectl --context kind-in-cluster get pods -A
```

Bootstrap synchronizes applications in dependency order.
A failure in TopoLVM can prevent later applications from being created.
Do not assume every application exists when investigating an interrupted bootstrap.

## Argo CD Cannot Find A Git Path Or Revision

```bash
kubectl --context kind-in-cluster describe application cdi -n argocd
kubectl --context kind-in-cluster describe application ci-infrastructure -n argocd
```

Inspect the source URL, revision, path, and reported conditions.
Confirm the manifests have been published to the branch Argo CD follows.
Local changes and ignored topology overrides are not visible through Git.
The parent `ci-infrastructure` application is created
only after the platform bootstrap completes.

## Kubean Does Not Complete The Cluster Installation

```bash
kubectl --context kind-in-cluster get clusteroperations
kubectl --context kind-in-cluster get jobs,pods -n kubean-system
kubectl --context kind-in-cluster logs -n kubean-system job/kubean-install-ops-job --all-containers=true
```

Check node reachability from the installer, guest SSH access,
inventory role membership, and registry access.
Do not publish inventory credentials or administrative kubeconfigs with the logs.
After correcting the cause, inspect the existing ClusterOperation and Job state
before choosing a recovery procedure.
Reapplying the same operation is not a guaranteed retry mechanism.

## Runner Disks Stay Pending

```bash
kubectl --kubeconfig /tmp/kubeconfig.yml get storageclass
kubectl --kubeconfig /tmp/kubeconfig.yml get pvc -A
kubectl --kubeconfig /tmp/kubeconfig.yml get pods -n topolvm-system
kubectl --kubeconfig /tmp/kubeconfig.yml get events -A --sort-by=.lastTimestamp
```

Confirm each eligible worker has the `csi-vgs` volume group and free space.
From the host, `vagrant ssh compute01 -- 'sudo vgs'`
inspects the default first worker.
Use your actual node name if you changed the topology.

`WaitForFirstConsumer` deliberately delays volume binding until a consuming workload
can be scheduled.
A Pending claim without a consumer is not by itself a storage failure.
CDI imports can also depend on their binding and scheduling configuration.

## KubeVirt Or Tekton Is Not Ready

```bash
kubectl --kubeconfig /tmp/kubeconfig.yml describe kubevirt kubevirt -n kubevirt-system
kubectl --kubeconfig /tmp/kubeconfig.yml describe cdi cdi
kubectl --kubeconfig /tmp/kubeconfig.yml describe tektonconfig config
kubectl --kubeconfig /tmp/kubeconfig.yml get pods -n kubevirt-system
kubectl --kubeconfig /tmp/kubeconfig.yml get pods -n cdi
kubectl --kubeconfig /tmp/kubeconfig.yml get pods -n tekton-pipelines
```

Check worker virtualization support and resource availability for KubeVirt.
For Tekton, inspect operator conditions
before applying dependent PipelineRuns or Tasks.
Infra Lab installs the `lite` profile;
missing Triggers or Dashboard components are expected.

## No Runners Appear In GitHub

An installed ARC controller does not register a runner by itself.
Confirm your separate values project has created the runner scale set,
credentials, VM templates, image volumes, and RBAC.
Follow [Connect runner workloads](connect-runner-workloads.md).
