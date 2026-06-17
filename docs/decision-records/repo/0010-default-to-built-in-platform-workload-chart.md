# ADR-repo/0010: Default to the Built-In Platform Workload Chart

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-17                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-17 Step 31 implementation review, ADR-repo/0003, ADR-repo/0006, ADR-repo/0009, Terraform root module, platform-workload chart. |
| Informed       | Platform operators, tenant repository maintainers, framework maintainers, policy authors, CI maintainers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-17                              |

## TL;DR

The built-in `charts/platform-workload` chart is the default workload chart.
When a workload omits `chart_path`, the Terraform root module resolves it to
the in-repository platform chart. Tenants can still use their own chart by
setting an explicit `chart_path`.

This restores the simple tenant path: a common workload can be described by
one `terraform.tfvars` file without an extra chart directory. The tenant-owned
chart model remains available for workloads that need chart-level Kubernetes
expressiveness.

## Context and Problem Statement

ADR-repo/0003 chose tenant-owned in-repository charts because the framework
must support any Kubernetes workload shape that can pass policy. ADR-repo/0006
then moved the tenant input contract to `all_workloads`, so one tfvars file can
describe one or more per-workload releases. ADR-repo/0009 split the platform
envelope path from the tenant deploy path while preserving the one tenant
repository experience.

The implementation drifted from the simple path. The root module defaulted an
omitted workload `chart_path` to `${path.root}/chart`. In this repository the
Terraform root is `terraform/`, so that default resolved to `terraform/chart`,
which is not committed. The real framework-owned starter chart is
`charts/platform-workload`. As a result, tenants could not omit `chart_path`
and use the built-in chart. The shipped tfvars example also taught tenants to
set platform-owned provider and envelope inputs and to bring `./chart`, which
undermined the "one tfvars, nothing else" common path.

The policy and admission posture does not require tenants to own a chart for
simple workloads. The platform chart is hardened by default and still renders
through the same Layer 1 and Layer 2 controls. Tenant-owned charts remain the
escape valve for unusual workload shapes.

## Decision Drivers

1. **Simple tenant surface.** The common path should need only one tenant
   tfvars file.
2. **Any-workload escape valve.** Tenants still need an explicit chart path for
   workloads that the built-in chart cannot express.
3. **No security loosening.** The committed chart must remain PSS Restricted
   and policy-gated by default.
4. **Truthful examples.** The example tfvars must teach tenant-owned workload
   values only, not platform credentials or envelope ownership.
5. **Framework portability.** The default chart path must resolve from the
   Terraform root without requiring a copied chart directory.

## Considered Options

1. Default omitted `chart_path` to the built-in `platform-workload` chart.
2. Keep requiring every tenant to provide an explicit chart path.
3. Copy the built-in chart into `terraform/chart`.
4. Loosen the built-in chart so more arbitrary public images run unchanged.

## Decision Outcome

Chosen option: **Option 1, default omitted `chart_path` to the built-in
`platform-workload` chart.**

The Terraform root module resolves omitted workload chart paths to
`../charts/platform-workload` relative to the Terraform root. An explicit
`all_workloads[*].chart_path` continues to override the default and supports
tenant-owned charts.

The committed `terraform/terraform.tfvars.example` is tenant workload input
only. It contains `all_workloads` and no platform provider credentials,
cluster IDs, project names, backend settings, kubeconfigs, or `chart_path`.
Those values are injected by the platform deploy runner out of band.

This decision amends ADR-repo/0003's "tenant repository always contains an
in-repo chart" clause. The current contract is: the built-in chart is the
default for simple workloads, and tenant-owned charts are supported by explicit
`chart_path` when needed.

## Pros and Cons of the Options

### Option 1: Default to the built-in chart

- **Good, because** common workloads can be deployed from one tfvars file.
- **Good, because** the existing hardened chart becomes the easy path instead
  of only a starter to copy.
- **Good, because** explicit `chart_path` keeps the any-workload model intact.
- **Good, because** no chart security controls need to be loosened.
- **Bad, because** documentation must distinguish default-chart workloads from
  tenant-owned-chart workloads.

### Option 2: Require explicit tenant chart paths

- **Good, because** it keeps ADR-repo/0003's original tenant-owned chart shape
  unchanged.
- **Bad, because** it forces an extra chart directory even for simple workloads.
- **Bad, because** it leaves the current nonexistent `terraform/chart` default
  broken.

### Option 3: Copy the built-in chart into `terraform/chart`

- **Good, because** it would make the old default path exist.
- **Bad, because** it duplicates chart source and creates drift between the
  framework chart and the Terraform default.
- **Bad, because** it hides the real chart location from tenants and reviewers.

### Option 4: Loosen the built-in chart

- **Good, because** more arbitrary public images would start without extra
  image-specific work.
- **Bad, because** it violates the owner directive to keep Step 30 loosening
  and proof-of-concept scaffolding out of committed source.
- **Bad, because** it weakens the hardened default path instead of making that
  path easier to consume.

## Confirmation

1. Omitting `all_workloads[*].chart_path` MUST use the built-in
   `charts/platform-workload` chart.
2. Setting `all_workloads[*].chart_path` MUST continue to deploy the explicit
   chart path supplied by the tenant or template.
3. The committed platform chart MUST stay hardened by default.
4. Tenant examples MUST NOT include platform-owned credentials, kubeconfigs,
   cluster IDs, project names, backend settings, or raw secrets.
5. Platform-owned provider, backend, identity, caps, and quota values MUST be
   injected by the deploy runner or platform workflow, not taught as tenant
   tfvars values.

## Consequences

### Positive

- The simplest tenant path is once again one tfvars file.
- The built-in chart is exercised as a real default, not only as starter
  source.
- The explicit chart path remains available for workloads that need additional
  Kubernetes objects or custom chart structure.

### Negative

- The framework must document when tenants should stay on the built-in chart
  and when they should bring their own chart.
- Registry policy can still reject otherwise hardened example images unless
  they are mirrored into an approved platform registry path.

### Neutral

- The two-layer policy and admission model remains unchanged.
- The module split from ADR-repo/0009 remains unchanged.
- The future tenant template still needs to define how platform values are
  injected around the tenant tfvars.

## Assumptions

1. The built-in chart remains appropriate for simple HTTP-style workloads.
2. Tenants that need arbitrary Kubernetes shapes can still maintain a chart and
   set `chart_path`.
3. The deploy runner will inject platform-owned variables out of band before
   production tenant use.

## Supersedes

- [ADR-repo/0003](0003-define-tenant-repo-contract.md) for the clauses
  that made a tenant-owned in-repo chart mandatory for every workload. Its
  constrained tfvars surface, three escape hatches, no-raw-secret posture, and
  tenant-owned chart support through explicit `chart_path` remain current.

## Superseded by

None (current).

## Implementing PRs

- The Step 31 pull request fixes the default chart path, rewrites the
  all-in-one tfvars example, and introduces this ADR.

## Related ADRs

- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the render and
  runtime controls that still enforce the workload boundary.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant
  contract amended by this ADR.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the
  `all_workloads` input shape preserved by the default chart path.
- [ADR-repo/0009](0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md)
  defines the platform envelope and tenant deploy module split.

## Compliance Notes

This ADR is design evidence for the tenant input surface. It does not replace
render-policy gates, admission tests, RBAC evidence, or the future runner
protocol that injects platform-owned variables around the tenant tfvars file.
