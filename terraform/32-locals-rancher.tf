#% =========================================================================================== %#
#% = File: 32-locals-rancher.tf                                  | Category: locals (30-39) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#

# Statically Configured LOCALS
locals {
  namespace_psa_labels = {
    "pod-security.kubernetes.io/enforce"         = "restricted"
    "pod-security.kubernetes.io/enforce-version" = "latest"
    "pod-security.kubernetes.io/audit"           = "restricted"
    "pod-security.kubernetes.io/audit-version"   = "latest"
    "pod-security.kubernetes.io/warn"            = "restricted"
    "pod-security.kubernetes.io/warn-version"    = "latest"
  }
}


# Dynamically Configured LOCALS
locals {

  chart_path = coalesce(var.chart_path, "${path.root}/chart")

  platform_values = {
    platform = {
      ingress                 = var.ingress
      replicas                = var.replicas
      hpa                     = var.hpa
      resources               = var.resources
      vault_secret_references = var.vault_secret_references
      persistent_storage      = var.persistent_storage
      escape_hatches = merge(
        var.escape_hatches,
        {
          persistent_storage = var.persistent_storage != null
        }
      )
      platform_caps = var.platform_caps
    }
  }

  helm_values = [
    yamlencode(merge(var.values, local.platform_values))
  ]

}
