# ADR-repo/0005: Validate with Ephemeral Rancher CI

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-11 owner interview, Rancher installation documentation, k3d documentation, Kyverno CLI documentation, Terraform framework quality gates. |
| Informed       | Framework maintainers, tenant template maintainers, CI maintainers, security reviewers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-11                              |

## TL;DR

CI must validate this framework against a disposable full Rancher environment:
a Rancher management cluster, an ephemeral downstream cluster, the platform
baseline, compliant and hostile fixture charts, real Terraform plan/apply of
the mechanism, and negative tests proving hostile workloads are denied or
clamped. Static validation remains the fast first stage, but synthetic-only
checks are not enough for the Rancher-specific framework.

CI must not depend on long-lived external Rancher credentials. The Rancher
environment is created inside the runner, used for the test, destroyed, and
treated as disposable.

## Context and Problem Statement

The inherited template ADR keeps the reference framework credential-free and
synthetic. ADR-repo/0001 supersedes that only for this repository's future
Rancher implementation and integration-validation scope. A real Rancher PaaS
framework cannot be proven only with static HCL because the important behavior
crosses Terraform providers, Rancher APIs, Helm rendering, Kubernetes
admission, Kyverno controllers, PSA labels, and namespace-scoped RBAC.

Rancher's Helm CLI quick start documents Rancher installation onto Kubernetes
with cert-manager and the Rancher Helm chart, and notes Rancher manages
Kubernetes clusters remotely
(https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli).
k3d documents that it runs k3s in Docker and makes it easy to create
single-node and multi-node k3s clusters for local development on Kubernetes
(https://k3d.io/stable/). Kyverno documents that its CLI can apply policies to
resource files before cluster admission
(https://kyverno.io/docs/kyverno-cli/reference/kyverno_apply/).

These sources support a two-stage CI topology: fast static render and policy
checks first, then a disposable Rancher integration environment to prove real
provider and admission behavior.

## Decision Drivers

1. **Mechanism proof.** The framework must prove the actual Rancher, Helm, and
   admission path, not only lint static files.
2. **No long-lived external credentials.** CI must be clone-and-run in the sense
   that it does not require a standing Rancher token or hosted test cluster.
3. **Negative evidence.** Security claims must be backed by hostile fixture
   failures, not only compliant happy paths.
4. **Cost and cleanup.** Test infrastructure should be disposable and destroyed
   by the run that created it.
5. **Stepwise speed.** Static checks should catch most errors before the slower
   Rancher integration stage.

## Considered Options

1. Static render checks plus disposable full Rancher integration CI.
2. Static Terraform and Helm checks only.
3. Integration tests against a long-lived shared Rancher cluster.
4. Unit tests with mocked provider responses only.
5. Manual pre-release validation by an operator.

## Decision Outcome

Chosen option: **Option 1, static render checks plus disposable full Rancher
integration CI.**

The CI topology is:

1. **Static stage.**
   - Run Terraform fmt, init with `-backend=false`, validate, tests, TFLint,
     terraform-docs drift detection, docs checks, and OPA policy tests.
   - Run `helm lint` and `helm template` on the golden chart starter and
     fixture charts.
   - Run schema and policy checks on rendered manifests, including kubeconform,
     conftest, and `kyverno apply`.
   - Assert the compliant fixture passes and the hostile fixture fails the
     relevant static policies.
2. **Ephemeral Rancher integration stage.**
   - Start disposable Kubernetes clusters, such as k3d or k3s clusters, for
     Rancher management and downstream validation.
   - Install cert-manager and Rancher using Helm.
   - Bootstrap Rancher, register or import the downstream cluster, and install
     the platform baseline: PSA labels/templates, Kyverno, Vault Secrets
     Operator, ingress, CRDs, and policy manifests.
   - Run the framework module with compliant and hostile fixture charts.
   - Prove the compliant chart deploys.
   - Prove hostile fixture cases are denied or clamped, including privileged
     Pods, `Service` type `LoadBalancer` or `NodePort`, hostPath, missing
     resource limits, writable root filesystem, illegal service account token
     mounts, tenant-created RBAC, tenant-created Secrets, and tenant-created
     CRDs.
   - Destroy the environment and verify cleanup.

The integration stage validates the mechanism. It does not deploy a real tenant
or contact a long-lived NWarila Rancher cluster.

## Pros and Cons of the Options

### Option 1: Static checks plus disposable full Rancher CI

- **Good, because** it proves Terraform provider behavior, Rancher envelope
  creation, Helm release behavior, and admission enforcement together.
- **Good, because** no standing Rancher token or external test cluster is
  needed.
- **Good, because** hostile fixtures turn security claims into executable
  evidence.
- **Bad, because** it is slower and more complex than static-only CI.
- **Bad, because** Rancher-in-Docker networking, startup timing, and cleanup
  require careful engineering.

### Option 2: Static Terraform and Helm checks only

- **Good, because** it is fast and deterministic.
- **Bad, because** it cannot prove Rancher API behavior or live admission
  denial.
- **Bad, because** it would leave the most important runtime security boundary
  untested.

### Option 3: Long-lived shared Rancher cluster

- **Good, because** it is closer to a stable production-like environment.
- **Bad, because** it requires long-lived credentials and cleanup discipline.
- **Bad, because** cross-run state can hide or create failures.
- **Bad, because** it violates the no-long-lived-external-credentials principle.

### Option 4: Mocked provider responses

- **Good, because** it is fast and cheap.
- **Bad, because** mocks can confirm only what the test author already encoded.
- **Bad, because** admission, Rancher timing, Helm behavior, and provider
  compatibility are exactly the pieces that need real integration proof.

### Option 5: Manual validation

- **Good, because** an operator can adapt to unusual failures.
- **Bad, because** it is not repeatable, reviewable, or sufficient for every
  pull request.
- **Bad, because** manual negative tests are easy to skip under time pressure.

## Confirmation

1. The future CI workflow MUST keep a fast static stage and a slower disposable
   Rancher integration stage.
2. CI MUST NOT require a long-lived external Rancher token, kubeconfig, or
   tenant credential for normal pull request validation.
3. CI MUST test both compliant and deliberately hostile fixture charts.
4. The hostile fixture suite MUST include negative tests for dangerous kinds and
   fields listed in ADR-repo/0002.
5. The integration stage MUST destroy disposable infrastructure and verify
   cleanup before completing.
6. CI logs and artifacts SHOULD be sufficient for a reviewer to see which
   security claim was proven by each fixture.

## Consequences

### Positive

- The framework can make fact-backed claims about Rancher, Helm, and admission
  behavior.
- Security controls are tested in the same place they matter: the live API
  server and admission chain.
- CI remains self-contained and avoids long-lived external credentials.

### Negative

- CI will be heavier than the inherited synthetic framework.
- The integration harness will need robust retry, timeout, logging, and cleanup
  behavior.
- Local developer machines may not have every integration tool installed, so
  some validation will lean on CI.

### Neutral

- The static stage remains the default fast feedback loop.
- The integration harness tests the framework mechanism with fixtures, not real
  tenant workloads.

## Assumptions

1. GitHub Actions runners, or any future CI runner, can run the required
   containerized Kubernetes and Rancher tooling.
2. Rancher, cert-manager, Kyverno, VSO, Helm, and Terraform versions can be
   pinned and updated through normal dependency review.
3. The owner accepts slower integration checks for security-relevant PRs.

## Supersedes

None directly. ADR-repo/0001 records the repo-scope supersession of
ADR-template/0002 for real-provider and disposable-Rancher integration scope.

## Superseded by

None (current).

## Implementing PRs

- The Step 1 architecture-lock pull request introduces this ADR. Later PRs for
  static chart gates, policy fixtures, and the Rancher integration harness
  should append links here.

## Related ADRs

- [ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md) is the inherited synthetic validation baseline this repository narrows through ADR-repo/0001.
- [ADR-repo/0001](0001-adopt-rancher2-envelope-and-helm-release-local-chart.md) chooses the real-provider delivery path that requires integration proof.
- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the controls that hostile fixture charts must test.
- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant contract the fixture charts must exercise.
- [ADR-repo/0004](0004-use-vault-references-and-vault-secrets-operator.md) defines the secret-reference behavior the platform baseline must test.

## Compliance Notes

This ADR supports evidence narratives for security testing, change validation,
least privilege, and temporary test environments. The eventual proof will be CI
configuration, pinned tool versions, logs, fixture manifests, and test artifacts
showing compliant success, hostile denial, and cleanup.
