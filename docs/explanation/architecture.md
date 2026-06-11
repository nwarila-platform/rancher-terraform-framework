# Architecture

## System topology

Source: [docs/diagrams/architecture.mmd](../diagrams/architecture.mmd)

```mermaid
C4Context
  title terraform-framework-template — system topology

  Person(maintainer, "Portfolio maintainer", "Nick Warila — owns templates, runner, and deployed frameworks")

  System_Boundary(template_tier, "Template tier (NWarila personal)") {
    System(framework_template, "terraform-framework-template", "Canonical synthetic Terraform module + reusable deploy workflow + validation harness. This repo.")
  }

  System_Boundary(runner_tier, "Runner tier (NWarila personal)") {
    System(runner, "github-terraform-runner", "Holds per-repo YAML inventory. Calls reusable-terraform-deploy.yaml at a pinned framework_ref to plan / apply GitHub Terraform state.")
  }

  System_Boundary(framework_tier, "Deployed-framework tier (nwarila-platform org)") {
    System(deployed_framework, "nwarila-platform/github-terraform-framework", "Real Terraform module that manages GitHub repos, rulesets, and CODEOWNERS. Derived from this template.")
    System(proxmox_framework, "nwarila-platform/proxmox-terraform-framework", "Real Terraform module managing Proxmox VMs. Another derivative framework.")
  }

  System_Ext(github_api, "GitHub API", "REST + GraphQL endpoints managed by the deployed framework")
  System_Ext(org_github, "NWarila/.github", "Org-baseline ADR masters and universal CI reusables")

  Rel(maintainer, framework_template, "Opens PRs, reviews, merges")
  Rel(maintainer, runner, "Manages inventory YAML and deploy triggers")
  Rel(runner, framework_template, "Calls reusable-terraform-deploy.yaml at pinned SHA (framework_ref)")
  Rel(runner, deployed_framework, "Overlays repo YAML inventory into pinned framework checkout at deploy time")
  Rel(deployed_framework, github_api, "terraform apply / plan")
  Rel(framework_template, org_github, "Mirrors org ADRs; calls org reusable CI workflows")
  Rel(deployed_framework, framework_template, "Derived from template; inherits baseline-manifest.json scaffold")
  Rel(proxmox_framework, framework_template, "Derived from template; inherits baseline-manifest.json scaffold")
```

## Template boundary

`terraform-framework-template` is the reference Terraform framework template. It owns:

- A complete synthetic Terraform module under [`terraform/`](../../terraform/) that demonstrates framework structure without external services.
- The framework deploy reusable, [`reusable-terraform-deploy.yaml`](../../.github/workflows/reusable-terraform-deploy.yaml), which runner repos call for plan/apply.
- The release-evidence reusable, [`reusable-release-evidence.yaml`](../../.github/workflows/reusable-release-evidence.yaml), which the release workflow calls to attest release artifacts.
- A template-tier `baseline-manifest.json` for derivative frameworks that separates byte-identical scaffold from starter files derivatives rewrite.
- Framework-template ADRs under [`docs/decision-records/template/`](../decision-records/template/) that explain the shared framework decisions derivative frameworks inherit.
- The normalized Terraform CI harness under [`tools/ci/`](../../tools/ci/).

It does not own the universal security and release-automation workflows. CodeQL, Scorecard, IaC security, release-please, and trusted-bot auto-merge live in [`NWarila/.github`](https://github.com/NWarila/.github); this template's `security.yaml`, `release.yaml`, and `auto-merge.yaml` entrypoints only *call* those org reusables pinned by SHA.

It does not own runner inventory data. Runner repos keep `repos/public/` and `repos/private/` and overlay that data into a pinned framework checkout at validation or deploy time.

## Inputs and outputs

Derivative frameworks replace the synthetic providers, resources, repo-specific docs, and deploy pins while preserving the command surface:

- `python tools/verify.py ci` proves formatting, init, validate, TFLint, tests, OPA policy, docs, and manifest health.
- `python tools/verify.py integration` assembles an ephemeral framework workspace from `terraform/` plus an example tfvars file and runs the Terraform-facing gates.
- Runner repos call this framework's deploy reusable with a pinned `framework_ref` and explicit overlay paths. Pull requests normally use the local backend for plan-only validation. Trusted `main` deploys can opt into the caller-supplied S3 backend mode to prove OIDC, locking, apply, and remote state verification.

The reference framework's own validation intentionally uses a local backend so the template can run without credentials. Production frameworks should use the backend required by their consuming stack policy, and trusted runner deploys can pass those backend settings to the reusable workflow at runtime.

## External dependencies

- [`NWarila/.github`](https://github.com/NWarila/.github) provides org-baseline ADR masters mirrored under `docs/decision-records/org/`.
- [`NWarila/drift-gate`](https://github.com/NWarila/drift-gate) enforces byte-identical mirrors for org and template baseline files.
- Terraform, TFLint, OPA, and terraform-docs form the local and CI validation toolchain.
