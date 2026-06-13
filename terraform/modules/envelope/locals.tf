# ============================================================================================ #
# locals.tf - Local values for envelope module                                                 #
# ============================================================================================ #

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
