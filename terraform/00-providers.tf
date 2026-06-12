#% =========================================================================================== %#
#% = File: 00-providers.tf                                       | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#
terraform {

  // Declare exact Terraform version used by CI.
  required_version = "= 1.15.4"

  // Store state file in S3 bucket.
  backend "s3" {}

  // Declare exact provider versions.
  required_providers {

    rancher2 = {
      source  = "rancher/rancher2"
      version = "= 14.1.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "= 3.2.0"
    }

  }

}
