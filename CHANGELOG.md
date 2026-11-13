<!-- Markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [6.7.1] - 2026-11-13

### Changed

- Simplified the project's bootstrap scripts and CI runner portability by enabling workflows to be invoked from varied directory layouts and supporting easier local and CI development. [77fd6a08](https://github.com/electrocucaracha/infra-lab/commit/77fd6a08772eadd8878c67bba294b44cfed90a2a)

## [6.7.0] - 2026-11-13

### Added

- Enabled automatic code review and ownership responsibilities by introducing a CODEOWNERS file that requests @electrocucaracha for reviews on all pull requests. [cc390088](https://github.com/electrocucaracha/infra-lab/commit/cc3900881aadea2aa93bfce76d24aaf41fbcb3bf)

## [6.6.9] - 2026-11-05

### Changed

- Enabled validation of both clean installs and rolling upgrades in the on-demand workflow, enhancing production rollout safety. [7a1e6060](https://github.com/electrocucaracha/infra-lab/commit/7a1e6060f1c8c4c5d689303e634df763c2906a35)

## [6.6.8] - 2026-11-05

### Changed

- Updated several dependencies to their latest versions, requiring users who rely on these dependencies to migrate to the new versions. [f3f11893](https://github.com/electrocucaracha/infra-lab/commit/f3f1189383a8b579fa7085f24c8e0b4ee559a050)

## [6.6.7] - 2026-11-06

### Changed

- Updated several dependencies to their latest versions, including GitHub Actions, pre-commit hooks, and the Tekton operator, with no breaking changes and no impact on observable behavior. [aca84491](https://github.com/electrocucaracha/infra-lab/commit/aca84491170fbf4f61c857cee477b507378c1b02)

## [6.6.6] - 2026-11-05

### Changed

- Modernized uv installation to use explicit path and updated environment, ensuring local availability and consistent test execution. [7ca2456b](https://github.com/electrocucaracha/infra-lab/commit/7ca2456b78eb9fcaa5ec5d18b98d110a89ffa96e)

## [6.6.5] - 2026-11-05

### Changed

- Simplified the UV installation process by eliminating custom installation logic and leveraging the default install path recommended by UV. [5c23d5b7](https://github.com/electrocucaracha/infra-lab/commit/5c23d5b761a5649b1f5628a4a3991cf363078b99)

## [6.6.4] - 2026-11-05

### Changed

- Strengthened CI tests for KUTTL and version updater with finer-grained assertions and explicit timeouts, while also modernizing the version updater to install `uv` in a dedicated user directory only when it's missing, and improving CI component validation to ensure KUBECONFIG values are absolute and validated. [835f4e33](https://github.com/electrocucaracha/infra-lab/commit/835f4e3387eed581fe022e9671f0683f17d60c13)

## [6.6.3] - 2026-11-04

### Changed

- Simplified smoke validation for components by replacing static manifests with KUTTL test cases, enabling consistent and automated testing across all components with updated dependency versions for ARC, KubeVirt, Topolvm, Argo CD, and kind. [a58d6e2e](https://github.com/electrocucaracha/infra-lab/commit/a58d6e2ec4342705535dcd055d2180b12fc0a2b5)

## [6.6.2] - 2026-11-04

### Changed

- Optimized version management by automating the update of pre-commit hooks and running the gh-updater tool, reducing manual overhead and improving setup for new environments. [17d34ab7](https://github.com/electrocucaracha/infra-lab/commit/17d34ab752a543f952aa41fb0b4c889edcbd533b)

## [6.6.1] - 2026-10-30

### Changed

- Improved release tag detection in update_versions.py now robustly handles nonstandard tags by retrying to find the latest valid release tag, and kustomization.yaml files have been introduced to simplify CI resource management for CDI and kubevirt-tekton-tasks. [59aa0908](https://github.com/electrocucaracha/infra-lab/commit/59aa09080abc67c1e7da1c61a48071e71ddb46e1)

## [6.6.0] - 2026-10-29

### Added

- Automated component updates and pull request validation are now enabled through GitHub Actions workflows that run weekly and on-demand respectively. [81e4a420](https://github.com/electrocucaracha/infra-lab/commit/81e4a4202ef8850568bc33108de173cccfedaa03)

## [6.5.6] - 2026-10-29

### Changed

- Updated the ai-prepare-commit-msg pre-commit hook to v20.10.5 to leverage the latest features and bug fixes, ensuring optimal commit message preparation without introducing any breaking behavior or migration requirements. [4bb78f86](https://github.com/electrocucaracha/infra-lab/commit/4bb78f865d71b1dcbebbe89feaaa803cad265b59)

## [6.5.5] - 2026-10-29

### Changed

- Modernized the platform's CI infrastructure to enable robust offline component validation and automated runtime pin updates. [7ab3cf7c](https://github.com/electrocucaracha/infra-lab/commit/7ab3cf7cdd7e0acca5568c191091350192cf800c)

## [6.5.4] - 2026-10-29

### Changed

- Simplified compute node configurations to use Ubuntu Jammy and a unified storage volume, removing settings for SR-IOV, QAT, NUMA, and pmem to align with new environment requirements. [1d0ef509](https://github.com/electrocucaracha/infra-lab/commit/1d0ef509e735c82a7f2a55773b34fd0dbb679dc9)

## [6.5.3] - 2026-10-29

### Changed

- Improved automation and consistency of the cluster provisioning workflow by enabling explicit application of and waiting for applications, introducing declarative ArgoCD Application manifests, and streamlining namespace creation and syncing checks. [48a11739](https://github.com/electrocucaracha/infra-lab/commit/48a11739824a5354a394ed26d6c26f59418fa2a4)

## [6.5.2] - 2026-10-29

### Fixed

- Hugepages are now disabled by default in environment configuration to ensure standard memory usage and more predictable deployments, unless explicitly overridden. [e6870fc2](https://github.com/electrocucaracha/infra-lab/commit/e6870fc2ae5515e7ef521c59ac33e23d612790f1)

## [6.5.1] - 2026-10-29

### Changed

- Modernized the documentation site to provide a structured entry point for new users and a comprehensive reference for contributors, including tutorials, guides, and reference sections for platform setup, GitOps integration, and operational concerns. [f589042d](https://github.com/electrocucaracha/infra-lab/commit/f589042d74aa8f90c031ab6751d8d38ea03ec2a6)

## [6.5.0] - 2026-10-28

### Added

- Enabled automated deployment of Tekton via ArgoCD in the infra-lab environment with self-healing and sync options to ensure consistent and streamlined deployment. [89aa5cb7](https://github.com/electrocucaracha/infra-lab/commit/89aa5cb7a05388de6c40bd44ba9edb6fcc6df41b)

## [6.4.0] - 2026-10-28

### Added

- Enabled managed cluster deployments of CDI under the cdi namespace through the introduction of an ArgoCD Application resource with automated synchronization and self-healing enabled. [69e5cfe5](https://github.com/electrocucaracha/infra-lab/commit/69e5cfe5e8a4ae37a955ec85912a203ccc25760a)

## [6.3.1] - 2026-10-28

### Changed

- Optimized the TopoLVM Helm chart configuration to improve scheduling and resilience by enabling automated self-healing, adjusting storage settings to use WaitForFirstConsumer and allow volume expansion, and updating the lvmd device class to use the 'csi-vgs' volume group with reduced spare space. [cbc7baf5](https://github.com/electrocucaracha/infra-lab/commit/cbc7baf567bf264fd24c950c84e6a48833b81360)

## [6.3.0] - 2026-10-28

### Added

- Enabled bridging on the pod network and configured automated sync with self-healing enabled through ArgoCD, improving deployment robustness and aligning with the desired cluster setup. [524b6e15](https://github.com/electrocucaracha/infra-lab/commit/524b6e15cd4f1540a247ee2e65a1856ac3855900)

## [6.2.1] - 2026-10-28

### Changed

- Normalized the volume group for the sdc disk to csi-vgs across all configurations to ensure consistency with storage naming conventions. [8a7e444b](https://github.com/electrocucaracha/infra-lab/commit/8a7e444bae641fd930e6e4c5ba4c4ca2fd4a33cb)

## [6.2.0] - 2026-10-28

### Added

- Enabled access to services running on port 80 in the VM from port 8080 on the host, replacing the previous forwarding of host port 9090 to guest port 9090. [a8d25df8](https://github.com/electrocucaracha/infra-lab/commit/a8d25df84bef29e9518ab80560497060ee322233)

## [6.1.0] - 2026-10-28

### Added

- Enabled explicit pruner activation, clarifying intent and improving transparency in configuration management without introducing breaking behavior or migration requirements. [7413ea57](https://github.com/electrocucaracha/infra-lab/commit/7413ea57e7ff8ff811bf0ee79cae2a4864925b85)

## [6.0.0] - 2026-10-27

### Removed

- Simplified the list of dependencies in bindep.txt by removing cockpit, tuned, ndctl, and ipmctl, which were no longer necessary for supported platforms, reducing unnecessary package checks during dependency installation and aligning with current platform support. [c0f7f027](https://github.com/electrocucaracha/infra-lab/commit/c0f7f02735d95c49d88f322c1078ffbca35c4233)

## [5.0.0] - 2026-10-27

### Removed

- Simplified the dependency installation process by eliminating the setup for the tuned service and its network-latency profile, as well as the loading of the rbd kernel module, which is no longer required. [9a99d7bf](https://github.com/electrocucaracha/infra-lab/commit/9a99d7bfbcb421a0a72acaa262caf05d0a0ae1aa)

## [4.1.1] - 2026-10-27

### Fixed

- Resolved dynamic cluster inventories for Ansible playbooks by accurately listing group hosts in the inventory generation script. [1837eefa](https://github.com/electrocucaracha/infra-lab/commit/1837eefa54522d04aeadd8f2114287e585ec9024)

## [4.1.0] - 2026-10-27

### Added

- Enabled consistent and maintainable setup of CI resources by introducing Kustomization YAML files that automate deployment of CDI, Tekton, and KubeVirt Tekton Tasks, streamlining updates and supporting reproducible CI infrastructure. [789b5fc6](https://github.com/electrocucaracha/infra-lab/commit/789b5fc6d868a9e123aa2ebf785d2245d8a46017)

## [4.0.0] - 2026-10-26

### Removed

- Simplified network configuration by eliminating redundant DNS server setup. [68e1e3ea](https://github.com/electrocucaracha/infra-lab/commit/68e1e3eafcfb114931eb10ecb2e84ee4a4cab1a4)

## [3.0.1] - 2026-10-26

### Changed

- Modernized the build process to utilize the latest stable Docker-in-Docker version and Go 1.26 language features for improved performance and support. [54c27cb4](https://github.com/electrocucaracha/infra-lab/commit/54c27cb4a4137ff2c039900ce43c06a58d08ccde)

## [3.0.0] - 2026-10-26

### Removed

- Simplified the CI bootstrap script by omitting vNVDIMMs and roles sections, reducing potential errors and streamlining VM configuration. [6d118ab2](https://github.com/electrocucaracha/infra-lab/commit/6d118ab2ed76f83294555b010b1bdf826723c7bb)

## [2.0.2] - 2026-10-26

### Fixed

- Resolved the issue of premature script termination due to deborphan installation failures, allowing dependency installation and cleanup to proceed even in environments with transient apt issues or missing repositories. [bad213d8](https://github.com/electrocucaracha/infra-lab/commit/bad213d801b0400b0711e4d8b18530cd5d7cbe6d)

## [2.0.1] - 2026-10-26

### Changed

- Simplified maintenance by focusing on a consistent provider, clarifying that only Ubuntu distributions are supported, with custom base boxes used for jammy, noble, and resolute releases, while removing support for non-Ubuntu distributions. [38d228d1](https://github.com/electrocucaracha/infra-lab/commit/38d228d1624cb1dbeb2c08e133bebbbe3c3d5a53)

## [2.0.0] - 2026-10-26

### Removed

- Simplified the Vagrantfile by removing outdated network configuration and QAT node setup provisioners and enabling unconditional customization of nested virtualization for VirtualBox and Libvirt, while also adding the UTM provider to improve compatibility on macOS. [f5605290](https://github.com/electrocucaracha/infra-lab/commit/f560529029fa05c6c519d9a6ade0aa86fd94e7c2)

## [1.2.0] - 2026-10-26

### Added

- Enabled consistent editor settings and code style validation across contributor contributions without affecting excluded directories. [eb46a84b](https://github.com/electrocucaracha/infra-lab/commit/eb46a84bc5bd1944c58d1090c4b9921cad7e6344)

## [1.1.0] - 2026-10-26

### Added

- Enabled automated quality checks and code formatting through the introduction of a pre-commit configuration file, enforcing consistent formatting and reducing manual review effort. [32370045](https://github.com/electrocucaracha/infra-lab/commit/32370045d50a7b3df30e9e8004456281db117aad)

## [1.0.0] - 2026-01-21

### Added

- Introduced support for self-hosted GitHub Actions runners through a provisioned Kubernetes cluster with integrated tooling for deployment and configuration management. [c8f39a37](https://github.com/electrocucaracha/infra-lab/commit/c8f39a37ef14d0205c4dc168dcbc6d90160880d5)
