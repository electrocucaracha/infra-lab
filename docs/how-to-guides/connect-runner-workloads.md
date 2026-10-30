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

## Validate Platform Updates

The repository's `Update Component Versions` workflow runs on Fridays at 00:00 UTC
and supports manual dispatch.
It uses the same pinned reusable maintenance workflow as `kubevirt-actions-runner`.
Set the repository secret `WORKFLOW_TOKEN` to a GitHub App token or a fine-grained
personal access token that can push update branches and create pull requests.
Unlike PRs created using `GITHUB_TOKEN`, these PRs can trigger validation workflows.
Enable Actions and allow the repository to call `electrocucaracha/gh-workflows`.

`ci/update_versions.sh` requires `uv` and network access.
It runs `ci/update_versions.py` using its inline Python 3.12+ requirement
and pinned dependencies; `uv` manages and caches the isolated environment.
It updates stable Helm chart versions from chart indexes and the ARC OCI registry,
discovers pinned GitHub release URLs in Kustomizations,
and updates the pinned kind management-cluster image.
This includes CDI, Tekton, KubeVirt Tekton tasks, and Argo CD.
It does not downgrade pins or change unversioned installer tool downloads.
Missing managed Kustomizations stop the update before it writes changes.

Register a dedicated, disposable Linux x64 runner with the `infra-lab` label.
Do not host it on the platform instance being validated.
The workflow targets the VirtualBox image built by
[KRD's Ubuntu runner pipeline](https://github.com/electrocucaracha/krd/blob/master/resources/ubuntu-runner-pipeline.yml).
That definition installs Vagrant and VirtualBox and grants the `runner` user passwordless sudo.
CI selects the VirtualBox provider and runs Vagrant through noninteractive sudo,
preserving the provider and host-installer settings and using the same privileges during cleanup.
Host-installer mode uses a host-only guest network rather than an internal-only network,
so the installer on the runner can reach the AIO VM.
CI allows the lab subnet `10.10.16.0/24` in `/etc/vbox/networks.conf`.
The runner must have `/dev/vboxdrv` and expose Intel VMX or AMD SVM CPU flags
to support nested VirtualBox and the KubeVirt guest.
The workflow checks these before provisioning; it does not require `/dev/kvm`
in the runner VM or a preinstalled Docker daemon.
Allow outbound access to GitHub and the configured chart and container registries.
The installer installs Docker and the management CLIs on the runner host.
The referenced template requests four vCPUs, 16G RAM, and a 35G root volume.
Increase the root volume or attach a work disk as needed for nested VM disks
and container images: the AIO guest alone declares 75 GiB of data-disk capacity
in addition to its root disk, although dynamically allocated VirtualBox disks grow with usage.
CI reports available disk space before provisioning.
The image-building definition does not register a runner or assign GitHub labels;
configure the `infra-lab` label when registering runners or configuring the scale set.
The runner must have no existing lab resources on `10.10.16.0/24`,
no kind cluster named `in-cluster`, and no unrelated Compose deployment
using this repository's project name.

Create the `ci-validation` GitHub environment and configure required reviewers
to approve code before it executes with host privileges.
The VM job accepts only same-repository PRs authored by an owner, member, or collaborator;
fork PRs still receive GitHub-hosted static checks.
Do not switch this workflow to `pull_request_target` to run fork code.
Only trusted maintainers should push branches to this repository.

Validation creates a fresh nested AIO VM, runs the installer on the host,
and deploys only the selected applications and their dependencies.
Tekton-only changes do not install virtualization or storage controllers.
CDI also installs TopoLVM and KubeVirt;
KubeVirt Tekton tasks also install TopoLVM, KubeVirt, CDI, and Tekton.
Shared provisioning changes select every validator, while documentation-only changes skip VMs.
The planning job uses the pinned `dorny/paths-filter` action to classify changed files.
Its component filters feed the matrix directly;
the shared-files filter expands the matrix to all platform components.
Static checks reject floating chart versions, release URLs, and kind node images.
Validation reads the pins checked out from the PR and never resolves newer upstream releases.
Only the scheduled updater performs release discovery.
Management-cluster pins are in `scripts/resources/management/kind.yaml`
and `scripts/resources/management/argocd/kustomization.yaml`;
changes to either select every validator.
Git-backed applications use the PR head commit rather than the default branch.
Scoped runs skip the full-stack bootstrap application so it cannot install unrelated apps.
Each changed component runs as a separate matrix job with its own nested AIO VM.
Jobs run in parallel when multiple isolated runner VMs are available;
a single runner processes them sequentially.
Run only one runner agent per host VM because the lab uses fixed VM names,
network addresses, and management-cluster names.
One failed component does not cancel the other matrix jobs.

Smoke checks cover TopoLVM volume binding and read/write,
KubeVirt VMI readiness, CDI blank-volume creation, Tekton TaskRun execution,
KubeVirt task availability, and ARC controller rollout.
The Kubernetes smoke manifests are in `ci/resources/<component>.yaml`;
`ci/validate_components.sh` applies them and waits for the corresponding checks.
Changes to a smoke manifest select that component's validator.
ARC registration and task-based golden-image builds still require the separate
workload configuration described above; these checks do not certify them.
Cleanup removes the AIO VM, management kind cluster, Compose resources, and exported kubeconfig.
Discard the runner VM after each job, including cancelled jobs, because teardown is best-effort.

Run the fast selection, revision, and smoke-manifest checks locally without provisioning infrastructure:

```bash
bash ci/check_components.sh
```
