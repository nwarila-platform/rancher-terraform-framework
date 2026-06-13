mock_provider "rancher2" {
  override_during = plan

  mock_resource "rancher2_project" {
    defaults = {
      id = "c-mock:p-mock"
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

variables {
  rancher_config = {
    api_url   = "https://rancher.test.invalid"
    token_key = "test-token-not-a-secret"
  }

  cluster_id                         = "c-mock"
  project_name                       = "tenant-project"
  tenant_reconciler_role_template_id = "nwarila-tenant-reconciler"
  tenant_reconciler_principal = {
    group_principal_id = "local://tenant-reconcilers"
  }

  all_workloads = [
    {
      key            = "app"
      namespace_name = "tenant-app"

      ingress = {
        host = "tenant.example.test"
        path = "/"
      }
    }
  ]
}

run "reconcile_rbac_grants_approved_kinds_only" {
  command = plan

  assert {
    condition = (
      kubernetes_service_account_v1.tenant_reconciler["app"].metadata[0].name == "nwarila-tenant-reconciler" &&
      kubernetes_service_account_v1.tenant_reconciler["app"].metadata[0].namespace == rancher2_namespace.workload["app"].name &&
      kubernetes_service_account_v1.tenant_reconciler["app"].automount_service_account_token == false
    )
    error_message = "The reconcile ServiceAccount must be namespace-local and must not automount tokens."
  }

  assert {
    condition = alltrue([
      for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
      length(setsubtract([
        "get",
        "list",
        "watch",
        "create",
        "update",
        "patch",
        "delete",
      ], rule.verbs)) == 0 &&
      length(setsubtract(rule.verbs, [
        "get",
        "list",
        "watch",
        "create",
        "update",
        "patch",
        "delete",
      ])) == 0
    ])
    error_message = "Every reconcile Role rule must use the exact approved reconciliation verbs."
  }

  assert {
    condition = alltrue([
      for resource in ["deployments", "statefulsets"] :
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "apps") ? rule.resources : []
      ]), resource)
    ])
    error_message = "The reconcile Role must grant approved apps resources."
  }

  assert {
    condition = alltrue([
      for resource in [
        "configmaps",
        "persistentvolumeclaims",
        "services",
        "serviceaccounts",
      ] :
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "") ? rule.resources : []
      ]), resource)
    ])
    error_message = "The reconcile Role must grant approved core resources."
  }

  assert {
    condition = alltrue([
      for resource in ["jobs", "cronjobs"] :
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "batch") ? rule.resources : []
      ]), resource)
    ])
    error_message = "The reconcile Role must grant approved batch resources."
  }

  assert {
    condition = (
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "networking.k8s.io") ? rule.resources : []
      ]), "ingresses") &&
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "autoscaling") ? rule.resources : []
      ]), "horizontalpodautoscalers") &&
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "policy") ? rule.resources : []
      ]), "poddisruptionbudgets") &&
      contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule :
        contains(rule.api_groups, "secrets.hashicorp.com") ? rule.resources : []
      ]), "vaultstaticsecrets")
    )
    error_message = "The reconcile Role must grant approved ingress, HPA, PDB, and VaultStaticSecret resources."
  }

  assert {
    condition = alltrue([
      for resource in [
        "secrets",
        "roles",
        "rolebindings",
        "clusterroles",
        "clusterrolebindings",
        "customresourcedefinitions",
        "namespaces",
        "resourcequotas",
        "limitranges",
        "networkpolicies",
        "pods",
        "daemonsets",
        "replicasets",
      ] :
      !contains(flatten([
        for rule in kubernetes_role_v1.tenant_reconciler["app"].rule : rule.resources
      ]), resource)
    ])
    error_message = "The reconcile Role must deny non-approved kinds by omitting their resources."
  }

  assert {
    condition = (
      kubernetes_role_binding_v1.tenant_reconciler["app"].subject[0].kind == "ServiceAccount" &&
      kubernetes_role_binding_v1.tenant_reconciler["app"].subject[0].name == kubernetes_service_account_v1.tenant_reconciler["app"].metadata[0].name &&
      kubernetes_role_binding_v1.tenant_reconciler["app"].subject[0].namespace == kubernetes_service_account_v1.tenant_reconciler["app"].metadata[0].namespace &&
      kubernetes_role_binding_v1.tenant_reconciler["app"].role_ref[0].kind == "Role" &&
      kubernetes_role_binding_v1.tenant_reconciler["app"].role_ref[0].name == kubernetes_role_v1.tenant_reconciler["app"].metadata[0].name
    )
    error_message = "The reconcile RoleBinding must bind the namespace-local ServiceAccount to the namespace Role."
  }

  assert {
    condition     = output.reconcile_service_account_names["app"] == "nwarila-tenant-reconciler"
    error_message = "The reconcile ServiceAccount output must expose only the ServiceAccount name."
  }
}
