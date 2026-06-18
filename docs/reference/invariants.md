# Invariants

- **Frameworks own Terraform code.** A framework contains `terraform/` and exposes plan/apply through the framework deploy reusable.
- **Org-owned policy files and ADR mirrors stay byte-identical with `NWarila/.github`.** `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `LICENSE`, org ADRs, and layout sentinels are enforced by the org drift gate.
- **Runners own inventory data.** Runner repos provide `repos/` data and call this framework by SHA; they do not mutate the framework source.
- **Terraform and provider versions are exact pins.** `terraform/versions.tf` uses `= X.Y.Z` for the CLI and every provider.
- **Workflow `uses:` references are SHA-pinned.** Local `./...` reusable calls and digest-pinned docker images are allowed.
- **Rancher envelope invariants are covered by Terraform validation and tests.** `terraform test` asserts project, namespace, PSA label, quota, Helm namespace, CRD-skip, and multi-workload fan-out behavior; `make opa-plan` is a documented compatibility no-op per ADR-repo/0008.
- **Tenant tfvars is an untrusted source boundary.** Only `all_workloads` is honored as the tenant-supplied Terraform variable surface; platform auth, identity, caps, quota, and backend settings are injected out of band by the consuming runner, because Terraform cannot enforce variable source.
- **The reference framework remains credential-free.** Synthetic providers are used so tests and integration run without cloud accounts, secrets, or recurring cost.
- **Generated Terraform docs are checked, not trusted.** `docs/reference/terraform.md` must match `terraform-docs` output.
- **Template-tier baseline entries must declare propagation semantics.** `baseline-manifest.json` is load-bearing for derivative framework drift gates. `byte_identical` entries are mirrored exactly; `scaffold_starter` entries are starter material that derivatives rewrite for their provider surface.
- **Framework-template ADRs are owned here.** Shared framework decisions live in `docs/decision-records/template/` and are mirrored to derivative frameworks through `baseline-manifest.json`.

## Template-Family Conventions

- Framework templates expose exactly one tool-specific reusable workflow using
  `reusable-<tool>-framework-<verb>.yaml`. The verb names the natural action
  for that tool family; this template uses `deploy` because Terraform framework
  consumers plan and apply the framework module through the reusable.
- Framework `verify.py ci` targets keep `workflow-helper-tests` and
  `privileged-workflows` explicit, and `docs-check` owns ADR schema validation.
  Tool-specific lint, test, and policy targets may differ by stack, but each
  difference must be listed in `docs/reference/quality-gates.md`.
- Runner templates and runner consumers do not copy the framework reusable
  naming pattern unless they own executable framework logic.
