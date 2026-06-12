# ============================================================================================ #
# backend.tf — Terraform backend declaration for Rancher framework                              #
# ============================================================================================ #

terraform {

  # Store state file in S3 bucket.
  backend "s3" {}

}
