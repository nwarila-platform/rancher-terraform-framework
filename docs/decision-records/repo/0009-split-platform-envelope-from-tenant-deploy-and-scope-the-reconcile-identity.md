# ADR-repo/0009: Split Platform Envelope From Tenant Deploy and Scope the Reconcile Identity

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-13                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-13 owner decision, Step 24 design review, Rancher provider documentation, Kubernetes provider documentation, Kubernetes RBAC and ServiceAccount documentation, Terraform sensitive-data documentation. |
| Informed       | Platform operators, tenant repository maintainers, framework maintainers, policy authors, CI maintainers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-13                              |

## TL;DR

The framework splits into two modules so the platform can own the Rancher
envelope with admin credentials while tenants deploy charts only through a
platform-issued restricted identity. The platform envelope module is run by the
platform at tenant onboarding. It creates the Rancher project, workload
namespace envelopes, quotas, PSA labels, and the restricted reconcile identity
with kind-allowlist RBAC. It then issues a scoped deploy credential for that
identity. The tenant deploy module is consumed by the tenant's single
repository and runs `helm_release` only with the scoped credential.

This keeps the tenant experience as one repository containing chart source,
one `terraform.tfvars`, and CI. It changes the framework implementation
boundary: tenants no longer run the admin envelope path, and the Helm provider
is no longer allowed to authenticate through an opaque credential that might be
admin.

## Context and Problem Statement

ADR-repo/0001 chose a Rancher envelope plus `helm_release` of tenant-owned
local charts. ADR-repo/0006 later expanded the contract to `all_workloads`:
one tenant project with per-workload namespaces and releases. The first
Terraform module combined both concerns: Rancher envelope resources and Helm
release deployment.

The Step 24 design gate found a control gap in that combined shape. The
module bound a restricted reconciler role, but `helm_release` authenticated
through `var.helm_kubernetes`, an opaque provider configuration. Nothing in
Terraform proved that this kubeconfig represented the restricted reconciler
principal. A tenant or caller could accidentally or deliberately provide a
broader credential, making the RBAC allowlist a false control. The same
combined module also needed admin credentials for the envelope while the
tenant deploy path must not hold admin credentials.

Rancher role templates are buildable: the Rancher provider documents
`rancher2_role_template` with `cluster` and `project` context support and
policy `rules`
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/resources/role_template.md).
Rancher project role template bindings are buildable for Rancher users or
groups, but the documented binding resource targets `user_id`,
`user_principal_id`, `group_id`, or `group_principal_id`
(https://raw.githubusercontent.com/rancher/terraform-provider-rancher2/main/docs/resources/project_role_template_binding.md).
The locked reconcile identity is a Kubernetes ServiceAccount identity, so the
ServiceAccount path must be implemented through Kubernetes RBAC unless a later
ADR deliberately chooses Rancher user/group credentials instead.

Kubernetes RBAC supports the needed least-privilege shape. Kubernetes documents
that Roles are namespace-scoped, that permissions are additive with no deny
rules, and that RoleBindings grant those permissions to subjects
(https://kubernetes.io/docs/reference/access-authn-authz/rbac/). The
Kubernetes provider documents `kubernetes_role_v1`, `kubernetes_role_binding_v1`,
and `kubernetes_service_account_v1` resources for those objects
(https://raw.githubusercontent.com/hashicorp/terraform-provider-kubernetes/main/docs/resources/role_v1.md,
https://raw.githubusercontent.com/hashicorp/terraform-provider-kubernetes/main/docs/resources/role_binding_v1.md,
https://raw.githubusercontent.com/hashicorp/terraform-provider-kubernetes/main/docs/resources/service_account_v1.md).

The scoped kubeconfig is itself a credential. Kubernetes documents kubeconfig
files as carrying cluster, user, namespace, and authentication data, including
token-based user authentication
(https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/).
Kubernetes also documents ServiceAccount token Secrets as a long-lived
credential mechanism and recommends short-lived TokenRequest tokens where
possible
(https://kubernetes.io/docs/concepts/configuration/secret/#serviceaccount-token-secrets).
Terraform documents that direct secret values and sensitive outputs can still
be stored in state or plan files, while ephemeral values can avoid state and
plan persistence in supported contexts
(https://developer.hashicorp.com/terraform/language/manage-sensitive-data).
Therefore, this ADR locks the credential boundary and leaves exact issuance
and delivery mechanics to implementation follow-up rather than pretending that
a raw Terraform output is automatically safe.

## Decision Drivers

1. **Tenant admin removal.** Tenants must never need Rancher admin or
   envelope-owner credentials to deploy their chart.
2. **Single tenant repository.** The tenant's usable experience remains one
   deploy repository with chart source, one tfvars file, and CI.
3. **Provable reconcile identity.** The Helm provider must authenticate only
   as the platform-issued restricted identity, not as an arbitrary caller
   credential.
4. **Defense in depth.** RBAC must mirror the Kyverno kind allowlist while
   Kyverno remains the authoritative runtime admission control.
5. **Credential hygiene.** Scoped kubeconfigs and tokens are secrets and must
   not be committed, placed in tenant tfvars, or casually exposed through
   Terraform state.
6. **Provider feasibility.** The chosen model must be implementable with
   Rancher and Kubernetes Terraform providers without live cluster operations
   in normal local checks.

## Considered Options

1. Single combined module with a contract that `helm_kubernetes` is a restricted
   platform-issued kubeconfig.
2. Single combined module that creates an in-module restricted ServiceAccount
   and then reconfigures Helm to use it.
3. Split platform envelope module from tenant deploy module.

## Decision Outcome

Chosen option: **Option 3, split platform envelope module from tenant deploy
module.**

The framework will provide two modules:

- **Platform envelope module.** Run by the platform during tenant onboarding
  with admin `rancher2` and any required admin Kubernetes provider context. It
  creates the Rancher tenant project, per-workload namespaces under that
  project, quota and defaults, PSA labels, and platform-owned reconcile
  identity resources. It also creates Role and RoleBinding objects, or an
  equivalent Rancher permission set if a later implementation proves a Rancher
  principal path is safer, that grant only the approved workload API surface.
- **Tenant deploy module.** Consumed by the tenant's single deploy repository.
  It deploys each local chart with `helm_release`, `create_namespace = false`,
  `skip_crds = true`, and authentication that comes only from the
  platform-issued scoped credential.

The split is invisible to the tenant's repository shape. The tenant still owns
chart source and one expected tfvars file. The platform, not the tenant, runs
the envelope module and delivers the scoped deploy credential through an
approved secret channel.

The reconcile identity's RBAC allowlist must stay coupled to
`policies/kyverno/restrict-object-kinds.yaml`. The current mapping is:

| Kind | API group | RBAC resources |
| --- | --- | --- |
| ConfigMap | `""` | `configmaps` |
| Service | `""` | `services` |
| ServiceAccount | `""` | `serviceaccounts` |
| PersistentVolumeClaim | `""` | `persistentvolumeclaims` |
| Deployment | `apps` | `deployments` |
| StatefulSet | `apps` | `statefulsets` |
| Job | `batch` | `jobs` |
| CronJob | `batch` | `cronjobs` |
| Ingress | `networking.k8s.io` | `ingresses` |
| HorizontalPodAutoscaler | `autoscaling` | `horizontalpodautoscalers` |
| PodDisruptionBudget | `policy` | `poddisruptionbudgets` |
| VaultStaticSecret | `secrets.hashicorp.com` | `vaultstaticsecrets` |

The allowed verbs are `get`, `list`, `watch`, `create`, `update`, `patch`, and
`delete`. Everything else is denied by omission: no Secrets, Roles,
RoleBindings, ClusterRoles, ClusterRoleBindings, CustomResourceDefinitions,
Namespaces, ResourceQuotas, LimitRanges, NetworkPolicies, DaemonSets, bare
Pods, ReplicaSets, or other non-approved kinds.

Kyverno admission remains authoritative for kind and field enforcement. RBAC is
the least-privilege deploy credential that prevents the tenant deploy path from
even asking for non-approved kinds when the API server can reject them before
admission policy has to.

## Pros and Cons of the Options

### Option 1: Single module with contract-issued restricted kubeconfig

- **Good, because** it preserves the original single-module implementation
  shape.
- **Good, because** it is the smallest Terraform refactor.
- **Bad, because** the module still accepts an opaque Helm provider credential
  and cannot prove that the caller supplied the restricted principal.
- **Bad, because** the admin envelope provider and deploy provider remain in
  one module interface, which makes it easier to leak or misuse admin
  credentials.
- **Bad, because** the RBAC allowlist becomes partly procedural: reviewers must
  trust that the external credential contract was followed.

### Option 2: Single module that creates and then uses a restricted ServiceAccount

- **Good, because** the ServiceAccount and RoleBinding resources can be
  directly modeled by Terraform.
- **Good, because** it keeps a single module name for callers.
- **Bad, because** Helm provider configuration cannot cleanly depend on
  credentials generated by resources earlier in the same apply without a
  two-phase apply, wrapper, or separate state handoff.
- **Bad, because** the tenant-facing module still needs admin provider context
  to create the envelope, which conflicts with "tenants never hold admin."
- **Bad, because** it hides a two-run operational workflow inside what appears
  to be one deploy path.

### Option 3: Split platform envelope from tenant deploy

- **Good, because** tenants do not run the admin envelope path.
- **Good, because** the tenant deploy module can be validated around one
  credential class: the scoped reconcile credential.
- **Good, because** the platform can create namespace, quota, PSA labels, and
  RBAC before the tenant's CI or apply path can deploy a chart.
- **Good, because** the tenant still has one repository; the split is in the
  framework's module boundary and platform onboarding workflow.
- **Good, because** it aligns RBAC least privilege with the Kyverno allowlist
  instead of relying only on admission to reject excessive requests.
- **Bad, because** implementation now needs a secure credential issuance and
  delivery workflow between platform onboarding and tenant CI.
- **Bad, because** documentation must explain that the tenant module consumes
  pre-created envelope outputs rather than creating the envelope itself.

## Confirmation

1. The framework MUST split the admin envelope path from the tenant deploy
   path before implementing the reconcile RBAC control.
2. The platform envelope module MUST be the only module that requires Rancher
   admin or namespace/RBAC owner credentials.
3. The tenant deploy module MUST deploy charts only with the platform-issued
   scoped credential.
4. Tenant repositories MUST remain single deploy repositories containing chart
   source, one expected tfvars file, and CI.
5. The scoped credential MUST NOT be stored in tenant Git or passed as a raw
   tenant tfvars value.
6. The scoped credential delivery path MUST be designed so Terraform state and
   plan files do not become casual credential-distribution artifacts.
7. Reconcile RBAC MUST mirror the approved kind set in
   `policies/kyverno/restrict-object-kinds.yaml`; when the Kyverno allowlist
   changes, the RBAC mapping must change in the same security review.
8. Kyverno MUST remain the authoritative runtime admission boundary even when
   RBAC rejects non-approved API requests earlier.

## Consequences

### Positive

- The tenant deploy path has a hard credential boundary instead of a
  convention around `var.helm_kubernetes`.
- The platform can own onboarding, namespace envelopes, quota, PSA labels, and
  reconcile identity lifecycle separately from tenant chart deployment.
- The RBAC allowlist becomes a real defense-in-depth twin of the Kyverno
  allowlist.

### Negative

- The implementation must create and document two modules rather than one.
- Onboarding now needs a secure way to deliver scoped deploy credentials to
  the tenant repository's CI environment.
- Credential rotation and revocation become first-class platform operations
  that must be tested and documented.

### Neutral

- The local-chart delivery decision remains current.
- The `all_workloads` tenant contract remains current; its envelope and deploy
  effects are now implemented across two modules.
- A future Fleet or GitOps path would still need its own ADR.

## Assumptions

1. The platform can run a tenant onboarding workflow before tenant deploy CI is
   enabled.
2. The platform can create Kubernetes RBAC resources in tenant workload
   namespaces through an admin Kubernetes provider context or an equivalent
   Rancher-controlled path.
3. The deploy credential can be delivered to tenant CI through an approved
   secret channel such as Vault, a platform-owned CI secret, or another
   auditable secret broker.
4. Short-lived TokenRequest-based credentials are preferred where practical;
   long-lived ServiceAccount token Secrets require explicit state, rotation,
   and revocation handling.
5. The exact scoped-kubeconfig delivery mechanism is not yet implemented and
   needs a follow-up design decision or implementation note before production
   use.

## Supersedes

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) for the single-module delivery and opaque Helm credential clauses only. Its Rancher envelope, local chart, Helm release, and disposable real-provider CI decisions remain current.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) for the clauses that implied tenants consume one module that creates both the envelope and the Helm releases. Its tenant-owned chart source, one expected tfvars file, constrained input surface, and three escape-hatch decisions remain current.

## Superseded by

None (current).

## Implementing PRs

- The Step 25 architecture-lock pull request introduces this ADR. Later PRs
  for the platform envelope module, tenant deploy module, scoped credential
  wiring, RBAC tests, and tenant template should append links here.

## Related ADRs

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) defines the Rancher envelope and local chart delivery model this ADR splits across modules.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines Kyverno admission and reconcile RBAC as paired controls.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant repository shape that remains a single repo.
- [ADR-repo/0004](0004-use-vault-references-and-vault-secrets-operator.md) defines the no-raw-secret posture that also applies to scoped kubeconfigs.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the multi-workload tenant contract preserved by the split.
- [ADR-repo/0008](0008-retire-static-terraform-plan-opa.md) keeps the workload boundary in render checks and admission rather than Terraform plan OPA.

## Compliance Notes

This ADR supports separation-of-duties, least-privilege, tenant-isolation, and
credential-handling review narratives. It is not implementation evidence. The
future evidence set must include the two module interfaces, RBAC resources,
proof that tenant Helm applies use only the scoped credential, credential
rotation and revocation documentation, and admission tests proving Kyverno
remains authoritative.
