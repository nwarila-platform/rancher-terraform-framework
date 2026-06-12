# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) governing this
framework. Per [org ADR-0001](org/0001-use-architecture-decision-records.md),
ADRs are organized into three scopes:

- `org/` - byte-identical mirrors of org-baseline ADRs from
  [`nwarila-platform/.github`](https://github.com/nwarila-platform/.github).
  These apply to every repo in the namespace regardless of stack.
- `template/` - framework-template ADRs inherited from
  [`NWarila/terraform-framework-template`](https://github.com/NWarila/terraform-framework-template).
  Derivative frameworks mirror the `byte_identical` baseline entries through
  `baseline-manifest.json`.
- `repo/` - repository-specific ADRs for this repository only.

`rancher-terraform-framework` is a derivative framework consumer: it inherits
the canonical framework command surface, validation tooling, reusable deploy
workflow, and framework-tier decisions, while Rancher-specific Terraform
implementation decisions belong in `repo/`.

## Template ADRs

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-template/0001](template/0001-pin-terraform-and-provider-versions-exactly.md) | Accepted | Pin the Terraform CLI and every provider to exact versions. |
| [ADR-template/0002](template/0002-keep-reference-framework-credential-free.md) | Accepted | Keep this reference framework credential-free, cost-free, and synthetic. |
| [ADR-template/0004](template/0004-isolate-pull-request-target-triggers.md) | Accepted | Keep `pull_request_target` isolated to trusted-bot auto-merge, never release publishing. |
| [ADR-template/0005](template/0005-classify-org-control-plane-callers-as-scaffold.md) | Accepted | Classify org-control-plane caller files as scaffold starter files, not byte-identical files. |

ADR-template/0003 was withdrawn before release and is intentionally absent.

## Org ADRs

The `org/` scope is mirrored from `nwarila-platform/.github` and enforced by
the org drift gate.

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-0001](org/0001-use-architecture-decision-records.md) | Accepted | Use ADRs to document design rationale. |
| [ADR-0002](org/0002-adopt-diataxis-documentation-framework.md) | Accepted | Use Diataxis for non-ADR documentation. |
| [ADR-0003](org/0003-use-deny-all-gitignore-strategy.md) | Accepted | Use deny-all `.gitignore` allowlists. |
| [ADR-0004](org/0004-use-renovate-for-dependency-updates.md) | Accepted | Use Renovate for dependency updates. |
| [ADR-0005](org/0005-keep-github-control-planes-namespace-local.md) | Accepted | Keep GitHub control planes namespace-local. |

## Repo ADRs

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-repo/0001](repo/0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) | Accepted | Adopt the Rancher envelope plus `helm_release` of tenant-owned local charts. |
| [ADR-repo/0002](repo/0002-use-two-layer-tenant-security.md) | Accepted | Use tenant-repo render checks plus in-cluster PSA Restricted, Kyverno, and envelope RBAC as the tenant security boundary. |
| [ADR-repo/0003](repo/0003-define-tenant-repo-contract.md) | Accepted | Define the tenant deliverable as an in-repo chart plus one tfvars file derived from `deploy-tenant-template`. |
| [ADR-repo/0004](repo/0004-use-vault-references-and-vault-secrets-operator.md) | Accepted | Accept Vault references only and materialize secrets with Vault Secrets Operator. |
| [ADR-repo/0005](repo/0005-validate-with-ephemeral-rancher-ci.md) | Accepted | Validate the mechanism against a disposable full Rancher CI environment. |
| [ADR-repo/0006](repo/0006-use-all-workloads-tenant-contract.md) | Accepted | Use `all_workloads` so one tenant tfvars can define multiple per-workload namespaces and releases under one tenant project. |
| [ADR-repo/0007](repo/0007-adopt-packer-limited-hcl-style.md) | Accepted | Adopt the packer-limited HCL source style for future Terraform implementation work. |
