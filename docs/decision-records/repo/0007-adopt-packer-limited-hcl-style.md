# ADR-repo/0007: Adopt Packer-Limited HCL Style

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-06-12                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (@NWarila)                  |
| Consulted      | 2026-06-12 owner interview, proxmox-terraform-framework, proxmox-packer-framework, aws-terraform-framework. |
| Informed       | Framework maintainers, tenant template maintainers, documentation authors. |
| Reversibility  | Medium                                  |
| Review-by      | 2026-12-12                              |

## TL;DR

This repository's future Terraform code will use the packer-limited HCL style
used across the Terraform and Packer framework family: unnumbered semantic
files, `#` comments, `#region` markers, simple banner comments, two-space
indentation, and a 98-column target. This supersedes the AWS-style numbered
Terraform file layout and `#%` banner style followed by the Step 2 skeleton for
this repository only.

The AWS framework still provides the `all_*` variable structure precedent:
list-object variables, `optional(...)`, `alltrue([for ...])` validations, locals
keyed from the list, and `for_each` resources. The style decision changes the
syntax presentation and file organization, not the accepted `all_workloads`
contract structure from [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md).

## Context and Problem Statement

The Step 1 and Step 2 work intentionally mirrored the sibling
`aws-terraform-framework` shape: numbered Terraform files such as
`00-providers.tf`, `10-variables.tf`, `32-locals-aws.tf`, and `50-resources.tf`,
plus `#%` banner comments. The owner later clarified that the broader framework
family needs Terraform and Packer code to remain visually and mechanically
consistent, so Rancher Terraform code should use the packer-limited HCL subset
already used in Proxmox Terraform and Packer framework repositories.

The Proxmox Terraform framework uses semantic Terraform file names such as
`versions.tf`, `providers.tf`, `variables.tf`, `locals.tf`, `resources.tf`,
`outputs.tf`, `data.tf`, and `backend.tf`. Its variables use the `all_systems`
list-object pattern, while resources consume locally keyed maps through
`for_each`.

The Proxmox Packer framework uses semantic Packer files such as
`packer.pkr.hcl`, `variables.pkr.hcl`, `locals.pkr.hcl`, `source.pkr.hcl`,
`builds.pkr.hcl`, and `data.pkr.hcl`. Its HCL files use `#` comments,
`#region`/`#endregion` markers, and simple `# ===` banners. Adopting that
limited subset keeps Terraform and Packer framework code easier to compare,
review, and generate.

## Decision Drivers

1. **Cross-tool consistency.** Terraform and Packer framework repositories
   should be readable with the same HCL conventions.
2. **Small future diffs.** Semantic file names make future file moves and
   comparisons easier across framework families.
3. **Avoid Terraform-only idioms.** Comments and formatting should stay inside
   the HCL subset that also feels native in Packer.
4. **Keep the proven object pattern.** The AWS `all_*` structure remains useful
   and should compose with the packer-limited style.

## Considered Options

1. Adopt the packer-limited HCL style for this repository's Terraform code.
2. Keep the AWS numbered-file and `#%` banner style.
3. Mix styles: numbered files with packer-style comments.

## Decision Outcome

Chosen option: **Option 1, adopt the packer-limited HCL style.**

Future Terraform code in this repository uses these conventions:

- unnumbered semantic files such as `versions.tf`, `providers.tf`,
  `variables.tf`, `locals.tf`, `resources.tf`, `outputs.tf`, `backend.tf`, and
  `data.tf` when needed;
- `#` comments rather than `//` comments;
- simple `# ===` banner comments where a file-level banner is useful;
- `#region` and `#endregion` section markers for long files;
- two-space indentation;
- a 98-column target through `.editorconfig`;
- no Terraform-only comment ornamentation that would look out of place in
  Packer HCL.

Future Terraform code still keeps the AWS framework's structural lessons where
they are useful:

- one `all_workloads` list-object input for managed workload objects;
- `optional(...)` fields for defaults in object types;
- `alltrue([for ...])` validations for list-wide checks;
- locals that normalize the list into maps keyed by stable workload keys;
- `for_each` resources over those local maps.

## Pros and Cons of the Options

### Option 1: Adopt packer-limited HCL style

- **Good, because** it aligns this Terraform framework with the Packer and
  Proxmox framework family.
- **Good, because** it supports the owner's cross-tool style requirement.
- **Good, because** it keeps HCL readable to maintainers moving between
  Terraform and Packer repositories.
- **Bad, because** Step 2's already-merged numbered Terraform files need a
  style-only refactor before the `all_workloads` contract refactor.

### Option 2: Keep AWS numbered-file style

- **Good, because** Step 2 already follows it.
- **Good, because** it matches the original architecture-lock instruction to
  mirror `aws-terraform-framework`.
- **Bad, because** it conflicts with the owner direction to keep Terraform and
  Packer framework style consistent.
- **Bad, because** it separates this repo from the Proxmox framework style that
  now carries the cross-tool convention.

### Option 3: Mix styles

- **Good, because** it would require fewer file moves than a full style refactor.
- **Bad, because** it creates a local hybrid style that matches neither AWS nor
  the packer-limited framework family.
- **Bad, because** it would make future automation and review guidance less
  clear.

## Confirmation

1. Future Terraform refactor work MUST rename the numbered Terraform files to
   semantic file names.
2. Future Terraform code MUST use `#` comments rather than `//` comments.
3. Future Terraform code MUST use packer-limited banners and region markers.
4. Future Terraform code MUST retain the `all_workloads` list-object structure
   accepted by ADR-repo/0006.
5. Documentation and generated Terraform reference output MUST be regenerated
   after the style-only file move in the later implementation step.

## Consequences

### Positive

- Terraform and Packer framework code can share one visible HCL house style.
- Future code-generation and review checklists can target one cross-tool subset.
- The `all_workloads` object contract can use the AWS `all_*` structure without
  inheriting AWS's numbered file style.

### Negative

- The Step 2 Terraform skeleton is now stylistically superseded and must be
  refactored before the contract is expanded.
- Reviewers must distinguish between structure borrowed from AWS and styling
  borrowed from the packer-limited framework family.

### Neutral

- This ADR does not change provider pins, resource behavior, variable semantics,
  tests, policies, or CI gates by itself.

## Assumptions

1. The packer-limited style remains the owner's preferred style across the
   Terraform and Packer framework family.
2. The Step 4 style-only refactor can preserve Terraform behavior exactly.
3. The Step 5 `all_workloads` contract refactor will happen after the style-only
   move to avoid mixing concerns.

## Supersedes

- The AWS numbered-file and `#%` banner styling previously followed by the Step
  2 Terraform skeleton for this repository's future `terraform/` implementation
  only.

## Superseded by

None (current).

## Implementing PRs

- The Step 3 architecture-reconciliation pull request introduces this ADR.
  The later style-only Terraform refactor PR should append its link here.

## Related ADRs

- [ADR-repo/0006](0006-use-all-workloads-tenant-contract.md) defines the `all_workloads` object contract this style will carry.
- [ADR-template/0001](../template/0001-pin-terraform-and-provider-versions-exactly.md) still requires exact Terraform and provider pins.

## Compliance Notes

This ADR records source style direction only. It is not evidence that the
current `terraform/` directory already follows the style; that refactor is a
later implementation step.
