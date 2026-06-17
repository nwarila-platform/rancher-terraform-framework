# ADR-repo/0003: Define the Tenant Repository Contract

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-11 owner interview, Rancher provider documentation, Helm provider documentation, Kubernetes Pod Security Standards. |
| Informed       | Tenant maintainers, framework maintainers, documentation authors, policy authors. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-11                              |

## TL;DR

The tenant deliverable is a repository, not a single variable file by itself.
That repository derives from `deploy-tenant-template`, contains the tenant's
in-repo Helm `chart/`, and supplies exactly one `terraform.tfvars` file for the
framework-controlled envelope and allowed values. This retires the earlier
single-tfvars-only product promise because a fixed platform-owned chart cannot
honestly cover any Kubernetes workload without becoming an unbounded schema.

The module exposes only envelope knobs and constrained workload knobs:
ingress, replicas and HPA within platform caps, CPU and memory requests and
limits within platform caps, Vault secret references, optional persistent
storage from an allowlist, and chart values that do not contain raw secret
values. The only tenant escape hatches are API access through a dedicated
service account token mount, low-port binding through `NET_BIND_SERVICE`, and a
structured persistent-storage block.

## Context and Problem Statement

The framework originally aimed to let a tenant provide only one
`terraform.tfvars` file. That is achievable when the platform owns the whole
chart and exposes a finite set of workload shapes. It is not compatible with the
later owner requirement that the framework cover any client workload expressible
in Kubernetes.

Helm charts contain the resource definitions needed to run an application in
Kubernetes, and the Helm provider supports a local chart path for `helm_release`
(https://raw.githubusercontent.com/hashicorp/terraform-provider-helm/main/docs/resources/release.md).
Giving the tenant ownership of that chart is the tractable way to express
arbitrary Kubernetes workload structure while still keeping the platform's
security boundary outside the chart.

The platform can still make the common path easy by shipping a golden chart
starter. A tenant can copy it, adjust values, or replace it completely. The
security boundary is not "the tenant used our chart"; the security boundary is
the combination of tenant-repo render checks, PSA Restricted, Kyverno policy,
Rancher quota, and reconcile RBAC described by ADR-repo/0002.

Kubernetes Pod Security Standards Restricted already permits only
`NET_BIND_SERVICE` as a capability add-back when containers drop `ALL`
capabilities
(https://kubernetes.io/docs/concepts/security/pod-security-standards/). That
matches one of the narrow escape hatches and keeps it aligned with the upstream
standard rather than inventing a broader capability override.

## Decision Drivers

1. **Any-workload support.** Tenants need chart-level expressiveness for
   arbitrary Kubernetes resources that policy allows.
2. **Tenant ease.** Simple tenants should start from a working chart and one
   tfvars file rather than from a blank repository.
3. **Security invariance.** Tenants must not be able to disable the platform
   boundary through tfvars.
4. **Reviewability.** The chart and tfvars should be committed together so CI
   and reviewers can see the proposed workload.
5. **Narrow exceptions.** Real applications need a few controlled exceptions,
   but broad security toggles would defeat the platform posture.

## Considered Options

1. Tenant repository equals in-repo chart plus one `terraform.tfvars`, derived
   from `deploy-tenant-template`.
2. Single `terraform.tfvars` only, with the platform owning a fixed chart.
3. Tenant-owned chart only, with no standardized tfvars contract.
4. Tenant writes raw Terraform against this module and providers.
5. Broad escape-hatch flags for privileged workloads.

## Decision Outcome

Chosen option: **Option 1, tenant repository equals in-repo chart plus one
`terraform.tfvars`, derived from `deploy-tenant-template`.**

The tenant repository contract is:

- `chart/` is the tenant-owned Helm chart. It starts from the golden chart
  starter when that is useful, but may be replaced for any workload shape.
- `terraform.tfvars` is the only tenant variable file expected by the template.
- The module wiring is supplied by `deploy-tenant-template` so tenants do not
  write provider plumbing from scratch.
- Tenant CI renders `chart/` and runs the Layer 1 policy gate before apply.
- The framework module owns project, namespace, quota, limit defaults, RBAC,
  PSA labels, and chart deployment into the framework-created namespace.

The tfvars surface is constrained to:

- ingress hostname and path;
- replicas and HPA minimum and maximum values within platform caps;
- CPU and memory requests and limits within platform caps;
- Vault secret references, never secret values;
- optional persistent storage size and storage class from an allowlist;
- chart values overrides that do not include raw secrets.

The accepted escape hatches are exactly:

1. **Kubernetes API access needed.** The tenant may request a dedicated service
   account and token mount for the specific workload that needs API access.
2. **Low-port binding needed.** The tenant may request `NET_BIND_SERVICE` only.
3. **Persistent storage needed.** The tenant may request storage through the
   structured persistent-volume block, constrained by size and class allowlists.

The following are not tenant flags: host networking, host PID, host IPC,
hostPath, privileged containers, arbitrary capabilities, tenant-created RBAC,
tenant-created Secrets, tenant-created CRDs, disabling PSA Restricted, disabling
Kyverno, `Service` type `LoadBalancer`, and `Service` type `NodePort`.

## Pros and Cons of the Options

### Option 1: Tenant repository with in-repo chart plus one tfvars

- **Good, because** it covers arbitrary Kubernetes workload shapes without
  turning tfvars into a bespoke manifest language.
- **Good, because** the chart and variable review happen in one Git repository.
- **Good, because** a starter chart keeps the common path approachable.
- **Good, because** the platform still owns the envelope and policy boundary.
- **Bad, because** the tenant deliverable is larger than a single file.
- **Bad, because** tenants must understand enough Helm to maintain unusual
  workloads.

### Option 2: Single tfvars only with a platform-owned chart

- **Good, because** it is the simplest possible tenant input surface for a
  narrow class of workloads.
- **Bad, because** it cannot cover arbitrary Kubernetes workloads unless the
  variable schema becomes as expressive as Kubernetes itself.
- **Bad, because** every new workload shape would require platform chart
  changes before the tenant can deploy.
- **Bad, because** it makes the platform own application-specific chart logic.

### Option 3: Tenant-owned chart only

- **Good, because** it maximizes workload expressiveness.
- **Bad, because** it does not standardize ingress, quota, resource caps,
  secret references, storage posture, or tenant CI.
- **Bad, because** it makes tenant onboarding harder than necessary.

### Option 4: Tenant writes raw Terraform

- **Good, because** advanced users can express arbitrary provider logic.
- **Bad, because** it exposes provider and envelope details the framework is
  meant to hide.
- **Bad, because** tenants could bypass or accidentally duplicate the platform
  envelope.

### Option 5: Broad escape-hatch flags

- **Good, because** unusual workloads can be unblocked quickly.
- **Bad, because** broad flags for host networking, privileged mode, hostPath,
  or arbitrary capabilities would directly undermine the security baseline.
- **Bad, because** they would make tenant-specific risk invisible in the
  architecture unless every flag were audited separately.

## Confirmation

1. The future `deploy-tenant-template` MUST include a tenant-owned `chart/` and
   a single expected `terraform.tfvars` file.
2. The future module variables MUST expose only the approved tfvars surface and
   the three audited escape hatches.
3. Terraform validation and OPA policy MUST reject raw secret values and
   unsupported escape hatches.
4. Kyverno and reconcile RBAC MUST reject tenant attempts to create locked kinds
   or use dangerous fields outside the accepted escape hatches.
5. Documentation MUST describe the retired single-tfvars-only promise honestly:
   tenants provide a repo with chart plus one tfvars, not one file alone.

## Consequences

### Positive

- The framework can support any workload a tenant can express in Kubernetes and
  pass through policy.
- The tenant onboarding path remains structured and reviewable.
- Security decisions live in platform policy rather than in chart ownership.

### Negative

- Tenant repositories need chart maintenance guidance and examples.
- A malformed chart can fail before Terraform or at Helm/admission time, so
  tenant documentation must explain the render and policy gates clearly.
- The product statement is less minimal than "one tfvars file only."

### Neutral

- The golden chart starter is still valuable for common workloads.
- Tenants that need only simple deployment shapes can stay close to the starter
  and treat most chart files as platform-provided defaults.

## Assumptions

1. The owner requirement to cover any Kubernetes workload remains higher
   priority than preserving a single-file-only tenant deliverable.
2. Tenant repositories can run CI that renders Helm charts and policy-checks the
   output.
3. The platform will define storage classes, image registries, ingress patterns,
   and resource caps before tenant production use.

## Supersedes

None.

## Superseded by

- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) for the one-chart tenant contract clauses only. This ADR's tenant-owned chart source, one expected tfvars file, constrained input surface, and three escape-hatch decisions remain current.
- [ADR-repo/0009](0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md) for the clauses that implied tenants consume one module that creates both the envelope and the Helm releases. This ADR's tenant-owned chart source, one expected tfvars file, constrained input surface, and three escape-hatch decisions remain current.
- [ADR-repo/0010](0010-default-to-built-in-platform-workload-chart.md)
  for the clauses that made a tenant-owned in-repo chart mandatory for every
  workload. Tenant-owned charts remain supported through explicit `chart_path`,
  but the built-in `platform-workload` chart is now the default when
  `chart_path` is omitted.

## Implementing PRs

- The Step 1 architecture-lock pull request introduces this ADR. Later PRs for
  the variable contract, golden chart starter, tenant template, and policy gates
  should append links here.

## Related ADRs

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) defines the delivery model behind this tenant contract.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the security boundary that keeps arbitrary charts safe.
- [ADR-repo/0004](0004-use-vault-references-and-vault-secrets-operator.md) defines the Vault-reference-only secret input rule.
- [ADR-repo/0005](0005-validate-with-ephemeral-rancher-ci.md) defines how the contract is tested.

## Compliance Notes

This ADR helps explain tenant responsibility boundaries, least-privilege
exception handling, and change-review scope. It does not prove tenant isolation
until the variable validation, admission policies, RBAC, and CI tests are
implemented and evidenced.
