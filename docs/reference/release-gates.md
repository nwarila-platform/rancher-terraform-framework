# Release Gates

PRs to `main` on this template must pass:

- `actionlint` (workflow syntax)
- `workflow helper tests` (ShellCheck, workflow input binding checks, and Bats coverage for workflow helpers)
- `markdownlint` (docs)
- `terraform verify` (`python tools/verify.py verify`, including Terraform gates, source-aware OPA, plan-aware OPA, lint, docs, manifest, and integration)
- `org-baseline / verify` (drift-gate against `NWarila/.github` at pinned source-ref)
- `Trivy (filesystem & secrets)`, `Gitleaks (secret scan)`, `zizmor (Actions security)` (security)
- `CodeQL` (`security.yaml`)

OpenSSF Scorecard runs on push, branch-protection, schedule, and manual paths;
it is skipped on PR and merge queue because private-repo Scorecard GraphQL
access is not reliable.

The framework deploy reusable is exercised by runner repositories that call it with a pinned `framework_ref`. This repo's `python tools/verify.py integration` covers the local framework assembly path; trusted runner repositories cover the full S3/OIDC deploy path on `main` with caller-owned secrets.

Release evidence, when `release.yaml` is enabled, uploads the evidence bundle
and SPDX SBOM as release assets and emits GitHub artifact attestations for
bundle provenance and SBOM binding.
