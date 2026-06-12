# ============================================================================================ #
# locals.tf — Local values for Rancher framework                                                #
# ============================================================================================ #

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

  workloads = {
    for workload in var.all_workloads : workload.key => merge(workload, {
      namespace_name = coalesce(workload.namespace_name, workload.key)
      release_name   = coalesce(workload.release_name, workload.key)
      chart_path     = coalesce(workload.chart_path, "${path.root}/chart")
      helm_values = [
        yamlencode(
          merge(
            workload.values,
            {
              platform = {
                ingress                 = workload.ingress
                replicas                = workload.replicas
                hpa                     = workload.hpa
                resources               = workload.resources
                vault_secret_references = workload.vault_secret_references
                persistent_storage      = workload.persistent_storage
                escape_hatches = merge(
                  workload.escape_hatches,
                  {
                    persistent_storage = workload.persistent_storage != null
                  }
                )
                platform_caps = var.platform_caps
              }
            }
          )
        )
      ]
    })
  }

}
