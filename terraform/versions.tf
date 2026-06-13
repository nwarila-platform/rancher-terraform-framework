# ============================================================================================ #
# versions.tf — Terraform version and provider requirements for Rancher framework               #
# ============================================================================================ #

terraform {

  # Declare exact Terraform version used by CI.
  required_version = "= 1.15.4"

  # Declare exact provider versions.
  required_providers {

    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 14.1.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "= 3.2.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.2.0"
    }

  }

}
