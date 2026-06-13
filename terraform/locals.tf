# ============================================================================================ #
# locals.tf — Local values for Rancher framework                                                #
# ============================================================================================ #

# Statically Configured LOCALS
locals {
  tenant_reconcile_identity_name = "nwarila-tenant-reconciler"

  namespace_psa_labels = {
    "pod-security.kubernetes.io/enforce"         = "restricted"
    "pod-security.kubernetes.io/enforce-version" = "latest"
    "pod-security.kubernetes.io/audit"           = "restricted"
    "pod-security.kubernetes.io/audit-version"   = "latest"
    "pod-security.kubernetes.io/warn"            = "restricted"
    "pod-security.kubernetes.io/warn-version"    = "latest"
  }

  tenant_reconcile_verbs = [
    "get",
    "list",
    "watch",
    "create",
    "update",
    "patch",
    "delete",
  ]

  # RBAC mirror of policies/kyverno/restrict-object-kinds.yaml; change both together.
  tenant_reconcile_role_rules = [
    {
      api_groups = [""]
      resources = [
        "configmaps",
        "persistentvolumeclaims",
        "services",
        "serviceaccounts",
      ]
      verbs = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["apps"]
      resources = [
        "deployments",
        "statefulsets",
      ]
      verbs = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["batch"]
      resources = [
        "cronjobs",
        "jobs",
      ]
      verbs = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["networking.k8s.io"]
      resources  = ["ingresses"]
      verbs      = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["autoscaling"]
      resources  = ["horizontalpodautoscalers"]
      verbs      = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["policy"]
      resources  = ["poddisruptionbudgets"]
      verbs      = local.tenant_reconcile_verbs
    },
    {
      api_groups = ["secrets.hashicorp.com"]
      resources  = ["vaultstaticsecrets"]
      verbs      = local.tenant_reconcile_verbs
    },
  ]
}


# Validation Helper LOCALS
locals {
  cpu_quantity_pattern    = "^(0\\.[0-9]{1,3}|[1-9][0-9]*(\\.[0-9]{1,3})?|[1-9][0-9]*m)$"
  memory_quantity_pattern = "^[1-9][0-9]*(Mi|Gi)$"
  values_raw_secret_signal_pattern = (
    "\"(password|passwd|secret|token|api[-_]?key|private[-_]?key|client[-_]?secret|access[-_]?token|refresh[-_]?token)\"[[:space:]]*:[[:space:]]*\"[^\"]+\""
  )
  values_pem_private_key_pattern = "-----begin [a-z0-9 ]*private key-----"
  vault_secret_reference_engines = ["kv-v1", "kv-v2"]
  rfc1123_dns_subdomain_pattern = (
    "^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?)*$"
  )

  platform_cap_cpu_millicores = {
    max_request = try(
      endswith(var.platform_caps.max_cpu_request, "m")
      ? tonumber(trimsuffix(var.platform_caps.max_cpu_request, "m"))
      : tonumber(var.platform_caps.max_cpu_request) * 1000,
      -1
    )
    max_limit = try(
      endswith(var.platform_caps.max_cpu_limit, "m")
      ? tonumber(trimsuffix(var.platform_caps.max_cpu_limit, "m"))
      : tonumber(var.platform_caps.max_cpu_limit) * 1000,
      -1
    )
  }

  platform_cap_memory_mib = {
    max_request = try(
      tonumber(trimsuffix(trimsuffix(var.platform_caps.max_memory_request, "Mi"), "Gi")) *
      (endswith(var.platform_caps.max_memory_request, "Gi") ? 1024 : 1),
      -1
    )
    max_limit = try(
      tonumber(trimsuffix(trimsuffix(var.platform_caps.max_memory_limit, "Mi"), "Gi")) *
      (endswith(var.platform_caps.max_memory_limit, "Gi") ? 1024 : 1),
      -1
    )
  }

  platform_cap_persistent_storage_mib = try(
    tonumber(trimsuffix(trimsuffix(var.platform_caps.max_persistent_storage_size, "Mi"), "Gi")) *
    (endswith(var.platform_caps.max_persistent_storage_size, "Gi") ? 1024 : 1),
    -1
  )
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
