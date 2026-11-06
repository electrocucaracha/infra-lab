# GitHub Actions Workflows

These workflows propose component release updates and validate the proposed
resource pins.

| Workflow                       | Trigger                                   | Purpose                                                 |
| ------------------------------ | ----------------------------------------- | ------------------------------------------------------- |
| [update.yml](update.yml)       | Fridays at 00:00 UTC; manual dispatch     | Open a pull request with newer component release pins.  |
| [on-demand.yml](on-demand.yml) | Pull request opened, reopened, or updated | Run static checks and component-specific VM validation. |

## Scheduled Version Updates

The update workflow calls a commit-pinned reusable workflow from
`electrocucaracha/gh-workflows`. That workflow invokes
[ci/update_versions.sh](../../ci/update_versions.sh), which checks required
files and runs [ci/update_versions.py](../../ci/update_versions.py) through
`uv`. The Python script declares its Python version and dependencies inline.

The updater discovers stable Helm chart releases, GitHub release URLs in
Kustomizations, and the kind management-cluster node image. It changes resource
pins without downgrading existing versions. Version discovery happens here, not
in the validation jobs.

The caller grants the reusable job contents and pull-request write permissions.
Configure the `WORKFLOW_TOKEN` repository secret with permission to push update
branches and create pull requests. Use credentials whose pull requests can
trigger other workflows; pull requests created with the default `GITHUB_TOKEN`
do not normally trigger them. The updater reuses `uv` when available; otherwise,
it installs `uv` in `$HOME/.local/bin` and adds that directory to its `PATH`.
The update runner needs network access to the installer and upstream release
services. Concurrent scheduled update runs use the same
concurrency group without cancelling an active run.

## Pull Request Validation

The `plan` job runs on `ubuntu-latest` and performs:

- Shell syntax and ShellCheck validation.
- Python syntax validation.
- Mocked component-selection and KUTTL test-selection checks through
  [ci/check_components.sh](../../ci/check_components.sh).
- KUTTL smoke-resource, timeout, and ARC rollout regression tests through
  [tests/ci.rb](../../tests/ci.rb).
- Mocked updater checks for existing or missing `uv` and installation failures
  through [tests/ci.rb](../../tests/ci.rb).
- YAML parsing and release-pin validation through
  [ci/check_release_pins.rb](../../ci/check_release_pins.rb).
- Changed-file classification using a commit-pinned `dorny/paths-filter` action.

Component manifests and smoke resources select their corresponding validators:
`topolvm`, `kubevirt`, `cdi`, `tekton`, `kubevirt-tekton-tasks`, or `arc`.
Shared provisioning or management-resource changes select every validator.
Documentation-only changes still receive static checks but skip VM validation.

The `validate` job creates one matrix job per selected component. Each job
provisions a fresh nested AIO VM, runs the installer on the runner host, and
installs the selected component with its required dependencies. Git-backed
applications use the PR head commit rather than the default branch.
[ci/validate_components.sh](../../ci/validate_components.sh) runs the selected
KUTTL smoke tests. The job installs the pinned KUTTL CLI before provisioning.

Matrix jobs have a 90-minute timeout and `fail-fast: false`, so one failed
component does not cancel the others. Parallel execution requires separate
runner VMs; one runner processes matrix jobs sequentially.

## Self-Hosted Runner Requirements

- Register disposable Linux x64 runner VMs with the `vm-self-hosted` label.
- Provide Vagrant, VirtualBox, its kernel driver, and passwordless sudo.
- Expose Intel VMX or AMD SVM for nested virtualization.
- Run only one runner agent per VM because lab names and addresses are fixed.
- Provide enough disk for nested VM disks and management container images.
- Configure required reviewers on the `ci-validation` GitHub environment.

CI selects the VirtualBox provider and runs Vagrant with noninteractive sudo.
Host-installer mode uses host-only networking; the workflow allows
`10.10.16.0/24` in `/etc/vbox/networks.conf`. The installer supplies Docker and
management CLIs. All referenced installer and resource files must be present in
the checkout.

VM jobs accept same-repository PRs and wait for required reviewer approval on
the `ci-validation` environment before accessing the self-hosted runner. Fork
PRs receive only the GitHub-hosted static checks. Do not use
`pull_request_target` to execute untrusted PR code on these privileged runners.

See the
[runner integration guide](../../docs/how-to-guides/connect-runner-workloads.md#validate-platform-updates)
for the base-image definition and storage considerations.

## Failure Diagnostics And Cleanup

Before cleanup, failed jobs report AIO VM status, VirtualBox information and
logs, guest kubelet/containerd journals, kernel messages, and the node
provisioning log. Guest SSH diagnostics have a 90-second limit. Cluster
diagnostics include pod state, events, and Argo CD applications. These
best-effort commands write to the Actions logs.

The cleanup step uses `always()` and attempts to remove the AIO VM, management
kind cluster, Compose resources, and exported workload kubeconfig. Discard the
runner VM after every job, including cancelled jobs; cleanup cannot guarantee
completion if the runner stops or the job times out.

## Upgrade Scenario And Production Rollout

Each `validate` matrix entry runs two scenarios: `fresh` installs the PR head,
and `upgrade` installs the base commit, validates it, checks out the PR head and
reapplies the configure phase. No deploy workflow exists: the production
cluster's Argo CD applications track `HEAD` of the default branch, so merging a
validated PR is the rollout. Require the validation checks before merging.
