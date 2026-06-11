# Develop This Template

## Local setup

Install the same toolchain CI uses:

- Terraform 1.15.4.
- TFLint 0.62.0.
- OPA 1.10.0.
- terraform-docs 0.23.0.
- Python 3.12 for helper scripts.

## Development loop

```sh
python tools/verify.py ci
python tools/verify.py integration
```

Use `make docs` after editing Terraform inputs, outputs, or variables; `make docs-check` verifies the committed docs are current.

## Editing framework files

Keep framework code in `terraform/`. Put reusable CI helpers under `tools/ci/`.
List files in `baseline-manifest.json` under `byte_identical` only when
derivative frameworks should mirror them byte-for-byte. Use
`scaffold_starter` for starter policy or examples derivatives are expected to
rewrite.

Runner inventory data belongs in runner repos, not in this framework template.
