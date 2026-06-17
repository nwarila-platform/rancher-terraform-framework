# rancher-terraform-framework

Reusable Rancher PaaS framework for NWarila-hosted Kubernetes. A tenant
repository derives from `deploy-tenant-template`, can use the built-in
`platform-workload` chart from one `terraform.tfvars` file or opt into a
tenant-owned chart with explicit `chart_path`, and uses `all_workloads` to
define one or more workload releases that can pass the platform security
baseline. This
repository is the framework source, not a deployment root: it will provide a
platform-run envelope module for the Rancher tenant project, per-workload
namespaces, quota, PSA labels, and restricted reconcile identity, plus a
tenant-consumed deploy module that runs `helm_release` only with the
platform-issued scoped credential. The security model is built from
tenant-repo render checks plus in-cluster Pod Security Admission Restricted,
Kyverno, and matching least-privilege RBAC.

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
- [ADR-repo/0008](docs/decision-records/repo/0008-retire-static-terraform-plan-opa.md) retires static OPA-on-plan for this Rancher framework.
- [ADR-repo/0009](docs/decision-records/repo/0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md) splits platform envelope from tenant deploy and scopes the reconcile identity.
- [ADR-repo/0010](docs/decision-records/repo/0010-default-to-built-in-platform-workload-chart.md) makes the built-in chart the default while preserving explicit tenant-owned chart paths.
