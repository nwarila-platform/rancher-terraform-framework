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
      release_name   = "tenant-release"
      chart_path     = "./chart"

      ingress = {
        host = "tenant.example.test"
        path = "/app"
      }

      values = {
        workload = {
          image = {
            repository = "registry.example.test/app"
            digest     = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
          }
        }
      }
    }
  ]
}

run "helm_release_uses_local_chart_namespace_and_values" {
  command = plan

  assert {
    condition     = helm_release.workload["app"].name == var.all_workloads[0].release_name
    error_message = "The Helm release must use the requested release name."
  }

  assert {
    condition     = helm_release.workload["app"].chart == var.all_workloads[0].chart_path
    error_message = "The Helm release must deploy the configured local chart path."
  }

  assert {
    condition     = helm_release.workload["app"].namespace == rancher2_namespace.workload["app"].name
    error_message = "The Helm release must target the Rancher-created namespace."
  }

  assert {
    condition     = helm_release.workload["app"].create_namespace == false
    error_message = "Helm must not create namespaces; Rancher owns the namespace envelope."
  }

  assert {
    condition     = helm_release.workload["app"].skip_crds == true
    error_message = "Tenant charts must not install CRDs through Helm."
  }

  assert {
    condition     = can(regex("tenant.example.test", helm_release.workload["app"].values[0]))
    error_message = "The Helm release values must include the platform ingress contract."
  }
}
