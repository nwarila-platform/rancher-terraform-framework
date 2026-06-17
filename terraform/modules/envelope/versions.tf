# ============================================================================================ #
# versions.tf - Terraform version and provider requirements for envelope module                #
# ============================================================================================ #

terraform {
  required_version = "= 1.15.6"

  required_providers {

    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 14.1.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.2.0"
    }

  }
}
