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
  namespace_name                     = "tenant-app"
  release_name                       = "tenant-release"
  chart_path                         = "./chart"
  tenant_reconciler_role_template_id = "nwarila-tenant-reconciler"
  tenant_reconciler_principal = {
    group_principal_id = "local://tenant-reconcilers"
  }

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

run "helm_release_uses_local_chart_namespace_and_values" {
  command = plan

  assert {
    condition     = helm_release.tenant.name == var.release_name
    error_message = "The Helm release must use the requested release name."
  }

  assert {
    condition     = helm_release.tenant.chart == var.chart_path
    error_message = "The Helm release must deploy the configured local chart path."
  }

  assert {
    condition     = helm_release.tenant.namespace == rancher2_namespace.tenant.name
    error_message = "The Helm release must target the Rancher-created namespace."
  }

  assert {
    condition     = helm_release.tenant.create_namespace == false
    error_message = "Helm must not create namespaces; Rancher owns the namespace envelope."
  }

  assert {
    condition     = helm_release.tenant.skip_crds == true
    error_message = "Tenant charts must not install CRDs through Helm."
  }

  assert {
    condition     = can(regex("tenant.example.test", helm_release.tenant.values[0]))
    error_message = "The Helm release values must include the platform ingress contract."
  }
}
