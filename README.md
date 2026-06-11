# terraform-framework-template

[![CI](https://github.com/NWarila/terraform-framework-template/actions/workflows/ci.yaml/badge.svg)](https://github.com/NWarila/terraform-framework-template/actions/workflows/ci.yaml)
[![Security](https://github.com/NWarila/terraform-framework-template/actions/workflows/security.yaml/badge.svg)](https://github.com/NWarila/terraform-framework-template/actions/workflows/security.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/docs-architecture-informational)](docs/explanation/architecture.md)

A reference template for building Terraform framework repositories: the kind of
repo a platform team derives real cloud frameworks from. It ships the canonical
module shape, validation tooling, OPA policy, and release-evidence pipeline so a
new framework can be stood up by deriving from this template rather than
hand-rolling each piece.

## Prerequisites

Install the same external tools CI uses before running the full local gates:

- Terraform CLI 1.15.4
- TFLint 0.62.0
- terraform-docs 0.23.0
- OPA 1.10.0
- shellcheck
- bats

## Quickstart

```sh
make help
make setup
python tools/verify.py ci
python tools/verify.py integration
```

`python tools/verify.py ci` runs formatting, init, validate, TFLint, tests, OPA checks, and terraform-docs drift checks. `python tools/verify.py integration` builds an ephemeral workspace under `.tmp/ci/integration/` from `terraform/`, copies the single-environment example, and runs the Terraform-facing gates against that assembled module.

The complete gate inventory lives in [`docs/reference/quality-gates.md`](docs/reference/quality-gates.md).

## Patterns demonstrated

| Pattern | Where to look |
| --- | --- |
| Required + optional scalar variables with `optional(<type>, <default>)` | [`variables.tf`](terraform/variables.tf) inside `all_environments` |
| Custom validation rules (`condition`/`error_message`) | [`variables.tf`](terraform/variables.tf), validations on `all_environments` |
| Sensitive variables with operational-context descriptions | `variable "secret_seed"` in [`variables.tf`](terraform/variables.tf) |
| List-of-objects mega-variable with nested optionals | `manifests`, `lifecycle_hooks` in [`variables.tf`](terraform/variables.tf) |
| Single-optional sub-object (becomes splat-on-optional dynamic block in main.tf) | `rotation`, `certificate`, `pet` in [`variables.tf`](terraform/variables.tf) |
| Plain HCL comments documenting omitted/computed fields | throughout |
| Data-source-injection pattern | [`data.tf`](terraform/data.tf) → [`locals.tf`](terraform/locals.tf) → [`main.tf`](terraform/main.tf) |
| Tier-based defaults (per-env override falls through to data-source default) | [`locals.tf`](terraform/locals.tf), see `retention_days` / `pet.length` |
| Flat composite-keyed for_each map (nested list-of-objects → iterable resource expansion) | [`locals.tf`](terraform/locals.tf), `manifests_flat`, `lifecycle_hooks_flat` |
| Iterative-children resources via for_each on flattened map | `local_file.manifest`, `null_resource.lifecycle_hook` in [`main.tf`](terraform/main.tf) |
| Filtered for_each for conditional resource creation (0..1 per env) | `time_rotating.environment_rotation`, `tls_self_signed_cert.environment` in [`main.tf`](terraform/main.tf) |
| Splat-on-optional dynamic block (`each.value["foo"][*]`) | `dynamic "subject"` block in [`main.tf`](terraform/main.tf) |
| Sensitive output handling | `environment_secrets`, `environment_certificates` in [`outputs.tf`](terraform/outputs.tf) |
| Aggregate roll-up outputs | `framework_summary` in [`outputs.tf`](terraform/outputs.tf) |
| `terraform test` with real `apply` + output assertions | [`tests/synthetic_environments.tftest.hcl`](terraform/tests/synthetic_environments.tftest.hcl) |
| Validation-rejection tests using `expect_failures` | same file, runs 5+ |

## The packer-aligned style

This framework follows the "packer-aligned" style established in [`nwarila-platform/proxmox-terraform-framework`](https://github.com/nwarila-platform/proxmox-terraform-framework):

| File | Role |
| --- | --- |
| [`terraform/versions.tf`](terraform/versions.tf) | `required_version` + `required_providers` (exact pins per [ADR-template/0001](docs/decision-records/template/0001-pin-terraform-and-provider-versions-exactly.md)) |
| [`terraform/providers.tf`](terraform/providers.tf) | Provider inheritance policy. This synthetic module intentionally declares no provider blocks. |
| [`terraform/backend.tf`](terraform/backend.tf) | Backend config. Local for this showcase; commented S3/GCS/azurerm/HCP variants for real frameworks. |
| [`terraform/data.tf`](terraform/data.tf) | Data sources. Demonstrates the data-source-injection pattern. |
| [`terraform/variables.tf`](terraform/variables.tf) | Consumer-facing input contract. Provider-level flat vars + one mega-object per managed resource type with `optional(<type>, <default>)` baked in. |
| [`terraform/locals.tf`](terraform/locals.tf) | Single `locals { }` block with region sections. Expands variables into a keyed map; injects data-source values; flattens nested lists into composite-keyed for_each maps. |
| [`terraform/main.tf`](terraform/main.tf) | Resource instantiation layer. Pure `each.value["key"]` lookups + dynamic blocks. No computation. |
| [`terraform/outputs.tf`](terraform/outputs.tf) | Per-env composed outputs + sensitive output handling demo. |
| [`terraform/tests/*.tftest.hcl`](terraform/tests/) | `terraform test` runs that actually `apply` against synthetic providers and assert on outputs. |

## What this is, and what it isn't

| | This repo | A real framework |
| --- | --- | --- |
| Demonstrates the framework pattern | Yes | Yes |
| Manages real cloud / SaaS infrastructure | No, by design | Yes |
| Used as the canonical reference for derivative frameworks | Yes | N/A |
| Suitable for "consume me to deploy something" | No | Yes |

If you want to deploy real infrastructure, use a real framework like [`nwarila-platform/proxmox-terraform-framework`](https://github.com/nwarila-platform/proxmox-terraform-framework). **This repo's job is to teach the pattern**, not to do work.

## New Framework Checklist

For a real framework derived from this template, edit these first:

1. `README.md` and repo-specific docs.
2. `terraform/` provider/resource implementation.
3. `examples/` and generated `docs/reference/terraform.md`.
4. `docs/decision-records/repo/` for local decisions.
5. Optional release layer, only if the repo publishes versioned releases.

The mirroring rules live in [`docs/reference/mirroring.md`](docs/reference/mirroring.md).

## Normalized repo interface

This repo uses the same validation command surface as the Terraform runner template:

| Command | Purpose |
| --- | --- |
| `make lint` | Repo-local static checks: fmt, init, validate, TFLint, Python tools, workflow YAML. |
| `make policy` | OPA policy tests plus source-aware and plan-aware policy evaluation. |
| `make docs-check` | terraform-docs drift check plus Diátaxis/ADR documentation layout. |
| `python tools/verify.py ci` | Repo-local quality gate. |
| `python tools/verify.py integration` | Ephemeral framework workspace assembled from `terraform/` and `examples/`. |
| `python tools/verify.py verify` | Full local verification: `ci` plus `integration`. |

To see the framework apply against richer input:

```sh
cp examples/multi-environment/terraform.tfvars.example terraform/terraform.tfvars
( cd terraform && terraform init && terraform apply )
# Inspect produced state:
( cd terraform && terraform state list )
# Real per-env files appear under terraform/.synthetic-output/
ls -la terraform/.synthetic-output/*/
```

## State backend

This showcase uses the **local backend** so the example always works without external setup, per [ADR-template/0002](docs/decision-records/template/0002-keep-reference-framework-credential-free.md). Production frameworks should use a remote backend with native state locking. See the commented variants in [`terraform/backend.tf`](terraform/backend.tf) for canonical S3, GCS, azurerm, and HCP Terraform configurations.

## Folding markers (`#region` / `#endregion`)

The HCL files use `#region ------ [ Title ] ----...---- #` / `#endregion --- [ Title ] ----...---- #` markers throughout. These are recognized by the [Explicit Folding](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding) VS Code extension for navigation in long files. The exact regex format is required for the folding rule to match.

## Why "do-nothing"

A do-nothing framework is the strongest possible pattern showcase because it has **zero confounding details**. Every line of HCL is about Terraform itself — module structure, variable shape, locals composition, resource expansion, dynamic block patterns — not about understanding what an AWS S3 bucket means or how the Proxmox API behaves. Real frameworks layer provider semantics on top of this foundation; the foundation has to be right before the provider semantics matter.

The synthetic providers (`null`, `random`, `local`, `time`, `tls`) were chosen because:

- All five are official HashiCorp providers with dead-stable APIs (~zero breaking changes per year)
- All five are free, all five work offline, all five generate real `terraform.tfstate`
- Together they cover every dynamic-block pattern (iterative blocks, single-optional blocks, splat-on-optional, filtered for_each), sensitive-data handling (private keys), and time-driven resource lifecycles (rotation)

## License

MIT — see [LICENSE](LICENSE).
