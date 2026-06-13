# ADR-repo/0001: Adopt Rancher Envelope and Local Chart Delivery

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-11 owner interview, Rancher provider documentation, Helm provider documentation, Rancher Fleet documentation. |
| Informed       | Tenant repositories derived from `deploy-tenant-template`, framework maintainers, CI policy authors. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-11                              |

## TL;DR

This repository is a reusable Rancher PaaS framework module. Tenant repositories
own an in-repo Helm chart and one `terraform.tfvars`; this module owns the
Rancher envelope around that chart. The module will use the `rancher/rancher2`
provider for project, namespace, quota, and Rancher RBAC objects, then use the
`hashicorp/helm` provider's `helm_release` resource with a local chart path to
deploy the tenant chart into the framework-created namespace.

The rejected alternatives are `rancher2_app_v2`, remote-registry chart
references, granular Kubernetes resources, and Fleet as the primary first
delivery path. This ADR supersedes ADR-template/0002 for this repository's
future `terraform/` implementation and CI integration scope: unlike the
credential-free template, this derivative will use real `rancher2` and `helm`
providers and a real disposable Rancher environment in CI, while preserving the
principle that CI needs no long-lived external credentials.

## Context and Problem Statement

NWarila runs Kubernetes on its own hardware and manages tenant clusters through
SUSE Rancher. The framework must let a tenant deploy any containerized workload
that Kubernetes and the platform security boundary allow, without giving the
tenant control over the namespace, project, quota, or tenant RBAC envelope.

Rancher's Terraform provider explicitly manages Rancher v2 resources and
documents admin and bootstrap modes for the Rancher API
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/index.md).
The same provider documents first-class `rancher2_project`,
`rancher2_namespace`, and `rancher2_project_role_template_binding` resources
for project, namespace, quota, container defaults, and project role binding
management
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/resources/project.md,
https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/resources/namespace.md,
https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/resources/project_role_template_binding.md).

The Helm provider documents that `helm_release.chart` may be a path and gives a
local chart example with `chart = "./charts/example"`
(https://raw.githubusercontent.com/hashicorp/terraform-provider-helm/main/docs/resources/release.md).
That makes a tenant-owned in-repo chart compatible with Terraform without
requiring a chart registry.

The Rancher provider compatibility matrix is version-sensitive and states that
the provider line is recommended for the associated Rancher minor version, such
as 13.x for Rancher 2.13.x
(https://github.com/rancher/terraform-provider-rancher2/blob/main/docs/compatibility-matrix.md).
The future provider pin must therefore be selected after the target Rancher
minor is known, and must remain exact per ADR-template/0001.

## Decision Drivers

1. **Tenant workload breadth.** The tenant must be able to express any workload
   shape Kubernetes supports, subject to security policy.
2. **Platform-owned envelope.** Projects, namespaces, quotas, and RBAC must be
   fixed by the framework rather than tenant charts.
3. **Template-time policy visibility.** Tenant chart source should be available
   to CI before Terraform applies anything.
4. **No chart registry dependency.** The first delivery path should not require
   NWarila to run, secure, and policy-gate a chart registry.
5. **Provider fit.** Terraform should use the provider that owns the API surface
   in question: Rancher for the envelope, Helm for Helm chart deployment.
6. **Future GitOps compatibility.** The model should not block a later Fleet or
   GitOps path, but it should keep the first framework implementation small and
   testable.

## Considered Options

1. `rancher2` envelope plus `helm_release` of a tenant-owned local chart path.
2. `rancher2_app_v2` for both chart deployment and Rancher app lifecycle.
3. Remote-registry chart references consumed by Terraform.
4. Granular Kubernetes resources managed directly by Terraform.
5. Fleet as the primary tenant deployment mechanism.

## Decision Outcome

Chosen option: **Option 1, `rancher2` envelope plus `helm_release` of a
tenant-owned local chart path.**

This repository will become a reusable module with these ownership boundaries:

- `rancher2` manages the tenant envelope: project, namespace, project-level
  quota and defaults, namespace quota and defaults when needed, and Rancher RBAC
  bindings.
- Kubernetes provider resources are allowed only as a fallback for envelope
  objects the Rancher provider cannot own cleanly.
- `helm_release` deploys the tenant's local in-repo chart path, normally
  `chart = "${path.root}/chart"` from the tenant repository, into the namespace
  created by the framework.
- The tenant repository is derived from `deploy-tenant-template` and carries its
  own `chart/` plus one `terraform.tfvars`.
- This repository will ship a golden chart starter to make the easy case easy,
  but that starter is not the security boundary and tenants may replace it.

This repository also records a repo-scope supersession of ADR-template/0002 for
the future `terraform/` and Rancher integration validation scope. The inherited
template is intentionally credential-free and synthetic. This derivative is
allowed to use real Rancher and Helm providers and a disposable Rancher
environment in CI. It must still avoid long-lived external credentials in CI:
the Rancher management and downstream clusters are created in-runner and
destroyed in the same validation flow.

## Pros and Cons of the Options

### Option 1: Rancher envelope plus `helm_release` of a local chart path

- **Good, because** it assigns ownership to the API that owns the concept:
  Rancher for project, namespace, quota, and RBAC; Helm for Helm chart release
  lifecycle.
- **Good, because** the Helm provider explicitly supports local chart paths, so
  tenant repositories can keep chart source in Git.
- **Good, because** an in-repo chart enables pre-apply `helm template` policy
  checks in tenant CI.
- **Good, because** no chart registry is required for the first implementation.
- **Good, because** tenants can express arbitrary Kubernetes workload shapes
  while the platform locks the envelope and admission controls.
- **Bad, because** Terraform plan output for `helm_release` does not model each
  rendered Kubernetes object as a first-class Terraform resource.
- **Bad, because** drift and timeout behavior is split between Terraform, Helm,
  the downstream Kubernetes API, and admission webhooks.

### Option 2: `rancher2_app_v2`

- **Good, because** it is Rancher's own App v2 abstraction and is available for
  Rancher v2.5.x and above.
- **Good, because** it integrates with Rancher app inventory.
- **Bad, because** the documented resource requires a Rancher repo name and
  chart name, which pushes the design toward Rancher chart catalog usage rather
  than tenant-owned local chart source.
- **Bad, because** it does not preserve the simple tenant-repo `helm template`
  gate as the natural first-class source of truth.
- **Bad, because** it couples workload release lifecycle to Rancher's app layer
  when the framework only needs Rancher for the envelope.

### Option 3: Remote-registry chart references

- **Good, because** it can work with the Helm provider's documented repository,
  URL, OCI, GCS, and S3 chart sources.
- **Good, because** it is a familiar distribution path for published charts.
- **Bad, because** tenant chart content is not necessarily present in the tenant
  pull request, which weakens template-time policy review.
- **Bad, because** the first implementation would need registry governance,
  authentication, retention, and provenance before the workload boundary is
  trustworthy.
- **Bad, because** it makes "what was reviewed" less obvious than a chart
  committed beside the tenant's tfvars.

### Option 4: Granular Kubernetes resources

- **Good, because** Terraform plan output would expose individual Kubernetes
  resources more directly than `helm_release`.
- **Good, because** Terraform could model some resource dependencies explicitly.
- **Bad, because** arbitrary tenant workloads cannot be represented by a fixed
  framework-owned set of HCL resources without either constraining workloads or
  re-implementing a chart renderer in Terraform.
- **Bad, because** CRDs and dynamic schemas make a generic Terraform resource
  model harder to validate and more brittle than rendered-manifest policy plus
  admission.
- **Bad, because** it creates substantially more HCL for tenants and framework
  maintainers.

### Option 5: Fleet as the primary delivery mechanism

- **Good, because** Fleet is Rancher's GitOps deployment engine and can manage
  raw YAML, Helm charts, and Kustomize from Git
  (https://fleet.rancher.io/).
- **Good, because** Fleet may become attractive for multi-cluster rollout,
  continuous reconciliation, and GitOps-first tenants.
- **Bad, because** it adds Fleet CRDs and controller behavior before the base
  Terraform module envelope is proven.
- **Bad, because** the immediate framework requirement is a reusable Terraform
  module consumed by tenant repositories, not a GitOps controller contract.
- **Neutral, because** this ADR does not ban Fleet later; it keeps Fleet as a
  possible future delivery path if a later ADR supersedes this first path.

## Confirmation

1. The future `terraform/` module MUST include exact-pinned `rancher/rancher2`
   and `hashicorp/helm` providers.
2. The future Rancher provider major MUST be selected from the Rancher provider
   compatibility matrix after the target Rancher minor is chosen.
3. The module MUST create or own the project and namespace envelope before
   deploying the tenant chart.
4. The module MUST deploy the tenant chart from a local path, not from a remote
   chart registry, unless a later ADR supersedes this decision.
5. Tenant charts MUST NOT be allowed to create or mutate the framework-owned
   namespace, tenant RBAC, CRDs, or other locked envelope resources.
6. CI MUST preserve the no-long-lived-external-credentials principle by using
   disposable in-runner Rancher infrastructure for integration validation.

## Consequences

### Positive

- The architecture supports arbitrary tenant charts without surrendering the
  platform envelope.
- The tenant repository remains self-reviewable: chart source, values, and
  tfvars are in one pull request.
- The first implementation avoids a chart registry, GitOps controller contract,
  or fixed Terraform workload schema.

### Negative

- Terraform plan policy cannot be the workload security boundary because the
  Kubernetes objects are rendered by Helm rather than represented as normal HCL
  resources.
- The module will need strong timeout, wait, and failure documentation around
  Helm and admission errors.
- A future Fleet path would require a new ADR and migration plan rather than
  being implicit in this first implementation.

### Neutral

- The golden chart starter is a convenience artifact, not a required workload
  shape and not a security control.
- Remote chart registries remain available for future explicitly governed use
  cases, but they are not part of the first accepted architecture.

## Assumptions

1. Tenants can use Git repositories derived from `deploy-tenant-template`.
2. The platform can install and maintain the Helm, Rancher, Kyverno, and Vault
   Secrets Operator components needed by later ADRs.
3. The target Rancher minor will be selected before the Terraform provider pins
   are introduced.
4. Tenant chart review and CI are acceptable parts of the tenant onboarding
   contract.

## Supersedes

- [ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md) for this repository's future `terraform/` implementation and Rancher integration CI scope only. The repo keeps the no-long-lived-external-credentials principle, but replaces the synthetic reference implementation with real Rancher and Helm providers and disposable CI infrastructure.

## Superseded by

- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) for the single-chart, single-namespace delivery clauses only. This ADR's Rancher envelope, local chart, and real-provider CI decisions remain current.
- [ADR-repo/0009](0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md) for the single-module delivery and opaque Helm credential clauses only. This ADR's Rancher envelope, local chart, Helm release, and disposable real-provider CI decisions remain current.

## Implementing PRs

- The Step 1 architecture-lock pull request introduces this ADR. Later
  implementation PRs for the Terraform module and CI harness should append
  links here.

## Related ADRs

- [ADR-template/0001](../template/0001-pin-terraform-and-provider-versions-exactly.md) requires exact Terraform and provider pins.
- [ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md) is superseded only for this repository's real-provider implementation and integration-validation scope.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the security boundary required because `helm_release` is not a first-class Kubernetes-object plan model.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant repository contract built on this delivery model.
- [ADR-repo/0005](0005-validate-with-ephemeral-rancher-ci.md) defines the disposable Rancher validation path.

## Compliance Notes

This ADR is design rationale, not evidence that the framework is already
compliant. It may support review evidence for architecture, change-control, and
supply-chain design discussions by showing why tenant chart source stays in Git,
why the platform owns the Rancher envelope, and why CI uses disposable
infrastructure rather than long-lived credentials.
