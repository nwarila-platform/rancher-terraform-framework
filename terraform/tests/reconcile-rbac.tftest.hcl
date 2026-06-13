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

  cluster_id   = "c-mock"
  project_name = "tenant-project"

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
      module.envelope.reconcile_service_account_names["app"] == "nwarila-tenant-reconciler" &&
      module.envelope.reconcile_service_account_namespaces["app"] == module.envelope.namespace_names["app"] &&
      module.envelope.reconcile_service_account_automount["app"] == false
    )
    error_message = "The reconcile ServiceAccount must be namespace-local and must not automount tokens."
  }

  assert {
    condition = alltrue([
      for rule in module.envelope.reconcile_role_rules :
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
        for rule in module.envelope.reconcile_role_rules :
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
        for rule in module.envelope.reconcile_role_rules :
        contains(rule.api_groups, "") ? rule.resources : []
      ]), resource)
    ])
    error_message = "The reconcile Role must grant approved core resources."
  }

  assert {
    condition = alltrue([
      for resource in ["jobs", "cronjobs"] :
      contains(flatten([
        for rule in module.envelope.reconcile_role_rules :
        contains(rule.api_groups, "batch") ? rule.resources : []
      ]), resource)
    ])
    error_message = "The reconcile Role must grant approved batch resources."
  }

  assert {
    condition = (
      contains(flatten([
        for rule in module.envelope.reconcile_role_rules :
        contains(rule.api_groups, "networking.k8s.io") ? rule.resources : []
      ]), "ingresses") &&
      contains(flatten([
        for rule in module.envelope.reconcile_role_rules :
        contains(rule.api_groups, "autoscaling") ? rule.resources : []
      ]), "horizontalpodautoscalers") &&
      contains(flatten([
        for rule in module.envelope.reconcile_role_rules :
        contains(rule.api_groups, "policy") ? rule.resources : []
      ]), "poddisruptionbudgets") &&
      contains(flatten([
        for rule in module.envelope.reconcile_role_rules :
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
        for rule in module.envelope.reconcile_role_rules : rule.resources
      ]), resource)
    ])
    error_message = "The reconcile Role must deny non-approved kinds by omitting their resources."
  }

  assert {
    condition = (
      module.envelope.reconcile_role_binding_subjects["app"].kind == "ServiceAccount" &&
      module.envelope.reconcile_role_binding_subjects["app"].name == module.envelope.reconcile_service_account_names["app"] &&
      module.envelope.reconcile_role_binding_subjects["app"].namespace == module.envelope.reconcile_service_account_namespaces["app"] &&
      module.envelope.reconcile_role_binding_role_refs["app"].kind == "Role" &&
      module.envelope.reconcile_role_binding_role_refs["app"].name == module.envelope.reconcile_role_names["app"]
    )
    error_message = "The reconcile RoleBinding must bind the namespace-local ServiceAccount to the namespace Role."
  }

  assert {
    condition     = output.reconcile_service_account_names["app"] == "nwarila-tenant-reconciler"
    error_message = "The reconcile ServiceAccount output must expose only the ServiceAccount name."
  }
}
