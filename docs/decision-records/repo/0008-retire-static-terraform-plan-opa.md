# ADR-repo/0008: Retire Static Terraform Plan OPA

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-12                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | Step 11 offline plan experiment, ADR-repo/0002, ADR-repo/0005, Terraform test suite. |
| Informed       | Framework maintainers, policy authors, CI maintainers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-12                              |

## TL;DR

This repository retires static OPA-on-Terraform-plan policy. The inherited
AWS-shaped `terraform_plan` Rego package is removed, and `make opa-plan` remains
only as an ADR-backed compatibility target that reports the retirement.

The visible Rancher envelope invariants are already covered by native Terraform
validation and mocked `terraform test` plan assertions. The workload security
boundary remains tenant chart render checks plus in-cluster Pod Security
Admission and Kyverno, as defined by [ADR-repo/0002](0002-use-two-layer-tenant-security.md).

## Context and Problem Statement

The generic Terraform scaffold included a `terraform_plan` OPA package for AWS
resources. That policy asserted AWS S3, IAM, security group, stateful-resource,
and tag invariants that do not exist in this Rancher framework.

Step 11 tested whether the current module can run a static plan offline with
dummy Rancher and Helm inputs. The direct static-stage command failed before
any Rancher or Helm API call:

```powershell
C:\tmp\tf1154\terraform.exe -chdir=terraform plan -input=false `
  -out=../.tmp/opa-plan/offline-feasibility.tfplan `
  -var-file=terraform.tfvars.example
```

Result:

```text
Error: Backend initialization required
Reason: Initial configuration of the requested backend "s3"
```

The same module files were also tested in a temporary copy with `backend.tf`
and `backend.hcl` excluded and a tiny local chart fixture present. That plan
did succeed with dummy Rancher and Helm inputs:

```powershell
C:\tmp\tf1154\terraform.exe -chdir=.tmp/offline-provider-plan-module plan `
  -input=false `
  -out=../opa-plan/offline-provider-feasibility.tfplan `
  -var-file=terraform.tfvars
```

Result: `Plan: 6 to add, 0 to change, 0 to destroy.`

This proves the providers configure lazily enough for an offline plan when the
backend and chart-path issues are artificially removed. It also proves that
keeping OPA-on-plan in this repository would require a special static-plan
workspace that bypasses the committed backend and carries a synthetic chart.

## Decision Drivers

1. **Truthful gates.** The quality gate must not silently skip a missing AWS
   fixture or pretend to enforce workload policy through opaque Helm plan data.
2. **No artificial static workspaces.** Static CI should avoid maintaining a
   second copy of the Terraform module only to remove the backend and add a
   synthetic chart.
3. **Avoid redundant policy.** The plan-visible envelope is already asserted by
   `terraform test`.
4. **Keep the real boundary clear.** Helm-rendered workload objects are
   validated by tenant render gates and admission, not Terraform plan JSON.
5. **Preserve command compatibility.** The template-family `opa-plan` target
   should still exist and explain why it is intentionally retired here.

## Considered Options

1. Retire static OPA-on-plan for this repository.
2. Implement Rancher envelope OPA-on-plan using a temporary backend-free module
   copy and synthetic chart fixture.
3. Keep the inherited AWS plan policy skipped until later.
4. Move OPA-on-plan to the Phase 5 ephemeral Rancher integration stage.

## Decision Outcome

Chosen option: **Option 1, retire static OPA-on-plan for this repository.**

The repository will:

- remove `policies/opa/terraform_plan.rego`;
- remove `policies/opa/terraform_plan_test.rego`;
- keep `make opa-plan` and `python tools/verify.py opa-plan` as documented
  no-op compatibility targets;
- keep envelope assertions in mocked `terraform test` files;
- keep source/repository policy in `policies/opa/repo_hygiene.rego`;
- keep workload policy in the future tenant chart render gate and admission
  policy set.

Future work may reintroduce plan-level OPA only through a new ADR that names a
non-redundant invariant and avoids claiming coverage over Helm-rendered
workload objects.

## Pros and Cons of the Options

### Option 1: Retire static OPA-on-plan

- **Good, because** it removes stale AWS policy from a Rancher repository.
- **Good, because** it keeps the quality gate honest about what is enforced.
- **Good, because** the repo already has direct plan assertions for PSA labels,
  quotas, Helm namespace ownership, CRD skipping, and fan-out behavior.
- **Bad, because** this derivative no longer mirrors the template's plan-policy
  package one-for-one.

### Option 2: Implement Rancher envelope OPA-on-plan

- **Good, because** it would provide an independent check over Terraform plan
  JSON for the visible envelope.
- **Bad, because** it duplicates existing `terraform test` assertions.
- **Bad, because** the current committed backend prevents direct static-stage
  planning with `-backend=false`.
- **Bad, because** it requires a synthetic chart fixture before the golden
  chart phase exists.

### Option 3: Keep the inherited AWS policy skipped

- **Good, because** it requires no immediate implementation work.
- **Bad, because** it leaves stale AWS assertions and an undocumented missing
  fixture in the Rancher repo.
- **Bad, because** it does not satisfy the Step 11 requirement to settle the
  gate honestly.

### Option 4: Move OPA-on-plan to ephemeral Rancher integration

- **Good, because** integration has real provider context.
- **Bad, because** admission and Helm behavior are better tested directly in
  integration than through a second OPA pass over plan JSON.
- **Bad, because** it still cannot make plan JSON authoritative for
  Helm-rendered workload resources.

## Confirmation

1. `make opa-plan` MUST print an explicit retirement message and exit
   successfully.
2. `policies/opa/` MUST NOT contain AWS-shaped Terraform plan policy.
3. Rancher envelope invariants MUST remain covered by Terraform variable
   validation and mocked `terraform test` assertions.
4. Workload security MUST remain covered by the future tenant render gate and
   the authoritative PSA/Kyverno admission boundary.
5. Documentation MUST NOT claim that OPA-on-plan enforces Rancher or workload
   invariants in this repository.

## Consequences

### Positive

- The policy suite now reflects the actual Rancher framework.
- The command surface remains stable while the retired target explains itself.
- The documentation no longer overstates what Terraform plan JSON can prove.

### Negative

- Reviewers who expect a `terraform_plan` package from the inherited scaffold
  must follow this ADR to understand why it is absent.
- A future non-redundant plan policy would need a fresh ADR and implementation.

### Neutral

- This does not change Terraform resources, variable validation, provider
  pins, Helm delivery, or admission-policy scope.
- Phase 5 still validates the real Rancher and Kubernetes mechanism through
  disposable integration tests rather than static OPA-on-plan.

## Assumptions

1. The existing Terraform tests remain blocking in CI.
2. The future Phase 2 and Phase 3 work will add chart render policy and
   Kyverno/PSA enforcement tests.
3. The empty S3 backend remains a deployment-time backend declaration, while
   local static gates continue to initialize with `-backend=false`.

## Supersedes

- The inherited Terraform scaffold's AWS-shaped `terraform_plan` policy package
  for this repository.
- The OPA-on-plan feedback expectation in [ADR-repo/0002](0002-use-two-layer-tenant-security.md)
  for this repository's static quality gate.

## Superseded by

None (current).

## Implementing PRs

- The Step 11 pull request introduces this ADR, removes the inherited AWS plan
  policy, and documents the `opa-plan` compatibility target.

## Related ADRs

- [ADR-repo/0002](0002-use-two-layer-tenant-security.md) defines the
  tenant-render and admission security boundary.
- [ADR-repo/0005](0005-validate-with-ephemeral-rancher-ci.md) defines the
  future disposable Rancher integration evidence.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the
  multi-workload Terraform contract covered by mocked Terraform tests.

## Compliance Notes

Evidence for this decision is the Step 11 offline plan experiment, the
existing mocked Terraform test suite, and the removal of the inherited AWS
`terraform_plan` package. The future evidence set for workload security remains
the chart render gate, Kyverno/PSA policy source, and ephemeral Rancher
integration logs.
