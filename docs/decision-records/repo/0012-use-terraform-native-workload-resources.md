# ADR-repo/0012: Use Terraform-Native Workload Resources

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-18                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-18 owner decision, ADR-repo/0001, ADR-repo/0002, ADR-repo/0003, ADR-repo/0006, ADR-repo/0008, ADR-repo/0009, ADR-repo/0010, ADR-repo/0011, Terraform root module, platform-workload chart. |
| Informed       | Platform operators, tenant repository maintainers, framework maintainers, deploy-runner maintainers, policy authors, CI maintainers, security reviewers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-18                              |

## TL;DR

The workload deploy path will move from `helm_release` of a local chart to
Terraform-native Kubernetes resources. The deploy module will create the
workload's Kubernetes objects directly from `all_workloads` through the
`kubernetes` provider: Deployment, Service, Ingress, HPA, PDB, ServiceAccount,
PVC, and VaultStaticSecret resources.

The recommended configuration that previously lived in the built-in chart's
`values.yaml` will move into Terraform variable defaults and locals. Tenants
still provide one tfvars file containing `all_workloads`, but there is no chart
artifact, Helm provider, `chart_path`, or tenant `values` override in the
target architecture. Security posture remains framework-owned and
non-overridable: security contexts, Pod Security Admission labels, dropped
capabilities, read-only root filesystem, non-root execution, and seccomp
defaults are fixed by the framework, not tenant input.

Layer 1 remains an early rendered-workload gate, but it becomes a
Terraform-rendered manifest gate instead of `helm template`. The gate MUST NOT
reintroduce static OPA-on-plan from ADR-repo/0008.

## Context and Problem Statement

ADR-repo/0001 chose a Rancher envelope plus Helm release of a tenant-owned
local chart. ADR-repo/0003 and ADR-repo/0006 used that chart as the mechanism
for broad Kubernetes workload expression while keeping `terraform.tfvars` as
the tenant's expected variable file. ADR-repo/0010 later made the built-in
`charts/platform-workload` chart the default for simple workloads.

The owner has now chosen a different direction for the framework: drop Helm and
the chart as first-class architecture, and generate workload resources directly
in Terraform. This moves the common and production path away from "tenant
provides chart source plus tfvars" and toward "tenant provides only the
workload data model in `all_workloads`; the framework generates the allowed
Kubernetes objects."

The current implementation has not yet made that migration. At the time of
this ADR, `terraform/modules/deploy/resources.tf` still contains
`helm_release.workload`, and the root `providers.tf` still configures the Helm
provider from `scoped_deploy_kubernetes`. The `charts/platform-workload`
templates still define the hardened Deployment, Service, Ingress, HPA, PDB,
ServiceAccount, PVC, and VaultStaticSecret source that the Terraform-native
implementation must reproduce. This ADR records the decision and implementation
sequence only; it does not change code, providers, charts, or workflows by
itself.

The hard design issue is the Layer 1 gate from ADR-repo/0002. That gate
currently renders a Helm chart with `helm template`, then runs schema and
Kyverno checks on the rendered manifests before anything reaches the cluster.
Dropping Helm must not silently drop early workload-policy feedback, and must
not reintroduce ADR-repo/0008's retired static OPA-on-plan boundary.

## Decision Drivers

1. **Terraform-native operation.** The target deploy path should not depend on
   Helm, a chart directory, or chart-value merging.
2. **Minimal tenant surface.** Tenants should provide one tfvars file whose
   tenant-owned top-level surface remains `all_workloads`.
3. **Fixed security posture.** Tenants must not be able to override security
   contexts, PSA posture, dropped capabilities, read-only root filesystem,
   non-root execution, seccomp, or privileged-field controls.
4. **Recommended defaults in Terraform.** Common configuration should come from
   `optional(type, default)` variable defaults and normalized locals rather
   than a chart `values.yaml`.
5. **Layer 1 continuity.** The framework should keep early rendered-workload
   schema and policy feedback without Helm.
6. **No false controls.** The replacement Layer 1 model must not claim that
   static Terraform plan OPA inspects every workload object.
7. **One-concern migration.** The repo must stay green through small follow-on
   PRs; this ADR is docs-only.

## Considered Options

1. Terraform-native Kubernetes resources with a Terraform-rendered manifest
   Layer 1 gate.
2. Terraform-native Kubernetes resources with mocked Terraform tests only,
   relying on Layer 2 admission as the workload boundary.
3. Keep Helm and the built-in or tenant-owned chart model.
4. Reintroduce static OPA-on-plan for the Terraform-native resources.
5. Allow tenant-provided raw Kubernetes manifests or YAML fragments through
   Terraform variables.

## Decision Outcome

Chosen option: **Option 1, Terraform-native Kubernetes resources with a
Terraform-rendered manifest Layer 1 gate.**

The target deploy module will create Kubernetes objects directly through the
`kubernetes` provider using `all_workloads` after root-level validation and
normalization. The module will no longer deploy `helm_release`, consume a
chart path, or merge tenant chart values. The root and module interfaces should
continue to receive the scoped deploy credential through the provider seam
locked by ADR-repo/0009 and ADR-repo/0011.

Recommended and hardened configuration moves into Terraform:

- variable type constraints use `optional(type, default)` for tenant tunables;
- locals normalize the final workload model and preserve current defaults;
- tenant-tunable values include image reference, exposed ports, ingress
  request, replicas, HPA limits, resources within platform caps, Vault
  references, and structured persistent storage;
- framework-fixed values include security contexts, service account token
  posture except the audited API-access hatch, dropped capabilities, the
  `NET_BIND_SERVICE` escape hatch, read-only root filesystem, non-root
  execution, seccomp, PSA labels, namespace ownership, RBAC, quota, and
  dangerous-field denial.

Layer 1 becomes a Terraform-rendered manifest gate. Implementation PRs must
derive an intended manifest set from the same normalized Terraform object model
used to configure the Kubernetes resources, then run the existing schema and
Kyverno-style checks against those manifests. The exact adapter can be an
output, a local render helper, or another repo-owned tool, but it must not be a
second hand-maintained source of workload truth. It must preserve manifest
inventory checks so missing objects or accidentally removed security fields fail
fast.

This is not OPA-on-plan. The gate checks Kubernetes-shaped rendered manifests,
not Terraform plan JSON, and does not revive the retired static plan policy from
ADR-repo/0008. Layer 2 remains authoritative in-cluster PSA, Kyverno, quota,
and reconcile RBAC even when Layer 1 passes or is bypassed.

This decision supersedes the Helm/local-chart delivery clauses from
ADR-repo/0001 and the built-in chart default from ADR-repo/0010. It amends
ADR-repo/0002's Layer 1 mechanism and ADR-repo/0003/0006 chart clauses while
preserving the one-tfvars `all_workloads` tenant surface.

## Pros and Cons of the Options

### Option 1: Terraform-native resources with rendered manifest gate

- **Good, because** it removes Helm and chart source from the target runtime
  architecture while preserving early schema and policy feedback.
- **Good, because** the framework can encode hardened defaults directly in
  Terraform defaults and locals.
- **Good, because** tenants cannot bypass security fields through chart values
  or chart templates.
- **Good, because** kubeconform and Kyverno checks still evaluate Kubernetes
  manifests before runtime admission.
- **Bad, because** the render adapter must be carefully kept in lockstep with
  the actual Terraform resources.
- **Bad, because** arbitrary chart-level Kubernetes expressiveness is replaced
  by a platform-owned workload schema that must be expanded intentionally.

### Option 2: Terraform tests only plus Layer 2 admission

- **Good, because** typed Terraform resources and mocked tests can assert many
  important fields without introducing a render adapter.
- **Good, because** runtime admission remains authoritative.
- **Bad, because** it weakens the early policy feedback loop recorded in
  ADR-repo/0002.
- **Bad, because** Kyverno and kubeconform would no longer inspect the intended
  workload manifests before apply.
- **Bad, because** security review would split between Terraform assertions and
  admission behavior instead of reusing the policy language that protects the
  cluster.

### Option 3: Keep Helm and charts

- **Good, because** it is already implemented and policy-gated.
- **Good, because** charts allow tenant-owned Kubernetes shapes beyond the
  framework's built-in object set.
- **Bad, because** it contradicts the owner decision to go Terraform-native.
- **Bad, because** it leaves security-relevant defaults spread across Terraform
  values injection and chart templates.

### Option 4: Reintroduce OPA-on-plan

- **Good, because** Terraform-native resources may expose more desired-state
  fields in plan than `helm_release` did.
- **Bad, because** ADR-repo/0008 deliberately retired static OPA-on-plan for
  this framework.
- **Bad, because** plan JSON is still not the same artifact as Kubernetes
  admission input, especially for provider normalization and CRD-like objects.
- **Bad, because** reusing plan OPA here would confuse source-admission,
  Terraform validation, rendered-manifest policy, and runtime admission.

### Option 5: Tenant raw manifests through Terraform variables

- **Good, because** it would recover arbitrary Kubernetes shape expression
  without Helm.
- **Bad, because** it turns tfvars into a raw manifest channel and undermines
  the fixed, non-overridable platform posture.
- **Bad, because** it makes the tenant surface much harder to validate and
  review than the constrained `all_workloads` model.
- **Bad, because** it recreates the same arbitrary-object containment problem
  without the chart tooling that previously rendered it.

## Confirmation

1. The target deploy module MUST create workload Kubernetes objects directly
   with the `kubernetes` provider, not `helm_release`.
2. The target architecture MUST remove the Helm provider and
   `charts/platform-workload` after the Terraform-native replacements and gate
   are implemented.
3. `all_workloads` remains the sole tenant-supplied Terraform variable surface.
4. The target tenant surface MUST NOT include `chart_path`, tenant chart
   source, Helm values, or raw Kubernetes manifests.
5. Recommended tunable configuration MUST be expressed through Terraform
   variable defaults and normalized locals.
6. Security posture MUST remain framework-controlled and non-overridable.
7. Layer 1 MUST be replaced with a Terraform-rendered manifest schema and
   policy gate, not static OPA-on-plan.
8. Layer 2 PSA, Kyverno, quota, and reconcile RBAC remain authoritative at
   runtime.

## Consequences

### Positive

- The target deploy path becomes Terraform-native and removes Helm from the
  runtime dependency graph.
- Recommended defaults live beside Terraform validation and caps logic.
- Tenant input becomes smaller and less able to affect security-sensitive
  fields.
- Existing Kyverno and schema policy investment remains useful through a
  rendered-manifest adapter.

### Negative

- This deliberately retires the earlier arbitrary tenant-chart expression
  model. New Kubernetes object families now require framework implementation
  work, variable contract changes, tests, and policy review.
- The implementation must prevent drift between Terraform resource arguments
  and the manifest-render evidence used by Layer 1.
- Documentation and examples need broad cleanup because many current pages
  accurately describe the still-present Helm implementation.

### Neutral

- The platform envelope and tenant deploy module split from ADR-repo/0009
  remains current.
- The untrusted tenant tfvars source contract from ADR-repo/0011 remains
  current.
- The chart and Helm provider remain in the repository until follow-on
  implementation PRs replace them and keep the repo green.

## Assumptions

1. The owner accepts the expressiveness tradeoff from tenant-owned charts to a
   platform-owned workload schema.
2. The allowed initial object set is Deployment, Service, Ingress, HPA, PDB,
   ServiceAccount, PVC, and VaultStaticSecret.
3. The Terraform Kubernetes provider can model the required objects, using
   typed resources where available and a reviewed manifest resource only where
   required for CRDs such as VaultStaticSecret.
4. A render adapter can be built from the same normalized locals used by the
   resources, so Layer 1 does not become a parallel hand-maintained manifest
   source.

## Supersedes

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md)
  for the `helm_release`, Helm provider, local chart delivery, and golden chart
  starter clauses. Its Rancher envelope and disposable real-provider CI
  decisions remain current.
- [ADR-repo/0010](0010-default-to-built-in-platform-workload-chart.md) in full.
  The built-in chart default is retired by the target Terraform-native deploy
  model.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) for the Helm-based
  `helm template` Layer 1 mechanism only. The two-layer model remains current
  with a Terraform-rendered manifest Layer 1 gate.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) for tenant-owned chart,
  chart-path, and chart-values clauses only. Its one expected tfvars file,
  constrained tenant surface, no-raw-secret posture, and escape-hatch limits
  remain current.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) for the per-entry
  Helm release and local chart path clauses only. Its `all_workloads` list,
  one tenant project, per-workload namespace model, and uniqueness/caps
  validation requirements remain current.

## Superseded by

None (current).

## Implementing PRs

- Step 33 records this ADR and reciprocal ADR/index metadata only.
- Step 34 should replace `helm_release` for the Deployment and fixed
  securityContext with Kubernetes provider resources.
- Step 35 should add Service and Ingress Kubernetes provider resources.
- Step 36 should add HPA and PDB Kubernetes provider resources.
- Step 37 should add ServiceAccount and PVC Kubernetes provider resources.
- Step 38 should add VaultStaticSecret generation through the Kubernetes
  provider.
- Step 39 should replace the Helm render gate with the Terraform-rendered
  manifest Layer 1 gate.
- Step 40 should remove the Helm provider, Helm chart directory, Helm-specific
  tests, and Helm install/gate wiring after replacements are green.
- Step 41 should update examples, module docs, terraform-docs output, and
  tenant-facing documentation for the Terraform-native contract.

## Related ADRs

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md)
  records the superseded Helm/local-chart delivery decision.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the security
  boundary amended by the Terraform-rendered manifest Layer 1 gate.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant
  contract clauses amended by removing chart artifacts.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the
  `all_workloads` shape preserved by this decision.
- [ADR-repo/0008](0008-retire-static-terraform-plan-opa.md) keeps static
  OPA-on-plan retired.
- [ADR-repo/0009](0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md)
  defines the platform envelope and tenant deploy module split.
- [ADR-repo/0010](0010-default-to-built-in-platform-workload-chart.md) records
  the superseded built-in chart default.
- [ADR-repo/0011](0011-treat-tenant-tfvars-as-untrusted-input.md) defines the
  untrusted tenant tfvars source contract preserved by this decision.

## Compliance Notes

This ADR is design evidence only. It does not remove Helm, delete the chart,
change provider configuration, rewrite Terraform resources, or alter CI. Future
compliance evidence must include Terraform resource tests, manifest-render gate
logs, Kyverno/schema gate results, documentation updates, and admission tests
showing that the runtime Layer 2 boundary still rejects unsafe requests.
