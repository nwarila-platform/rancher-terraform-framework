# Testing Strategy

## What checks this repo runs

This template repo exercises the framework pattern and its support tooling
across two workflows: `ci.yaml` (validation jobs) and `security.yaml`
(which calls the org reusables in `NWarila/.github`). Most of the
Terraform and policy checks below are sub-steps of the single
`terraform verify` job in `ci.yaml`, which runs `python tools/verify.py
verify`, rather than standalone jobs:

| Layer | Where it runs | What it proves |
| --- | --- | --- |
| Terraform module | `terraform verify` job → `python tools/verify.py verify` | `fmt`, `init`, `validate`, TFLint, `terraform test`, source-aware OPA, the documented `opa-plan` compatibility no-op, docs drift, and integration all pass. |
| Terraform plan policy | `python tools/verify.py opa-plan` | Static OPA-on-plan is retired by ADR-repo/0008. Framework-specific Rancher envelope assertions live in `terraform test`; workload security lives in chart render gates and admission. |
| Template manifest | sub-step of `python tools/verify.py verify` | The template-tier scaffold manifest loads and every source path exists. |
| YAML data | sub-step of `python tools/verify.py verify` | Workflow YAML is valid and consistently shaped (yamllint). |
| Documentation layout | sub-step of `python tools/verify.py verify` | Markdown stays inside the Diataxis and ADR directory structure (docs-layout). |
| Python tools | sub-step of `python tools/verify.py verify` | CI helper scripts lint clean (ruff). |
| Workflow YAML | `actionlint` job (`ci.yaml`) | Workflow files parse and follow GitHub Actions semantics. |
| Markdown | `markdownlint` job (`ci.yaml`) | Documentation lints clean. |
| Workflow security | `security.yaml` → `NWarila/.github` `reusable-iac-security` | Workflow code avoids known dangerous Actions patterns (zizmor). |

Derivative frameworks exercise this template by retaining the same `make` interface and replacing only the Terraform implementation details.

## What the tests do not cover

- Real provider credentials and external services in the static gate; this
  repository uses mocked Terraform tests locally and defers real Rancher
  behavior to future disposable integration CI.
- Repository ruleset enforcement, branch protection, and required status checks; those live in GitHub settings.
- A production remote backend in PR/self-CI; the reference keeps local state so the template is runnable without setup. Trusted runner deploy workflows can exercise the reusable deploy path with caller-supplied S3/OIDC configuration after merge.
