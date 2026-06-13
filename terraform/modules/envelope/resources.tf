# ============================================================================================ #
# resources.tf - Rancher envelope and restricted reconcile RBAC                                #
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
  for_each = var.workloads

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

#endregion --- [ Create Rancher Tenant Envelope ] -------------------------------------------- #


#region ------ [ Create Restricted Reconcile RBAC ] ------------------------------------------ #

resource "kubernetes_service_account_v1" "tenant_reconciler" {
  for_each = var.workloads

  # Create the restricted reconcile identity in each workload namespace.
  metadata {
    name      = local.tenant_reconcile_identity_name
    namespace = rancher2_namespace.workload[each.key].name
  }

  automount_service_account_token = false

}

resource "kubernetes_role_v1" "tenant_reconciler" {
  for_each = var.workloads

  # Grant only the approved chart reconciliation surface from ADR-repo/0009.
  metadata {
    name      = local.tenant_reconcile_identity_name
    namespace = rancher2_namespace.workload[each.key].name
  }

  dynamic "rule" {
    for_each = local.tenant_reconcile_role_rules

    content {
      api_groups = rule.value.api_groups
      resources  = rule.value.resources
      verbs      = rule.value.verbs
    }
  }

}

resource "kubernetes_role_binding_v1" "tenant_reconciler" {
  for_each = var.workloads

  # Bind the namespace-local reconcile ServiceAccount to its allowlisted Role.
  metadata {
    name      = local.tenant_reconcile_identity_name
    namespace = rancher2_namespace.workload[each.key].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.tenant_reconciler[each.key].metadata[0].name
    namespace = kubernetes_service_account_v1.tenant_reconciler[each.key].metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.tenant_reconciler[each.key].metadata[0].name
  }

}

#endregion --- [ Create Restricted Reconcile RBAC ] ------------------------------------------ #
