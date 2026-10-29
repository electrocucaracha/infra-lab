---
layout: default
title: Connect runner workloads
parent: How-to guides
nav_order: 2
---

# Connect Runner Workloads From Another Repository

Use this guide after the [platform tutorial](../tutorials/first-ci-platform.md)
to connect the values project you create for runner workloads.
That project does not exist in this repository;
the paths below define an example integration contract rather than a shipped implementation.

## 1. Assign Workload Ownership

Keep platform controllers in Infra Lab.
Put the following in the values project:

- Runner scale-set Helm values and GitHub repository URLs.
- Credential references and an encrypted or out-of-band secret-delivery workflow.
- Runner namespaces, service accounts, and least-privilege role bindings.
- KubeVirt VM templates and CDI cloning permissions.
- Golden-image pipelines and their explicit PipelineRuns.
- Cleanup jobs for completed runners and unused images.

See [Architecture and ownership](../explanations/architecture.md#ownership-boundary)
for the complete boundary.

## 2. Prepare A Deployable Directory

Create a directory such as `clusters/ci` in your values repository
that Argo CD can render as Kubernetes manifests, a Kustomization, or a Helm chart.
A directory containing only Helm values files is not independently deployable.
To use values files, declare the matching chart through an Argo CD Application,
or use Argo CD's [multiple-source applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/).

Publish that directory before registering it with Argo CD.
Use a reviewed commit or tag for predictable rollout.
For a private repository, configure Argo CD repository credentials separately.

## 3. Register The Workloads Application

The following example assumes `clusters/ci` contains deployable resources.
Replace the repository URL and revision with your actual values:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ci-runner-workloads
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-OWNER/YOUR-VALUES-REPOSITORY.git
    targetRevision: YOUR-COMMIT-OR-TAG
    path: clusters/ci
  destination:
    name: infra-lab
    namespace: default
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

Apply the completed Application manifest to `argocd` in the management cluster,
using the `kind-in-cluster` context.
Keep it outside Infra Lab's platform application directory
so your workload rollout has an independent lifecycle.
For long-term GitOps management,
let a parent application in the values project own it.

## 4. Deliver Credentials And Build Images

Create or reconcile GitHub credentials into the runner namespaces
through your selected secret workflow.
Never commit a plaintext GitHub token in values or manifests.
The Infra Lab bootstrap does not consume `KRD_ARC_TOKEN`.

Install the pipeline definitions and required RBAC,
then run and verify the image-building PipelineRuns.
The KubeVirt tasks supplied by this platform are in the `default` namespace;
PipelineRuns that reference them as namespaced Tasks must resolve them there.
If you use another namespace, explicitly arrange task availability there.

Only enable runner scale sets after their golden images and VM templates are ready.
Grant CDI cloning permissions explicitly when a runner namespace clones an image
from another namespace.

## 5. Verify A Runner Registration

Confirm the values project's Argo CD application is synchronized,
its runner scale set is ready,
and a runner can execute a deliberately selected workflow in the target GitHub repository.
Platform readiness alone does not establish any of these conditions.

Use [Troubleshoot provisioning](troubleshooting.md) for platform failures
and keep workload-specific diagnostics with the values project.
