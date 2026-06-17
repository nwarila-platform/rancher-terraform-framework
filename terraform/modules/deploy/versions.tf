# ============================================================================================ #
# versions.tf - Terraform version and provider requirements for deploy module                  #
# ============================================================================================ #

terraform {
  required_version = "= 1.15.6"

  required_providers {

    helm = {
      source  = "hashicorp/helm"
      version = "= 3.2.0"
    }

  }
}
