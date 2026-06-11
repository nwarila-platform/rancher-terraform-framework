# ADR-repo/0001: Use Synthetic Providers for the Reference Framework

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-02                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (sole portfolio maintainer) |
| Consulted      | ADR-template/0002 (credential-free constraint). |
| Informed       | Derivative framework maintainers via template README. |
| Reversibility  | High                                    |
| Review-by      | N/A (Accepted)                          |
| Last reviewed  | 2026-06-02                              |

## TL;DR

The reference Terraform module in this repository uses five synthetic providers — `null`, `random`, `local`, `time`, and `tls` — as the implementation substrate. These providers require no credentials, cost nothing, and together exercise every major Terraform language pattern a derivative framework will use with a real provider.

## Context and Problem Statement

ADR-template/0002 established that this reference framework must be credential-free and cost-free. That constraint rules out every real cloud or SaaS provider. The remaining question is which synthetic providers to use and why.

An under-specified choice (such as using only `null`) would leave gaps: no sensitive-output handling, no time-driven lifecycle, no iterative resource expansion across multiple types. An over-specified choice (many providers, complex interdependencies) would obscure the patterns the template is meant to demonstrate.

This ADR records the specific provider set and the rationale for each member.

## Decision Drivers

1. **Pattern coverage.** The provider set must collectively exercise dynamic blocks, `for_each` on composite-keyed maps, `count`-gated resources, splat-on-optional, sensitive outputs, time-driven rotation, and `terraform test` with real `apply`.
2. **Stability.** Each provider must have a near-zero breaking-change rate so the template does not need frequent unplanned updates.
3. **Offline-safe.** All five providers work without network access once initialized, so CI does not depend on provider registry uptime beyond `terraform init`.
4. **Official provenance.** All providers must be published by HashiCorp on the public registry, avoiding third-party supply-chain risk in a portfolio-wide reference.
5. **No credentials.** No provider in the set may require API tokens, cloud accounts, or secrets.

## Considered Options

1. Five HashiCorp synthetic providers: `null`, `random`, `local`, `time`, `tls`.
2. Single `null` provider only.
3. `null` + `local` only.
4. AWS provider with mock/localstack backend.
5. Custom in-house test provider.

## Decision Outcome

Chosen option: **Option 1, five HashiCorp synthetic providers.**

Each provider covers a distinct dimension:

| Provider | Why it is included |
| -------- | ------------------ |
| `null`   | Baseline lifecycle resource. Proves `triggers`-based replacement and `for_each` expansion of lifecycle hooks. |
| `random` | Stable random strings and pets. Proves the single-optional sub-object pattern and `keeper`-driven rotation without time drift in tests. |
| `local`  | Writes real files to disk. Proves iterative-children resource expansion via `for_each` on a flattened manifest map, and produces artifacts that tests can assert against. |
| `time`   | Rotating resource tied to a `rotation_days` input. Proves time-driven lifecycle patterns and the filtered `for_each` (0 or 1 resource per environment). |
| `tls`    | Self-signed certificate per environment. Proves the single-optional sub-object pattern at the certificate level, sensitive output handling for private keys, and the `dynamic "subject"` splat-on-optional block. |

Together these five cover every dynamic-block pattern demonstrated in the template and produce real Terraform state that `terraform test` can assert against. Each is an official HashiCorp provider with a near-zero breaking-change history.

## Pros and Cons of the Options

### Option 1: Five synthetic providers

- **Good, because** pattern coverage is complete without any real provider semantics cluttering the examples.
- **Good, because** all five are stable, credential-free, and offline-safe after init.
- **Good, because** CI remains deterministic: no external API calls, no flake from service outages.
- **Bad, because** the set does not prove any real provider API, quota model, or IAM pattern. Derivative frameworks must add those tests themselves.

### Option 2: Single `null` provider

- **Good, because** minimal dependency surface.
- **Bad, because** no sensitive-output demonstration, no time-driven lifecycle, no file artifact assertions. Gaps in pattern coverage would force derivative frameworks to design from scratch.

### Option 3: `null` + `local` only

- **Good, because** smaller provider set than Option 1.
- **Bad, because** still missing sensitive-output handling (`tls`), time-driven rotation (`time`), and stable random-value generation (`random`).

### Option 4: AWS provider with localstack

- **Good, because** it would demonstrate a realistic cloud provider path.
- **Bad, because** localstack is a third-party tool, introduces container dependency, and the AWS provider has non-trivial breaking changes. Contradicts ADR-template/0002.

### Option 5: Custom in-house test provider

- **Good, because** maximum control over the provider surface.
- **Bad, because** significant ongoing maintenance cost, non-standard provenance, and no benefit over the existing official set for the patterns covered.

## Confirmation

1. `terraform/versions.tf` MUST list exactly these five providers at exact version pins.
2. `terraform test` MUST run successfully against `apply` without any credentials or network calls beyond `terraform init`.
3. Any addition to the provider set MUST be recorded as an update to this ADR with rationale for the new pattern it covers.
4. Derivative frameworks MUST replace this synthetic set with their real provider(s) and record the replacement decision in their own repo-tier ADR.

## Consequences

### Positive

- The template can be cloned and validated by anyone without accounts or secrets.
- Each provider covers a distinct language pattern, making the demo more legible.
- Official HashiCorp provenance keeps supply-chain risk low.

### Negative

- Real provider APIs, IAM models, quota behavior, and state-migration scenarios are not proven here. Derivative frameworks cannot infer cloud-specific correctness from this template.

### Neutral

- Renovate updates each provider pin through a reviewable PR. Exact pins mean no silent drift between init and apply.

## Assumptions

1. HashiCorp continues to publish these five providers on the public registry without breaking changes that force unplanned template updates.
2. Derivative frameworks accept that provider-specific correctness is their own responsibility to prove, not delegated to this template.
3. `terraform test` with `apply` against synthetic providers remains sufficient to exercise the lifecycle runner repos depend on.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

- The initial synthetic provider set was introduced alongside the credential-free constraint in the v1.0.0 readiness pass.

## Related ADRs

- [ADR-template/0001](../template/0001-pin-terraform-and-provider-versions-exactly.md) — exact version pinning for the providers selected here.
- [ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md) — the credential-free constraint that motivates this synthetic selection.

## Compliance Notes

None.
