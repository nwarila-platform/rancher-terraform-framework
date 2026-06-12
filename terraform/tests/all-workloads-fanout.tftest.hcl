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
      key            = "api"
      namespace_name = "tenant-api"
      release_name   = "tenant-api"
      chart_path     = "./charts/api"

      ingress = {
        host = "api.tenant.example.test"
        path = "/api"
      }
    },
    {
      key = "web"

      ingress = {
        host = "web.tenant.example.test"
        path = "/"
      }
    }
  ]
}

run "all_workloads_fan_out_namespaces_and_releases" {
  command = plan

  assert {
    condition     = rancher2_namespace.workload["api"].name != rancher2_namespace.workload["web"].name
    error_message = "Each workload must get a distinct Rancher namespace."
  }

  assert {
    condition = (
      rancher2_namespace.workload["api"].project_id == "c-mock:p-mock" &&
      rancher2_namespace.workload["web"].project_id == "c-mock:p-mock"
    )
    error_message = "Every workload namespace must be assigned to the one tenant Rancher project."
  }

  assert {
    condition = (
      rancher2_namespace.workload["api"].labels["pod-security.kubernetes.io/enforce"] == "restricted" &&
      rancher2_namespace.workload["web"].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    )
    error_message = "Every workload namespace must carry PSA Restricted enforce labels."
  }

  assert {
    condition = (
      helm_release.workload["api"].namespace == rancher2_namespace.workload["api"].name &&
      helm_release.workload["web"].namespace == rancher2_namespace.workload["web"].name
    )
    error_message = "Every Helm release must target its own Rancher-created namespace."
  }

  assert {
    condition     = rancher2_namespace.workload["web"].name == "web"
    error_message = "A workload without namespace_name must default the namespace name to its key."
  }

  assert {
    condition     = helm_release.workload["web"].name == "web"
    error_message = "A workload without release_name must default the Helm release name to its key."
  }

  assert {
    condition     = endswith(helm_release.workload["web"].chart, "/chart")
    error_message = "A workload without chart_path must default to the root module chart path."
  }

  assert {
    condition = (
      helm_release.workload["api"].create_namespace == false &&
      helm_release.workload["web"].create_namespace == false
    )
    error_message = "Helm must not create namespaces for any workload."
  }

  assert {
    condition = (
      helm_release.workload["api"].skip_crds == true &&
      helm_release.workload["web"].skip_crds == true
    )
    error_message = "Tenant charts must not install CRDs through Helm."
  }
}
