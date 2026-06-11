# Threat Model

This document is a STRIDE-style threat model for `NWarila/terraform-framework-template` and, by extension, the framework pattern this template demonstrates. It exists to make the security posture of derivative frameworks legible: a real framework managing real cloud resources inherits the same trust boundaries and the same threat surface the pattern itself has, plus whatever its specific provider adds.

## Scope

What this document covers:

- The framework template repository's own threats (supply chain, CI compromise, contributor account compromise).
- Threats inherent to the framework PATTERN (state file leakage, `terraform plan` output leakage, drift between code and reality).
- Threats inherent to the derivative-consumer pattern (a runner's overlay tree composed at validation time, the SHA-pin chain from runner to framework to drift-gate to canonical).

What this document does NOT cover:

- Threats specific to the synthetic providers (`null`, `random`, `local`, `time`, `tls`). These are stack-internal Terraform features with no external attack surface; their threat model is the Terraform Core threat model, which lives upstream.
- Threats specific to derivative frameworks' real providers (AWS, GCP, Azure, etc.). Each derivative framework owns its own threat model addendum. This document gives them a starting structure.
- Operational runbooks. Incident response procedures live in each consumer's `docs/how-to/`, not here.

## Trust boundaries

Six boundaries cross the framework pattern, each one a candidate for compromise or accidental disclosure:

1. **Author → Repository.** The framework author commits HCL into the repo. Trust depends on the author's GitHub credentials, their commit signing posture, and branch protection on `main`.
2. **Repository → CI runner.** Self-CI checks out the repo onto a GitHub-hosted runner. Trust depends on GitHub's runner-image integrity and GitHub Actions' permission model.
3. **CI runner → Provider registry.** `terraform init` downloads provider plugins from `registry.terraform.io`. Trust depends on the registry, the provider's signing cert (HashiCorp signs official providers), and Terraform Core's verification logic.
4. **CI runner → State backend.** `terraform apply` writes state. For the do-nothing reference framework, state is local in the test sandbox and never leaves the runner. For a derivative framework, state goes to the remote backend selected by that framework or its consuming runner. Trust depends on the backend service, the encryption configuration, and the IAM/auth path used to reach it.
5. **CI runner → Cloud APIs.** A real framework's `terraform apply` calls the cloud provider's API to create resources. Trust depends on the API's authentication path, the temporary credentials' scope, and the API itself.
6. **Framework → Consumer (template-tier composition).** A runner consumer overlays its `repos/` data onto this framework's `terraform/` tree at validation time. The overlay can change what the framework sees on disk. Trust depends on the runner's contribution discipline (it controls the data) and the overlay mechanism (it controls how data lands in the framework tree).

## Threats by category

### Spoofing

- **Compromised commit on the framework template repo.** An attacker with author credentials commits malicious HCL or workflow YAML to `main`. Mitigation: branch protection requires signed commits, code-owner review, and passing CI. The drift-gate workflow blocks PRs that drift from canonical org-baseline files. The OPA `repo_hygiene` policy rejects unsigned `uses:` references and tag-pinned actions.
- **Compromised SHA-pin in a downstream consumer.** A derivative framework's `uses:` line references a forked/squatted repo at a SHA that looks legitimate. Mitigation: the OPA policy requires `uses:` references to be either SHA-pinned, local `./...`, or digest-pinned docker. SHA collisions on Git's SHA-1 are computationally expensive but not impossible; full SHA-256 transitions in Git would close this further. Practically, the SHA-pin discipline is the strongest mitigation available today.
- **Provider registry MITM.** An attacker intercepts the `registry.terraform.io` connection during `terraform init` and serves a malicious provider plugin. Mitigation: Terraform verifies provider plugins against the registry's signing certificate (HashiCorp official providers are signed). The template commits `terraform/.terraform.lock.hcl` with cross-platform H1 hashes so Linux CI, Windows, and macOS contributors verify the same provider selections, and `tools/verify.py lockfile-check` fails closed if the lock file is absent.

### Tampering

- **State file mutation between apply and read.** An attacker modifies Terraform state to change Terraform's view of reality. Mitigation: this reference framework uses local state only inside test and workflow sandboxes. Derivative frameworks that adopt a remote backend must document locking, recovery, and encryption controls in their own repo-tier threat model.
- **Overlay path injection.** A runner consumer's `repos/public/` data is overlaid onto the framework's `terraform/` tree at validation time. A malicious entry in the overlay could try to write to `terraform/versions.tf`, `terraform/providers.tf`, or `.github/workflows/` and silently change pinned versions or workflow behavior. Mitigation: the framework/runner ownership boundary is kept in the overlay contract itself, the runner-template validates `framework_ref` is a 40-character SHA before checkout, and `tools/ci/apply_overlay.sh` rejects overlay destinations outside `terraform/repos/` and `terraform/fixtures/runtime/`. The framework's own files at `framework_ref` stay byte-stable; only runner-owned data and runtime fixture paths can land via overlay.
- **Cached state-tampering on a CI runner.** A persistent runner reused across jobs could have stale `terraform.tfstate` or `.terraform/` cached from a prior tenant. Mitigation: GitHub-hosted runners are ephemeral by default — each job gets a fresh image. Self-hosted runners that persist between jobs MUST clean working directories between tenants. Out of scope: this template only targets GitHub-hosted runners.

### Repudiation

- **An author denies committing a malicious change.** Mitigation: the org's signed-commits requirement (org ADR-0001 §"required_signatures") makes authorship cryptographically verifiable on every commit. Denying authorship requires denying control of the signing key, which is a separate (much higher-bar) compromise scenario.
- **A consumer denies running an apply that broke production.** Mitigation: every apply executed via the framework's `reusable-terraform-deploy.yaml` runs in GitHub Actions, producing a tamper-evident workflow run record (run ID, actor, commit SHA, timestamp). Local-backend reference runs may upload plan/state artifacts for inspection. Remote-backend deploys should suppress those artifacts and rely on the workflow run record plus provider-side audit logs because real Terraform plan and state files can contain sensitive material.

### Information Disclosure

- **State file contains sensitive resource attributes.** `terraform.tfstate` records every attribute of every resource Terraform manages, including provisioned secrets, derived IDs, and sensitive variable values. The state file IS sensitive material. Mitigation: this reference framework keeps state local to ephemeral validation contexts unless a trusted runner explicitly supplies a remote backend. Remote-backend deploys verify state in the backend instead of uploading state as a workflow artifact. Derivative frameworks that use remote state must define backend-specific read controls, logging, and encryption. The framework itself uses `sensitive = true` on outputs that contain credential material (`environment_secrets`, `environment_certificates` in `outputs.tf`) so the values are redacted in CLI output.
- **`terraform plan` output leaked via PR comments.** A common pattern is posting plan output as a PR comment for review. Plan output includes proposed resource attribute values, including sensitive defaults. Mitigation: this template does NOT post plan output to PR comments by default. Derivative frameworks that adopt that pattern MUST mask sensitive values in the comment-posting step or skip it for sensitive resources.
- **CI workflow logs contain provider credentials.** A misconfigured `terraform plan -debug` or a `set -x` in a wrapper script could echo credentials. Mitigation: this template's workflows don't enable Terraform's verbose debug. OPA + `zizmor` (in the IaC security workflow) flag dangerous inputs as code injection into workflow steps. GitHub Actions' built-in secret masking redacts known-secret values from logs but does NOT catch derived values (e.g., a token base64-decoded into a different form).
- **Public repo accidentally tracking secrets.** A future contributor commits a `terraform.tfvars` containing real credentials into the framework's runner-inventory fixture tree. Mitigation: `.gitignore` blocks common Terraform state, local variable, credential, and key files; pre-commit hooks plus `gitleaks` in the IaC security workflow catch staged secrets that slip past ignore rules.

### Denial of Service

- **Provider registry unavailability.** If `registry.terraform.io` is down during a CI run, `terraform init` fails. Mitigation: this is a hard external dependency. Workarounds (private Terraform registry mirror, vendored providers) are out of scope for this template; consumers that genuinely need air-gapped operation document their own mitigation in a repo-tier ADR.
- **State backend unavailability.** A derivative framework's remote backend outage can prevent state locking or writes. Mitigation: this template's self-validation still fails fast without a remote backend. Trusted runner deploys that opt into the S3 backend fail during `terraform init`, locking, apply, or post-apply state verification. Real frameworks must document backend availability expectations and recovery procedures alongside the backend they choose.
- **drift-gate as a single point of failure.** Every consumer's PR validation runs against `NWarila/drift-gate` as a SHA-pinned composite action. If that repo is deleted or corrupted, every consumer's drift-gate.yaml fails on next run. Mitigation: drift-gate is in a public repo under the maintainer's control; SHA-pinning means an existing pin keeps working even if the canonical repo is later compromised (the immutable Git SHA still resolves). Consumers that want to harden further could fork drift-gate to a non-maintainer-owned org and pin against that fork.

### Elevation of Privilege

- **Privilege escalation via overlay-injected workflow.** If the overlay mechanism allowed writing to `.github/workflows/`, an attacker controlling runner data could inject a workflow that runs with the framework's permissions. Mitigation: the overlay is constrained to `terraform/repos/` and `terraform/fixtures/runtime/` within the framework tree. The runner contract's `overlay_paths` input requires explicit `<src>=><dst>` pairs; there's no glob or recursive copy that would land in `.github/`. Defense-in-depth: workflows run with `permissions: contents: read` by default in this template; even a successful injection couldn't push code or write protected refs without explicit permission grants.
- **OIDC role over-permission.** A derivative framework's cloud role assumed via OIDC could be over-scoped, granting more permissions than the framework needs. Mitigation: the trust policy SHOULD scope to specific repository, branch, environment, and event claims where the cloud provider supports them. The role policy SHOULD use least-privilege grants to specific resources, not wildcards. This is a per-framework concern; this template does not define a cloud role.
- **Cross-job credential reuse.** GitHub Actions' OIDC tokens are scoped per-job. A misconfigured workflow that passes credentials between jobs could expand the trust radius. Mitigation: this template's workflows obtain fresh OIDC tokens per job; no cross-job credential passing.

## Out of scope (and why)

- **Terraform Core vulnerabilities.** Bugs in Terraform itself are outside this template's threat model. Mitigation lives at the Terraform version pin level: this repository's ADR-template/0001 requires exact `=` pins so a newly-discovered Terraform CVE forces an explicit, reviewable bump rather than silent uptake of a compromised release.
- **Provider plugin vulnerabilities.** Same reasoning — provider versions are exact-pinned per this repository's ADR-template/0001. A CVE in `hashicorp/random` (unlikely; it's tiny) or in a real provider (more likely) is detected via vulnerability scanners (Trivy in `reusable-iac-security.yaml`) and forces an explicit upgrade.
- **Compromise of the upstream HashiCorp signing key.** If HashiCorp's provider-signing key were compromised, every Terraform provider distributed by HashiCorp could be malicious. This is a global-Terraform-ecosystem-wide problem. Mitigations live at HashiCorp; consumers can only respond after disclosure.
- **Compromise of a runner's private inventory source.** Some runners may source private inventory from an external system before overlay. If that source is compromised, the data is tainted before this framework sees it. Mitigations live in the runner's own ops setup and are outside this framework template.

## Cross-references

- [Org ADR-0004](../decision-records/org/0004-use-renovate-for-dependency-updates.md) — establishes the per-template Renovate baseline pattern. SHA-pinning + Renovate-driven bumps mean every dependency change is a reviewable PR rather than silent uptake.
- [ADR-template/0001](../decision-records/template/0001-pin-terraform-and-provider-versions-exactly.md) — establishes exact-pinning of Terraform CLI and provider versions. Direct mitigation for "silent uptake of a compromised release" listed above.
- [ADR-template/0002](../decision-records/template/0002-keep-reference-framework-credential-free.md) — keeps this reference framework synthetic, local, and credential-free.
- [`policies/opa/repo_hygiene.rego`](../../policies/opa/repo_hygiene.rego) — the OPA policy enforcing SHA-pinned `uses:` references and exact `=` version pins. Mechanical enforcement of several of the mitigations referenced above.

## What a derivative framework adds

A real framework (managing AWS, GCP, Azure, etc.) inherits this threat model and adds, at minimum:

- A section enumerating the cloud-specific resources it manages and the threat each one introduces.
- An OIDC trust policy + IAM role policy pair, scoped to the specific framework's repository and the specific resources it provisions.
- A backup/recovery posture for the resources under management, including both Terraform state and the resources themselves.
- An incident-response runbook (`docs/how-to/incident-response.md` typically) with named response procedures, on-call rotation, and rollback steps.

This template doesn't have any of those — it manages no real resources. The structure here is the canonical starting point a derivative framework's threat model fills in.
