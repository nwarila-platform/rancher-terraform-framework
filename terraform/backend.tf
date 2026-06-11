# State backend.
#
# This do-nothing showcase uses the LOCAL backend so the example always
# works without external setup, paid services, or cloud accounts. Real
# derivative frameworks SHOULD use a remote backend with state locking;
# the commented-out blocks below show the canonical patterns.
#
# Local state lives at ./terraform.tfstate during dev and is uploaded as
# a CI workflow artifact for inspection. Local state has NO concurrency
# protection and MUST NOT be used for production frameworks managing
# real infrastructure.
#
# To switch to a real backend, delete the empty `terraform { }` block
# below and uncomment the variant for your provider. Re-run
# `terraform init -migrate-state` to move existing state.

terraform {
  # Local backend (default) — no block needed; left empty so init succeeds
  # without partial-config flags. Real frameworks replace this.
}

# region ------ [ Real Backends (commented) ] --------------------------------------------- #

# Amazon S3 with native state locking via S3 + use_lockfile (Terraform >= 1.10).
# Requires AWS credentials at runtime (typically via OIDC).
#
# terraform {
#   backend "s3" {
#     encrypt                     = true
#     insecure                    = false
#     skip_credentials_validation = false
#     use_fips_endpoint           = true
#     use_lockfile                = true
#     # bucket / key / region passed via -backend-config or backend-config file
#   }
# }

# Google Cloud Storage with native state locking.
# Requires application-default credentials at runtime.
#
# terraform {
#   backend "gcs" {
#     # bucket / prefix passed via -backend-config or backend-config file
#   }
# }

# Azure Blob Storage with native state locking.
# Requires Azure credentials at runtime.
#
# terraform {
#   backend "azurerm" {
#     # resource_group_name / storage_account_name / container_name / key
#     # passed via -backend-config or backend-config file
#   }
# }

# HCP Terraform / Terraform Cloud — remote runs + state.
#
# terraform {
#   cloud {
#     organization = "<your-org>"
#     workspaces { name = "<workspace>" }
#   }
# }

# endregion --- [ Real Backends (commented) ] --------------------------------------------- #
