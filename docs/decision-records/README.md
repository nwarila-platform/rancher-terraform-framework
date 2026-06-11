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
- `repo/` - repository-specific ADRs for this repository only. This scope is
  currently empty.

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

No repo-specific ADRs are recorded yet.
