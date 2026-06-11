terraform {

  # Specify the required Terraform version. Per template-tier ADR-0001
  # (pin Terraform and provider versions exactly), exact pins only —
  # the `~>` pessimistic operator is rejected by the OPA policy in
  # policies/opa/repo_hygiene.rego.
  required_version = "= 1.15.4"

  # Specify the required providers. All five are official HashiCorp
  # providers selected for the do-nothing showcase: each demonstrates
  # a distinct framework pattern (state-only resources, deterministic
  # data generation, real artifact production, time-based lifecycle,
  # crypto material generation) without touching any external service
  # or accruing cost.
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "= 3.2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.8.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.8.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.13.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.2.1"
    }
  }

}
