# ADR-repo/0006: Use All Workloads Tenant Contract

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-12                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-12 owner interview, Rancher provider documentation, aws-terraform-framework, proxmox-terraform-framework. |
| Informed       | Tenant repositories derived from `deploy-tenant-template`, framework maintainers, CI policy authors. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-12                              |

## TL;DR

The tenant repository still contains tenant-owned Helm chart source and exactly
one expected `terraform.tfvars` file, but that tfvars file defines a list of
workloads through `all_workloads`, not a single workload envelope. The framework
creates one Rancher project for the tenant as the quota and RBAC boundary. Each
`all_workloads` entry becomes a per-workload namespace under that project plus
a `helm_release` of that workload's local chart path.

This ADR scoped-supersedes the single-chart and single-namespace clauses of
[ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md)
and [ADR-repo/0003](0003-define-tenant-repo-contract.md). Their core decisions
remain intact: tenants own chart source, the platform owns the Rancher envelope,
and security is enforced by tenant-repo render checks plus in-cluster admission.

## Context and Problem Statement

The Step 1 ADRs described a tenant repository as one chart plus one tfvars file,
with this module deploying that chart into one framework-created namespace. The
owner later clarified that this framework should follow the `all_*`
list-of-objects pattern used by sibling Terraform frameworks, so one tfvars file
can describe multiple related objects.

The AWS framework uses list-object variables such as `all_systems`,
`all_databases`, and `all_load_balancers`, then keys resources through locals
and `for_each`. The Proxmox Terraform framework uses the same shape in the
packer-limited style: `all_systems = list(object(...))`, locals keyed by system
name, and `for_each` resources. That structure maps naturally to Rancher
workloads because each workload needs the same envelope knobs: namespace,
release, chart path, ingress, scaling, resource requests and limits, Vault
references, chart values, and the three audited escape hatches.

The Rancher provider supports this mapping directly. `rancher2_project` has a
required `cluster_id` and supports project quota and namespace defaults
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/master/docs/resources/project.md).
`rancher2_namespace` requires a `project_id` and supports namespace quota
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/master/docs/resources/namespace.md).
Therefore, one tenant project can contain multiple framework-created namespaces
without giving tenants namespace ownership.

## Decision Drivers

1. **One tfvars file remains the tenant interface.** Tenants should define all
   workload envelopes in one expected tfvars file.
2. **Many workloads per tenant.** A tenant may need multiple independently
   deployed charts that share the same platform project boundary.
3. **Rancher object fit.** Rancher projects are the natural project-level quota
   and RBAC boundary; namespaces are the natural per-workload isolation unit.
4. **Security continuity.** Each workload still needs PSA labels, quota locks,
   Helm CRD blocking, and admission controls.
5. **Framework-family consistency.** The variable contract should match the
   sibling `all_*` list-object pattern.

## Considered Options

1. One tenant project with one namespace and one `helm_release` per
   `all_workloads` entry.
2. One Rancher project per workload.
3. A caller-controlled project mode where workloads choose their own project.
4. Keep the single-workload variable surface and defer multi-workload support.

## Decision Outcome

Chosen option: **Option 1, one tenant project with per-workload namespaces and
releases.**

The future Terraform module contract is:

- `all_workloads` is a list of workload objects.
- Each workload has a stable key, namespace name, release name, local
  `chart_path`, ingress request, replicas/HPA request, resource request and
  limit request, Vault secret references, non-secret chart values, optional
  persistent storage, and the two non-storage escape hatches.
- The module creates one tenant Rancher project for the tenant/project input.
- For each workload, the module creates one Rancher namespace under that
  project with PSA Restricted labels and locked namespace quota.
- For each workload, the module creates one `helm_release` targeted at that
  workload namespace, with `create_namespace = false`, `skip_crds = true`, and
  CRD hooks disabled.
- Project-level quota is the tenant cap. Namespace quota and container defaults
  are the per-workload cap/default envelope.
- The module consumes `all_workloads` using `for_each` over a locally keyed map,
  following the sibling framework precedent.

Future validation must enforce these new invariants:

- workload keys are unique and stable;
- namespace names are unique within the tenant project;
- release names are unique where Helm requires uniqueness;
- ingress hosts are unique unless a later ADR explicitly allows host/path
  sharing;
- each chart path is local and non-empty;
- per-workload scaling, resource, storage, and escape-hatch requests stay within
  platform caps;
- tenant values do not contain raw secret-looking content;
- no tenant input exposes host networking, host PID, host IPC, hostPath,
  privileged containers, arbitrary capabilities, tenant-created RBAC,
  tenant-created Secrets, tenant-created CRDs, disabling PSA Restricted,
  disabling Kyverno, `Service` type `LoadBalancer`, or `Service` type
  `NodePort`.

## Pros and Cons of the Options

### Option 1: One tenant project with per-workload namespaces and releases

- **Good, because** it keeps the tenant project as the shared quota and RBAC
  boundary.
- **Good, because** namespace-level PSA labels and quotas apply independently
  to each workload.
- **Good, because** it matches Rancher's documented project-to-namespace model.
- **Good, because** it composes with `for_each` and the framework-family
  `all_*` variable pattern.
- **Bad, because** validations must now protect list-wide uniqueness and
  per-workload cardinality.

### Option 2: One Rancher project per workload

- **Good, because** it maximizes workload separation.
- **Bad, because** it makes tenant-level quota and RBAC harder to reason about
  and heavier to operate.
- **Bad, because** it creates more Rancher objects than the tenant-level
  boundary requires.

### Option 3: Caller-controlled project mode

- **Good, because** it is flexible for unusual tenants.
- **Bad, because** it exposes the platform envelope boundary as a tenant input.
- **Bad, because** it risks splitting a tenant's workloads across inconsistent
  security and quota boundaries.

### Option 4: Keep single-workload variables

- **Good, because** the Step 2 skeleton already matches this shape.
- **Bad, because** it ignores the owner's `all_*` direction and does not match
  the sibling framework model.

## Confirmation

1. Future Terraform code MUST expose workload definitions through
   `all_workloads`.
2. Future Terraform code MUST use one tenant Rancher project as the tenant
   envelope unless a later ADR supersedes this mapping.
3. Future Terraform code MUST create one namespace and one Helm release per
   workload entry.
4. Future Terraform validation MUST enforce workload, namespace, release, and
   ingress uniqueness.
5. The per-workload namespace and release model MUST preserve the security
   controls accepted in ADR-repo/0002.

## Consequences

### Positive

- One tfvars file can describe multiple tenant workloads without turning the
  framework into a raw Kubernetes manifest language.
- Tenant-level project quota and RBAC stay centralized.
- Workload-level namespace boundaries make PSA, quota, policy failures, and
  cleanup easier to isolate.

### Negative

- The Step 2 singular-variable Terraform skeleton must be refactored before
  rich validation work continues.
- Tenant docs must explain list-wide uniqueness and per-workload namespace
  behavior.

### Neutral

- The golden chart starter remains a starter. Tenants may use one chart copied
  multiple times, several charts, or custom charts, subject to policy.

## Assumptions

1. A tenant project is the desired operational boundary for quota, RBAC, and
   ownership.
2. Workloads inside one tenant project are related enough to share the tenant
   project boundary.
3. Later policy work will keep arbitrary tenant charts bounded by render gates,
   PSA Restricted, Kyverno, quota, and reconcile RBAC.

## Supersedes

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) for the single-chart, single-namespace delivery clauses only.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) for the one-chart tenant contract clauses only.

## Superseded by

None (current).

## Implementing PRs

- The Step 3 architecture-reconciliation pull request introduces this ADR.
  Later Terraform refactor PRs should append links here.

## Related ADRs

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) defines the underlying Rancher envelope plus local chart delivery model.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the security boundary that applies to every workload namespace.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant repository contract this ADR narrows and extends.
- [ADR-repo/0007](0007-adopt-packer-limited-hcl-style.md) defines the HCL style used to implement this contract.

## Compliance Notes

This ADR is design rationale, not implementation evidence. It supports review
of the future variable contract and object mapping, but compliance depends on
later Terraform refactor, validation, policy, and CI evidence.
