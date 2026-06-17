# ADR-repo/0011: Treat Tenant tfvars as Untrusted Input

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-17                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-17 Step 32 implementation review, ADR-repo/0003, ADR-repo/0006, ADR-repo/0008, ADR-repo/0009, Terraform root module. |
| Informed       | Platform operators, tenant repository maintainers, framework maintainers, deploy-runner maintainers, security reviewers. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-17                              |

## TL;DR

The tenant `terraform.tfvars` file is untrusted input. The only tenant-supplied
Terraform variable surface is `all_workloads`; tenant-owned charts remain
allowed through the `chart_path` value defined inside that surface.

Any consuming deploy runner MUST reject platform-owned or unknown top-level
tfvars keys before `terraform plan`, and MUST inject provider authentication,
platform identity, caps, quota, and backend configuration out of band. Terraform
itself cannot enforce this source boundary because variable validation sees
only final values, and a CLI `-var-file` can override `TF_VAR_*` inputs.

## Context and Problem Statement

ADR-repo/0003 defines the tenant repository contract, and ADR-repo/0006 defines
the `all_workloads` list that lets one tenant tfvars file describe multiple
workloads. ADR-repo/0010 restored the simple path where a tenant can deploy a
common workload with the built-in chart and one tfvars file.

That simple path depends on a trust contract that was not explicit: the tenant
tfvars file crosses from the tenant side into the platform side and is not
trusted. If a deploy runner passes tenant tfvars with a CLI `-var-file` while
platform-owned values are injected with `TF_VAR_*`, Terraform's precedence rules
let the tenant file shadow the platform values. A tenant-set
`rancher_config`, `kubernetes_admin`, `scoped_deploy_kubernetes`,
`platform_caps`, `platform_resource_quota`, `cluster_id`, `project_name`, or
`project_description` could redirect provider authentication, raise caps or
quota, or reassign placement and identity.

Terraform configuration cannot tell whether a final variable value came from a
tenant file, an environment variable, or an operator file. A `validation {}`
block checks the value, not the source. The source boundary must therefore be
enforced by the runner that admits tenant input and assembles the Terraform
invocation.

## Decision Drivers

1. **Fixed platform posture.** Tenants must not be able to override platform
   authentication, identity, caps, quota, or backend behavior.
2. **Simple tenant experience.** The common path still uses one tfvars file for
   tenant workload input.
3. **Correct enforcement layer.** Source admission happens before Terraform
   evaluates variables, so the consuming runner owns it.
4. **Runner portability.** This repository is consumed by more than one
   infrastructure path, so the contract must not require a specific CI system.
5. **No false controls.** Documentation must not imply Terraform validation or
   retired plan OPA can prove variable provenance.

## Considered Options

1. Document the tenant tfvars file as untrusted input and require pre-plan
   runner admission of only the tenant variable surface.
2. Add Terraform variable validation to reject platform-owned variables.
3. Reintroduce OPA-on-plan to detect platform variable shadowing.
4. Accept tenant-provided platform variables as a documented advanced path.

## Decision Outcome

Chosen option: **Option 1, document the tenant tfvars file as untrusted input
and require pre-plan runner admission of only the tenant variable surface.**

The tenant tfvars file may set only the top-level Terraform variable
`all_workloads`. The runner MUST reject any platform-owned or unknown top-level
key before `terraform plan`. Platform-owned inputs include provider auth,
scoped deploy credentials, admin Kubernetes credentials, cluster and project
identity, platform caps, platform quota, and backend configuration.

The runner MUST inject platform-owned values out of band. Provider
authentication is supplied through runner-owned `TF_VAR_*` inputs that do not
come from tenant tfvars. Non-secret platform envelope values MAY be supplied
through a runner-owned var file placed after the tenant var file in the
Terraform CLI argument order, so runner-owned values win precedence. Backend
settings are supplied through backend config or equivalent runner-owned
initialization inputs, not tenant tfvars.

This is a pre-plan source contract. It is explicitly distinct from
ADR-repo/0008's retired static OPA-on-plan decision: this contract does not use
plan JSON, does not inspect rendered Helm objects, and does not reintroduce an
OPA plan gate. The framework Terraform module still validates final values for
shape and caps, but the consuming runner is responsible for source admission.

## Pros and Cons of the Options

### Option 1: Document the runner-owned source contract

- **Good, because** it records the real trust boundary without adding a false
  Terraform control.
- **Good, because** any consuming runner can implement the same pre-plan
  admission rule.
- **Good, because** the tenant experience stays one tfvars file for workload
  input.
- **Bad, because** correctness depends on every conforming runner implementing
  the admission rule before production deploys.

### Option 2: Add Terraform validation

- **Good, because** validation already exists in the module.
- **Bad, because** Terraform validation cannot distinguish tenant-sourced
  values from platform-sourced values.
- **Bad, because** it would create confidence in a control that cannot enforce
  the premise.

### Option 3: Reintroduce OPA-on-plan

- **Good, because** OPA is familiar in the template family.
- **Bad, because** ADR-repo/0008 retired static plan OPA for this framework.
- **Bad, because** plan JSON shows final values and resource changes, not the
  source of each root variable.
- **Bad, because** it still cannot see the Helm-rendered workload boundary that
  motivated the retirement.

### Option 4: Accept tenant platform variables

- **Good, because** it requires no runner admission work.
- **Bad, because** tenants could redirect provider authentication, raise caps
  or quota, or change placement and identity.
- **Bad, because** it contradicts the fixed, non-overridable platform security
  posture.

## Confirmation

1. Tenant tfvars is untrusted input crossing the tenant-to-platform boundary.
2. `all_workloads` is the sole tenant-supplied Terraform variable surface.
3. Tenant-owned charts remain supported only through values inside
   `all_workloads`, especially explicit `chart_path`.
4. Platform-owned auth, identity, caps, quota, and backend values MUST NOT be
   accepted from tenant tfvars.
5. A conforming runner MUST reject platform-owned or unknown top-level keys
   before Terraform plan/apply.
6. Terraform validation and plan OPA are not source-provenance controls.

## Consequences

### Positive

- The one-tfvars tenant path now has an explicit trust boundary.
- Platform-owned provider and envelope inputs remain non-overridable by
  contract.
- Future runner implementations have a clear pre-plan admission requirement.

### Negative

- This ADR does not provide an enforcement implementation by itself.
- A non-conforming runner can still misassemble Terraform inputs and weaken the
  platform contract.

### Neutral

- The Terraform module behavior is unchanged.
- The two-layer render and admission security model is unchanged.
- ADR-repo/0003 and ADR-repo/0006 remain the references for the tenant surface.

## Assumptions

1. Consuming deploy runners can parse the tenant tfvars before Terraform plan.
2. Platform operators can inject auth, identity, caps, quota, and backend
   settings through runner-owned channels.
3. Tenant-owned chart support remains available through explicit
   `all_workloads[*].chart_path`.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

- The Step 32 pull request records the untrusted tfvars contract in ADRs and
  reference docs, and updates the `rancher_config` Terraform description.

## Related ADRs

- [ADR-repo/0003](0003-define-tenant-repo-contract.md) defines the tenant
  repository contract.
- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the
  `all_workloads` tenant variable surface.
- [ADR-repo/0008](0008-retire-static-terraform-plan-opa.md) explains why this
  contract is not enforced by static plan OPA.
- [ADR-repo/0009](0009-split-platform-envelope-from-tenant-deploy-and-scope-the-reconcile-identity.md)
  requires the scoped deploy credential to stay out of raw tenant tfvars.
- [ADR-repo/0010](0010-default-to-built-in-platform-workload-chart.md) records
  the built-in chart default for the simple one-tfvars path.

## Compliance Notes

This ADR is governance evidence for consuming deploy runners. It does not add a
Terraform source-provenance gate, a workflow implementation, a chart change, or
an OPA-on-plan policy. Runners that consume this framework must implement the
pre-plan tfvars admission rule before trusted tenant deployment.
