# ADR-repo/0004: Use Vault References and Vault Secrets Operator

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-11 owner interview, Terraform sensitive-data documentation, Helm storage documentation, Vault Secrets Operator documentation. |
| Informed       | Tenant maintainers, framework maintainers, platform operators, security reviewers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-11                              |

## TL;DR

Tenants pass Vault references, not secret values, through `terraform.tfvars` or
chart values. The Vault Secrets Operator materializes those referenced secrets
inside the cluster as Kubernetes Secrets, or through an approved direct-mount
path when that is later implemented. Terraform and Helm must not receive raw
application secret values.

## Context and Problem Statement

Terraform and Helm are poor places to pass raw application secrets. HashiCorp
documents that if secret values are placed directly in Terraform configuration,
Terraform stores those secrets in state and plan files. It also documents that
even `sensitive` values are still stored in state and plan files for anyone who
can access those files
(https://developer.hashicorp.com/terraform/language/manage-sensitive-data).

Helm also stores release information. Helm's advanced documentation says that,
by default, release information is stored in Kubernetes Secrets in the release
namespace, and that release information includes chart contents and values files
which might contain sensitive data such as passwords, private keys, and other
credentials
(https://helm.sh/docs/topics/advanced/). The Helm provider also exposes
release metadata, including `metadata.values`, as read-only state
(https://raw.githubusercontent.com/hashicorp/terraform-provider-helm/main/docs/resources/release.md).

The Vault Secrets Operator (VSO) lets Pods consume Vault secrets natively from
Kubernetes Secrets. HashiCorp documents that VSO watches supported CRDs,
synchronizes from supported Vault secret sources to Kubernetes Secrets, writes
source secret data to the destination Secret, and replicates source changes over
the destination lifetime
(https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso).

## Decision Drivers

1. **State safety.** Terraform state and plan files must not contain tenant
   application secret values.
2. **Helm metadata safety.** Helm release records and provider metadata must not
   become a secondary secret store for tenant values.
3. **Runtime-native consumption.** Workloads should consume secrets through
   Kubernetes-native references once admitted to the cluster.
4. **Rotation.** Secret rotation should be handled by Vault and VSO rather than
   requiring Terraform or Helm value changes for every secret update.
5. **Tenant clarity.** Tenants need a simple reference contract rather than
   credentials embedded in tfvars.

## Considered Options

1. Tenants pass Vault references; VSO materializes secrets in-cluster.
2. Tenants pass raw secret values through Terraform variables.
3. Tenants pass raw secret values through Helm chart values.
4. Tenants create Kubernetes Secret manifests in their chart.
5. Tenants manage secrets manually with kubectl or Rancher UI.

## Decision Outcome

Chosen option: **Option 1, tenants pass Vault references and VSO materializes
secrets in-cluster.**

The framework contract is:

- `terraform.tfvars` may contain structured Vault references, never raw secret
  values.
- Chart values may reference the names and keys of VSO-managed Kubernetes
  Secrets, never raw secret values.
- Tenant charts may include approved VSO custom resources or equivalent
  platform-defined reference objects once those are implemented.
- Terraform validation and policy must reject inputs that look like raw secret
  values.
- Kyverno must reject tenant-created raw Kubernetes Secret objects unless a
  later ADR defines a narrow platform-owned exception.

The platform remains responsible for Vault auth configuration, VSO installation
and health, allowed Vault paths, namespace scoping, and rotation behavior.

## Pros and Cons of the Options

### Option 1: Vault references plus VSO

- **Good, because** raw values do not need to enter Terraform plan or state.
- **Good, because** raw values do not need to enter Helm values or release
  metadata.
- **Good, because** VSO supports synchronization and drift remediation from
  Vault sources to Kubernetes Secrets.
- **Good, because** rotation can happen without requiring a Terraform variable
  change for each new secret value.
- **Bad, because** the cluster must run and monitor VSO.
- **Bad, because** Vault auth and path scoping become part of the platform
  operational boundary.

### Option 2: Raw secret values through Terraform variables

- **Good, because** it is simple for tenants to understand.
- **Bad, because** Terraform documentation explicitly warns that direct secret
  values are stored in state and plan files.
- **Bad, because** the module would need to treat plan artifacts and local state
  as high-risk secret material.

### Option 3: Raw secret values through Helm values

- **Good, because** Helm charts commonly support values for application
  settings.
- **Bad, because** Helm release information includes chart and values content
  and may contain credentials.
- **Bad, because** Helm provider state can expose release metadata.

### Option 4: Tenant-created Kubernetes Secrets

- **Good, because** Kubernetes workloads already know how to consume Secrets.
- **Bad, because** the secret values still live in Git, rendered manifests,
  tenant CI logs, Helm release data, or Terraform inputs before reaching the
  cluster.
- **Bad, because** tenant-created Secrets weaken the arbitrary-chart kind
  restriction in ADR-repo/0002.

### Option 5: Manual secret management

- **Good, because** it avoids storing raw secrets in Terraform variables.
- **Bad, because** it is not reproducible or reviewable.
- **Bad, because** manual changes drift from Git and complicate rotation and
  incident response.

## Confirmation

1. Terraform variables MUST accept only Vault references for application
   secrets.
2. Terraform validation and OPA MUST reject raw secret-looking values in the
   tenant input surface.
3. The chart policy gate MUST reject raw Kubernetes Secret manifests in tenant
   charts unless an explicitly approved platform-owned exception exists.
4. VSO CRDs and controller installation MUST be part of the platform baseline
   before tenant secret references are considered production-ready.
5. Documentation MUST warn that Terraform `sensitive` redaction alone is not
   enough because sensitive values are still stored in state and plan files.

## Consequences

### Positive

- Terraform and Helm are not used as tenant application secret transport.
- Vault remains the source of truth for secret values and rotation.
- Tenant chart values can stay reviewable without containing secret material.

### Negative

- VSO becomes a required platform dependency.
- Tenant onboarding must include allowed Vault reference formats and path
  scoping.
- Local and CI tests need fixtures that prove raw secret values are rejected
  without requiring real secret material.

### Neutral

- Kubernetes Secrets may still exist as the in-cluster destination object. This
  ADR is about keeping raw values out of Terraform, Helm, Git, and tenant
  inputs, not about eliminating Kubernetes Secrets entirely.

## Assumptions

1. NWarila will operate Vault and VSO for hosted tenant clusters.
2. Tenants can be issued Vault paths or references without seeing secret values
   in Git.
3. The platform can restrict which Vault references a tenant namespace is
   allowed to use.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

- The Step 1 architecture-lock pull request introduces this ADR. Later PRs for
  variable validation, VSO manifests, golden chart integration, and policy tests
  should append links here.

## Related ADRs

- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) includes raw-secret
  denial in the tenant chart security boundary.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) includes Vault
  references in the tenant tfvars surface.
- [ADR-repo/0005](0005-validate-with-ephemeral-rancher-ci.md) defines how the
  secret-reference path is validated.

## Compliance Notes

This ADR supports evidence narratives for secret minimization, state-file risk
reduction, and runtime secret synchronization. Future compliance evidence must
include the variable schema, policy tests rejecting raw secrets, VSO deployment
configuration, Vault auth and path scoping, and rotation test results.
