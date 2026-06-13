# ============================================================================================ #
# resources.tf - Helm release resources for deploy module                                      #
# ============================================================================================ #


#region ------ [ Deploy Tenant-Owned Local Chart ] ------------------------------------------- #

resource "helm_release" "workload" {
  for_each = var.workloads

  # Deploy each tenant-owned chart into its platform-created namespace.
  name              = each.value.release_name
  chart             = each.value.chart_path
  namespace         = each.value.namespace_name
  values            = each.value.helm_values
  create_namespace  = false
  skip_crds         = true
  disable_crd_hooks = true
  atomic            = true
  wait              = true

}

#endregion --- [ Deploy Tenant-Owned Local Chart ] ------------------------------------------- #
