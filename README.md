# rancher-terraform-framework

Reusable Rancher PaaS framework module for NWarila-hosted Kubernetes. A tenant
repository derives from `deploy-tenant-template`, keeps in-repo Helm chart
source plus one `terraform.tfvars`, and uses `all_workloads` to define one or
more workload releases that can pass the platform security baseline. This
repository is the framework module, not a deployment root: it will own the
Rancher tenant project, create a namespace per workload, deploy each local chart
with `helm_release`, and enforce a two-layer security model built from
tenant-repo render checks plus in-cluster Pod Security Admission Restricted and
Kyverno.

The Rancher-specific Terraform module, golden chart starter, policy manifests,
tenant template, and ephemeral-Rancher CI harness are being built in small,
reviewed steps from the scaffold now present in this repository.

## Quickstart

Run the local quality gate before changing framework sources:

```shell
make ci
```

The CI path runs Terraform formatting, init, validation, tests, TFLint, Helm
chart schema validation, terraform-docs drift detection, documentation layout
checks, and the repo's OPA policy target. Rancher-specific integration coverage
will be added through a disposable CI-managed Rancher environment rather than
long-lived external credentials.

## Documentation

- [Getting started](docs/how-to/develop-this-module.md)
- [Architecture](docs/explanation/architecture.md)
- [Threat model](docs/explanation/threat-model.md)
- [Quality gates](docs/reference/quality-gates.md)
- [Release gates](docs/reference/release-gates.md)
- [Architecture decisions](docs/decision-records/README.md)

## Current Architecture Decisions

- [ADR-repo/0001](docs/decision-records/repo/0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) adopts the Rancher envelope plus local in-repo Helm chart delivery model.
- [ADR-repo/0002](docs/decision-records/repo/0002-use-two-layer-tenant-security.md) defines the tenant-repo render gate plus authoritative in-cluster admission boundary.
- [ADR-repo/0003](docs/decision-records/repo/0003-define-tenant-repo-contract.md) defines the tenant repository contract and the three audited escape hatches.
- [ADR-repo/0004](docs/decision-records/repo/0004-use-vault-references-and-vault-secrets-operator.md) keeps secret values out of Terraform and Helm inputs.
- [ADR-repo/0005](docs/decision-records/repo/0005-validate-with-ephemeral-rancher-ci.md) commits validation to a disposable full Rancher CI environment.
- [ADR-repo/0006](docs/decision-records/repo/0006-use-all-workloads-tenant-contract.md) updates the tenant contract to `all_workloads` under one tenant project.
- [ADR-repo/0007](docs/decision-records/repo/0007-adopt-packer-limited-hcl-style.md) adopts the packer-limited HCL style for future Terraform implementation work.
