# Infra Lab

<!-- markdown-link-check-disable-next-line -->

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

<!-- markdown-link-check-disable-next-line -->

![visitors](https://visitor-badge.laobi.icu/badge?page_id=electrocucaracha.infra-lab)

## Overview

The **Infra-lab** project provides instructions and tooling
to deploy a Kubernetes cluster designed to support self-hosted
GitHub Actions runners.
The cluster is provisioned using **Kubean**,
a Kubespray-based Kubernetes lifecycle management operator,
ensuring a reliable and repeatable installation process.

Application deployment and configuration management use **Argo CD**,
enabling a GitOps-based workflow for continuous delivery
and cluster state management.
This approach provides consistency, traceability,
and automated synchronization between declared configurations
and the running cluster.
