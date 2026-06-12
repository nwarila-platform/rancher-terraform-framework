#% =========================================================================================== %#
#% = File: 02-provider-rancher2.tf                               | Category: Providers (00-09) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% =========================================================================================== %#

provider "rancher2" {

  // Configure Rancher admin-mode API access from caller-supplied credentials.
  api_url   = var.rancher_config.api_url
  token_key = var.rancher_config.token_key
  insecure  = var.rancher_config.insecure
  ca_certs  = var.rancher_config.ca_certs

}
