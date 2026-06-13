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

run "rancher_envelope_wires_project_namespace_and_psa" {
  command = plan

  assert {
    condition     = module.envelope.project_cluster_id == var.cluster_id
    error_message = "The Rancher project must target the requested downstream cluster."
  }

  assert {
    condition     = module.envelope.project_limit_cpu == var.platform_resource_quota.project_limit.limits_cpu
    error_message = "The Rancher project quota must use the platform project CPU cap."
  }

  assert {
    condition     = module.envelope.namespace_project_ids["app"] == "c-mock:p-mock"
    error_message = "The namespace must be assigned to the framework-created Rancher project."
  }

  assert {
    condition     = module.envelope.namespace_labels["app"]["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "The namespace must carry PSA Restricted enforce labels."
  }

  assert {
    condition     = module.envelope.reconcile_service_account_names["app"] == "nwarila-tenant-reconciler"
    error_message = "The envelope must create the namespace-local restricted reconcile ServiceAccount."
  }
}
