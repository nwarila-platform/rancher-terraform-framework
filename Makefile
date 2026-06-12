PYTHON ?= python3
TFLINT ?= tflint
INTEGRATION_CASE ?= basic

.PHONY: help setup fmt fmt-check init validate tflint ruff yamllint test chart-schema chart-policy workflow-helper-tests opa-test opa-policy opa-plan manifest-check docs docs-diff docs-layout adr-schema lint policy docs-check integration ci verify

help:
	@printf "Targets:\\n"
	@printf "  setup          Install local Python lint dependencies\\n"
	@printf "  lint           Run Terraform, TFLint, Python, and YAML checks\\n"
	@printf "  test           Run terraform test\\n"
	@printf "  chart-schema   Render charts and validate Kubernetes schemas\\n"
	@printf "  chart-policy   Render charts and evaluate Kyverno policies\\n"
	@printf "  policy         Run OPA tests and policy evaluation\\n"
	@printf "  docs-check     Check terraform-docs output and docs layout\\n"
	@printf "  ci             Run the repo-local quality gate\\n"
	@printf "  integration    Exercise the quickstart input in a temp workspace\\n"
	@printf "  verify         Run ci plus integration\\n"

setup:
	$(PYTHON) -m pip install --upgrade pyyaml==6.0.3 ruff==0.13.0 yamllint==1.35.1

# Mutating: rewrites HCL in place. Use locally before committing.
fmt:
	terraform -chdir=terraform fmt -recursive

# Non-mutating: fails if any file would change. Use in CI.
fmt-check:
	terraform -chdir=terraform fmt -check -recursive

init:
	terraform -chdir=terraform init -backend=false -input=false

validate:
	terraform -chdir=terraform validate

tflint:
	$(TFLINT) --init --config "$(CURDIR)/.tflint.hcl"
	$(TFLINT) --config "$(CURDIR)/.tflint.hcl" --chdir terraform

ruff:
	$(PYTHON) tools/verify.py ruff

yamllint:
	$(PYTHON) tools/verify.py yamllint

# Real apply against synthetic resources via `terraform test`.
# Generates a real terraform.tfstate inside the test sandbox,
# asserts on outputs, and tears down cleanly. Demonstrates that
# this framework's full lifecycle works end-to-end without external
# providers.
test:
	terraform -chdir=terraform test

chart-schema:
	$(PYTHON) tools/verify.py chart-schema

chart-policy:
	$(PYTHON) tools/verify.py chart-policy

workflow-helper-tests:
	shellcheck tools/ci/*.sh
	$(PYTHON) tools/ci/check_workflow_run_inputs.py .github/workflows
	bats tests/ci/*.bats

# OPA policy tests. Exercises every deny rule in
# policies/opa/repo_hygiene.rego against pass + fail fixtures.
opa-test:
	opa test policies/opa

# OPA policy enforcement. Evaluates the policy against this repo's
# actual workflows and Terraform version pins.
opa-policy:
	$(PYTHON) tools/verify.py opa-policy

# Static OPA-on-plan is intentionally retired for this repo by ADR-repo/0008.
# Keep the target for template-family command compatibility.
opa-plan:
	$(PYTHON) tools/verify.py opa-plan

# Validates baseline-manifest.json against the drift-gate manifest
# schema without installing drift-gate during CI. Derivative frameworks
# use this manifest to mirror the template-tier scaffold byte-for-byte.
manifest-check:
	$(PYTHON) tools/verify.py manifest-check

# Mutating: regenerates the BEGIN_TF_DOCS / END_TF_DOCS block in
# docs/reference/terraform.md from the HCL in terraform/.
docs:
	$(PYTHON) tools/verify.py docs

# Non-mutating: fails if docs/reference/terraform.md is out of sync.
# Run by CI to enforce that committed terraform-docs output matches
# what the current HCL would produce.
docs-diff:
	$(PYTHON) tools/verify.py docs-diff

docs-layout:
	$(PYTHON) tools/verify.py docs-layout

adr-schema:
	$(PYTHON) tools/verify.py adr-schema

lint:
	$(MAKE) fmt-check
	$(MAKE) init
	$(MAKE) validate
	$(MAKE) tflint
	$(MAKE) ruff
	$(MAKE) yamllint

policy:
	$(MAKE) opa-test
	$(MAKE) opa-policy
	$(MAKE) opa-plan

docs-check:
	$(MAKE) docs-diff
	$(MAKE) docs-layout
	$(MAKE) adr-schema

integration:
	$(PYTHON) tools/verify.py integration --case $(INTEGRATION_CASE)

ci:
	$(PYTHON) tools/verify.py ci

verify:
	$(PYTHON) tools/verify.py verify --case $(INTEGRATION_CASE)
