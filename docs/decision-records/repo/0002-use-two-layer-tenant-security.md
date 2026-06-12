# ADR-repo/0002: Use Two-Layer Tenant Security

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-11 owner interview, Kubernetes Pod Security documentation, Kyverno documentation, Helm provider documentation. |
| Informed       | Tenant repository maintainers, framework maintainers, policy authors, CI maintainers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-11                              |

## TL;DR

Tenant workload security uses two layers. Layer 1 is a tenant-repository
template-time policy gate over the rendered in-repo chart: `helm template`
feeds schema and policy tools before a pull request can apply. Layer 2 is the
authoritative runtime boundary in the cluster: Pod Security Admission Restricted
plus Kyverno admission policies, backed by an envelope RBAC allowlist for the
identity that reconciles tenant charts.

Terraform and OPA remain valuable for early feedback on visible envelope and
input choices, but they are not the workload security boundary because
`helm_release` does not expose every rendered Kubernetes object as ordinary
Terraform resources in the plan. Admission is the final boundary because it sees
requests from Terraform, Helm, kubectl, Rancher UI, future GitOps controllers,
and any other Kubernetes API producer.

## Context and Problem Statement

ADR-repo/0001 chooses `helm_release` of a tenant-owned local chart path. That
choice gives tenants broad workload expressiveness, but it also means a tenant
chart can render arbitrary Kubernetes objects unless the platform constrains
them before and during admission.

The Helm provider documents `helm_release.manifest` and `helm_release.resources`
as read-only rendered outputs rather than first-class desired Kubernetes
resources, and documents `metadata.values` as read-only release metadata
(https://raw.githubusercontent.com/hashicorp/terraform-provider-helm/main/docs/resources/release.md).
That means an OPA policy over `terraform show -json` can validate the
framework-visible envelope, but it is the wrong place to be the sole workload
policy boundary for arbitrary Helm-rendered manifests.

Kubernetes Pod Security Admission documents namespace labels for `enforce`,
`audit`, and `warn` modes, including the `restricted` level
(https://kubernetes.io/docs/concepts/security/pod-security-admission/). The
same documentation has an important limitation: enforce mode is applied to the
resulting Pod objects, not to workload resources themselves. It says audit and
warning modes apply to workload resources, but enforce mode applies only to the
Pods created from them. Therefore, PSA Restricted is necessary but not
sufficient for every chart hazard.

Kubernetes Pod Security Standards Restricted covers core Pod-level controls:
privileged containers, hostPath, host ports, privilege escalation, non-root,
seccomp, and dropping `ALL` capabilities while allowing only
`NET_BIND_SERVICE` to be added back
(https://kubernetes.io/docs/concepts/security/pod-security-standards/).

Kyverno covers the policy surface PSA does not cover. Kyverno validate rules can
deny requests, generate rules can create and synchronize resources such as
namespace default-deny NetworkPolicies, verifyImages rules can enforce image
digest and signature policy, and the Kyverno CLI can apply policies to resource
files before cluster admission
(https://kyverno.io/docs/policy-types/cluster-policy/validate/,
https://kyverno.io/docs/policy-types/cluster-policy/generate/,
https://kyverno.io/docs/policy-types/cluster-policy/verify-images/overview/,
https://kyverno.io/docs/kyverno-cli/reference/kyverno_apply/).

## Decision Drivers

1. **Authoritative runtime enforcement.** The final boundary must see every
   Kubernetes API producer, not only Terraform.
2. **Early tenant feedback.** Tenant pull requests should fail before apply
   when chart output violates platform policy.
3. **Arbitrary chart containment.** The policy set must handle tenant charts
   that render unexpected kinds or dangerous fields.
4. **Defense in depth.** Runtime admission and the reconcile identity's RBAC
   should both prevent dangerous objects.
5. **Clear division of labor.** Terraform/OPA should validate the envelope and
   allowed inputs; Kubernetes admission should validate rendered workloads.

## Considered Options

1. Tenant-repo template-time gate plus in-cluster PSA Restricted and Kyverno,
   backed by envelope RBAC.
2. Terraform plan OPA as the only workload security boundary.
3. PSA Restricted only.
4. Kyverno only.
5. Human chart review only.

## Decision Outcome

Chosen option: **Option 1, tenant-repo template-time gate plus in-cluster PSA
Restricted and Kyverno, backed by envelope RBAC.**

The framework security boundary is:

| Control | Primary enforcement | Defense in depth / early feedback |
| --- | --- | --- |
| PSS Restricted Pod fields | PSA Restricted namespace labels | Golden chart defaults and tenant CI render checks |
| `readOnlyRootFilesystem` | Kyverno validate policy | Golden chart defaults and tenant CI render checks |
| `automountServiceAccountToken=false` | Kyverno validate policy | Golden chart defaults and tenant CI render checks |
| Default-deny ingress and egress | Kyverno generate policy on namespace creation | Chart fixtures and integration tests |
| Resource quota and container defaults | Rancher project/namespace quota and native Kubernetes quota/limits where needed | Terraform validation and OPA on visible envelope |
| Image registry allowlist, digest, and signature verification | Kyverno image verification | Terraform variable validation for digest references and tenant CI |
| Kind allowlist and dangerous field restrictions | Kyverno validate policy | Reconcile Role allows only approved object kinds |
| Tenant-created Secrets, RBAC, CRDs, privileged kinds | Kyverno deny policy | Reconcile Role excludes those API groups and resources |
| Raw secret values | ADR-repo/0004 Vault reference contract | Terraform variable validation and chart policy checks |

The tenant-repository Layer 1 gate will render the local chart with
`helm template`, then run schema and policy checks such as kubeconform,
conftest, and `kyverno apply`. The in-cluster Layer 2 gate is authoritative and
must reject or clamp unsafe output even if Layer 1 is bypassed.

The Kyverno policy set must include an allowed-kinds and dangerous-fields
restriction for arbitrary tenant charts. It must deny tenant-created RBAC,
Secrets, CRDs, service account token mounting except the approved escape hatch,
`Service` type `LoadBalancer` or `NodePort`, hostPath, host namespaces,
privileged containers, disallowed capabilities, writable root filesystems, and
missing required resource limits. The chart reconcile identity must be bound to
a Kubernetes Role or equivalent Rancher-scoped permission set that can only
reconcile the allowed namespaced workload kinds.

## Pros and Cons of the Options

### Option 1: Template-time gate plus PSA, Kyverno, and envelope RBAC

- **Good, because** tenant pull requests receive fast feedback before apply.
- **Good, because** admission sees every live Kubernetes API request regardless
  of which tool produced it.
- **Good, because** PSA handles standardized Pod hardening while Kyverno covers
  non-Pod kinds, supply chain, namespace defaulting, and fields outside PSA.
- **Good, because** RBAC and Kyverno fail closed in different parts of the
  system.
- **Bad, because** it requires policy authoring, fixture charts, and negative
  integration tests to keep the boundary honest.
- **Bad, because** admission failures can be more complex for tenants to
  interpret than Terraform validation failures.

### Option 2: Terraform plan OPA only

- **Good, because** the existing scaffold already has OPA-on-plan tooling.
- **Good, because** it gives early feedback before apply.
- **Bad, because** `helm_release` does not model every rendered Kubernetes
  object as a normal Terraform resource in plan JSON.
- **Bad, because** it misses changes introduced by kubectl, Rancher UI, future
  GitOps controllers, or provider behavior outside Terraform's visible inputs.

### Option 3: PSA Restricted only

- **Good, because** it is built into Kubernetes and implements a well-known Pod
  hardening baseline.
- **Good, because** it catches critical Pod-level risks such as privilege
  escalation, hostPath, non-root, seccomp, and capabilities.
- **Bad, because** Kubernetes documents that PSA enforce mode applies to
  resulting Pods, not workload resources.
- **Bad, because** it does not restrict tenant-created RBAC, CRDs, Secrets,
  Service type, image registry and signature policy, default NetworkPolicy, or
  read-only root filesystem.

### Option 4: Kyverno only

- **Good, because** Kyverno can validate, mutate, generate, and verify images
  across Kubernetes resources.
- **Good, because** it can cover the arbitrary-chart constraints PSA does not.
- **Bad, because** it would discard a standardized built-in Pod Security
  baseline that Kubernetes already provides.
- **Bad, because** custom policy-only implementations can drift from upstream
  Pod Security Standards unless every field is carefully mirrored.

### Option 5: Human chart review only

- **Good, because** a reviewer can understand application intent and spot
  context-specific risks.
- **Bad, because** review alone does not enforce anything at runtime.
- **Bad, because** a chart can drift after review if the boundary is not
  expressed as executable policy.

## Confirmation

1. Tenant template CI MUST render the tenant chart and run schema and policy
   checks before any apply path.
2. Every tenant namespace MUST be labeled for Pod Security Admission
   `enforce=restricted`, with version pinning chosen by the implementation.
3. Kyverno policies MUST deny dangerous kinds and fields not covered by PSA.
4. Kyverno MUST generate default-deny NetworkPolicies or an equivalent default
   network isolation resource on tenant namespace creation.
5. The chart reconcile identity MUST be scoped to only the object kinds a tenant
   chart is allowed to manage.
6. OPA-on-plan MUST remain limited to visible Terraform envelope and input
   policy unless a later ADR introduces a safe rendered-manifest plan model.
7. CI MUST include compliant and hostile fixture charts that prove accepted and
   rejected behavior.

## Consequences

### Positive

- The security boundary is enforced in the cluster where all producers converge.
- Tenant developers get early, localizable chart feedback in pull requests.
- The model scales from simple golden-chart workloads to arbitrary tenant-owned
  charts.

### Negative

- The framework must maintain policy fixtures and integration tests, not just
  Terraform tests.
- Some policy failures will be admission-time errors surfaced through Helm,
  which requires careful tenant-facing documentation.
- Kyverno policy authoring must avoid overbroad exceptions that would silently
  weaken the arbitrary-chart boundary.

### Neutral

- Terraform/OPA remains part of the quality gate, but it is intentionally scoped
  to the Terraform envelope rather than claiming to inspect every workload
  object.
- The golden chart starter is hardened, but it is a convenience baseline rather
  than the sole enforcement mechanism.

## Assumptions

1. Kyverno will be installed and healthy before tenant releases are applied.
2. The cluster Kubernetes version supports Pod Security Admission and the
   Restricted Pod Security Standards needed by this framework.
3. A CNI that enforces Kubernetes NetworkPolicy or an equivalent network policy
   implementation is present.
4. The reconcile identity used by Helm can be restricted to the approved object
   kinds without blocking compliant tenant charts.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

- The Step 1 architecture-lock pull request introduces this ADR. Later PRs for
  Kyverno, PSA, OPA, tenant CI, and integration tests should append links here.

## Related ADRs

- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) chooses the local chart delivery model that makes the Layer 1 render gate possible.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines which tenant inputs and escape hatches the policies must allow.
- [ADR-repo/0004](0004-use-vault-references-and-vault-secrets-operator.md) defines the secret-handling control referenced by this boundary.
- [ADR-repo/0005](0005-validate-with-ephemeral-rancher-ci.md) defines how positive and negative policy behavior is proven.

## Compliance Notes

This ADR records the intended security architecture. The future evidence set
must include policy source, rendered fixture output, CI logs, and admission
negative-test results. The ADR itself supports review narratives for
least-privilege, policy-as-code, admission control, and supply-chain design, but
does not prove enforcement until the implementing PRs and CI evidence exist.
