mock_provider "rancher2" {
  override_during = plan

  mock_resource "rancher2_project" {
    defaults = {
      id = "c-mock:p-mock"
    }
  }
}

mock_provider "helm" {}

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

run "rancher_envelope_wires_project_namespace_and_psa" {
  command = plan

  assert {
    condition     = rancher2_project.tenant.cluster_id == var.cluster_id
    error_message = "The Rancher project must target the requested downstream cluster."
  }

  assert {
    condition     = rancher2_project.tenant.resource_quota[0].project_limit[0].limits_cpu == var.platform_resource_quota.project_limit.limits_cpu
    error_message = "The Rancher project quota must use the platform project CPU cap."
  }

  assert {
    condition     = rancher2_namespace.workload["app"].project_id == "c-mock:p-mock"
    error_message = "The namespace must be assigned to the framework-created Rancher project."
  }

  assert {
    condition     = rancher2_namespace.workload["app"].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "The namespace must carry PSA Restricted enforce labels."
  }

  assert {
    condition     = rancher2_project_role_template_binding.tenant_reconciler.role_template_id == var.tenant_reconciler_role_template_id
    error_message = "The tenant reconciler binding must use the configured role template."
  }

  assert {
    condition     = rancher2_project_role_template_binding.tenant_reconciler.group_principal_id == "local://tenant-reconcilers"
    error_message = "The tenant reconciler binding must target the configured group principal."
  }
}
