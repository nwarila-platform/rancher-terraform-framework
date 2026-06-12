tflint {
  required_version = ">= 0.50"
}

config {
  format = "compact"
  call_module_type = "all"
}

# region ------ [ Plugin: terraform (built-in best-practice rules) ] ----------------------- #

plugin "terraform" {
  enabled = true
  preset  = "all"
  version = "0.14.1"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# endregion --- [ Plugin: terraform (built-in best-practice rules) ] ----------------------- #

# region ------ [ Rule overrides ] --------------------------------------------------------- #

# Keep unused declaration checks enabled. Derivative modules that need a
# local exception must document it in their own repo rather than inheriting
# a blanket provider-specific rationale from the template.

rule "terraform_unused_declarations" {
  enabled = true
}

# Rancher framework modules intentionally use the packer-limited semantic file
# layout instead of canonical main.tf/variables.tf/outputs.tf.
rule "terraform_standard_module_structure" {
  enabled = false
}

# The packer-limited house style uses # comments and #region markers across
# Terraform and Packer HCL.
rule "terraform_comment_syntax" {
  enabled = false
}

# Module-style frameworks prefer documentation comments over inline
# descriptions on every variable; the `terraform_documented_outputs`
# rule already enforces output descriptions, which is the more useful
# of the pair.

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

# This framework's variables.tf uses the packer-aligned mega-object
# pattern with very long type definitions. The 80-char line-length rule
# forces awkward wrapping; disabled in favor of the editor ruler at 96.

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# endregion --- [ Rule overrides ] --------------------------------------------------------- #
