# ============================================================================================ #
# resources.tf — Rancher envelope and Helm release resources for Rancher framework              #
# ============================================================================================ #


#region ------ [ Create Rancher Tenant Envelope ] -------------------------------------------- #

resource "rancher2_project" "tenant" {

  # Create the Rancher project that owns the tenant namespaces.
  name        = var.project_name
  cluster_id  = var.cluster_id
  description = var.project_description

  resource_quota {
    project_limit {
      config_maps              = var.platform_resource_quota.project_limit.config_maps
      limits_cpu               = var.platform_resource_quota.project_limit.limits_cpu
      limits_memory            = var.platform_resource_quota.project_limit.limits_memory
      persistent_volume_claims = var.platform_resource_quota.project_limit.persistent_volume_claims
      pods                     = var.platform_resource_quota.project_limit.pods
      replication_controllers  = var.platform_resource_quota.project_limit.replication_controllers
      requests_cpu             = var.platform_resource_quota.project_limit.requests_cpu
      requests_memory          = var.platform_resource_quota.project_limit.requests_memory
      requests_storage         = var.platform_resource_quota.project_limit.requests_storage
      secrets                  = var.platform_resource_quota.project_limit.secrets
      services_load_balancers  = var.platform_resource_quota.project_limit.services_load_balancers
      services_node_ports      = var.platform_resource_quota.project_limit.services_node_ports
    }

    namespace_default_limit {
      config_maps              = var.platform_resource_quota.namespace_default_limit.config_maps
      limits_cpu               = var.platform_resource_quota.namespace_default_limit.limits_cpu
      limits_memory            = var.platform_resource_quota.namespace_default_limit.limits_memory
      persistent_volume_claims = var.platform_resource_quota.namespace_default_limit.persistent_volume_claims
      pods                     = var.platform_resource_quota.namespace_default_limit.pods
      replication_controllers  = var.platform_resource_quota.namespace_default_limit.replication_controllers
      requests_cpu             = var.platform_resource_quota.namespace_default_limit.requests_cpu
      requests_memory          = var.platform_resource_quota.namespace_default_limit.requests_memory
      requests_storage         = var.platform_resource_quota.namespace_default_limit.requests_storage
      secrets                  = var.platform_resource_quota.namespace_default_limit.secrets
      services_load_balancers  = var.platform_resource_quota.namespace_default_limit.services_load_balancers
      services_node_ports      = var.platform_resource_quota.namespace_default_limit.services_node_ports
    }
  }

  container_resource_limit {
    limits_cpu      = var.platform_resource_quota.container_resource_limit.limits_cpu
    limits_memory   = var.platform_resource_quota.container_resource_limit.limits_memory
    requests_cpu    = var.platform_resource_quota.container_resource_limit.requests_cpu
    requests_memory = var.platform_resource_quota.container_resource_limit.requests_memory
  }

}

resource "rancher2_namespace" "workload" {
  for_each = local.workloads

  # Create each workload namespace under the Rancher project with PSA labels fixed on.
  name        = each.value.namespace_name
  project_id  = rancher2_project.tenant.id
  description = "Tenant workload namespace ${each.key} managed by the NWarila Rancher Terraform framework."
  labels      = local.namespace_psa_labels

  resource_quota {
    limit {
      config_maps              = var.platform_resource_quota.namespace_limit.config_maps
      limits_cpu               = var.platform_resource_quota.namespace_limit.limits_cpu
      limits_memory            = var.platform_resource_quota.namespace_limit.limits_memory
      persistent_volume_claims = var.platform_resource_quota.namespace_limit.persistent_volume_claims
      pods                     = var.platform_resource_quota.namespace_limit.pods
      replication_controllers  = var.platform_resource_quota.namespace_limit.replication_controllers
      requests_cpu             = var.platform_resource_quota.namespace_limit.requests_cpu
      requests_memory          = var.platform_resource_quota.namespace_limit.requests_memory
      requests_storage         = var.platform_resource_quota.namespace_limit.requests_storage
      secrets                  = var.platform_resource_quota.namespace_limit.secrets
      services_load_balancers  = var.platform_resource_quota.namespace_limit.services_load_balancers
      services_node_ports      = var.platform_resource_quota.namespace_limit.services_node_ports
    }
  }

  container_resource_limit {
    limits_cpu      = var.platform_resource_quota.container_resource_limit.limits_cpu
    limits_memory   = var.platform_resource_quota.container_resource_limit.limits_memory
    requests_cpu    = var.platform_resource_quota.container_resource_limit.requests_cpu
    requests_memory = var.platform_resource_quota.container_resource_limit.requests_memory
  }

}

resource "rancher2_project_role_template_binding" "tenant_reconciler" {

  # Bind the tenant reconcile identity to an existing platform-owned role template.
  name               = "${var.project_name}-tenant-reconciler"
  project_id         = rancher2_project.tenant.id
  role_template_id   = var.tenant_reconciler_role_template_id
  group_id           = var.tenant_reconciler_principal.group_id
  group_principal_id = var.tenant_reconciler_principal.group_principal_id
  user_id            = var.tenant_reconciler_principal.user_id
  user_principal_id  = var.tenant_reconciler_principal.user_principal_id

}

#endregion --- [ Create Rancher Tenant Envelope ] -------------------------------------------- #


#region ------ [ Deploy Tenant-Owned Local Chart ] ------------------------------------------- #

resource "helm_release" "workload" {
  for_each = local.workloads

  # Deploy each tenant-owned chart into its framework-created namespace.
  name              = each.value.release_name
  chart             = each.value.chart_path
  namespace         = rancher2_namespace.workload[each.key].name
  values            = each.value.helm_values
  create_namespace  = false
  skip_crds         = true
  disable_crd_hooks = true
  atomic            = true
  wait              = true

  depends_on = [
    rancher2_project.tenant,
    rancher2_project_role_template_binding.tenant_reconciler
  ]

}

#endregion --- [ Deploy Tenant-Owned Local Chart ] ------------------------------------------- #
