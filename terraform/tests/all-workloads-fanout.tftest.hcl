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
    condition     = module.envelope.namespace_names["api"] != module.envelope.namespace_names["web"]
    error_message = "Each workload must get a distinct Rancher namespace."
  }

  assert {
    condition = (
      module.envelope.namespace_project_ids["api"] == "c-mock:p-mock" &&
      module.envelope.namespace_project_ids["web"] == "c-mock:p-mock"
    )
    error_message = "Every workload namespace must be assigned to the one tenant Rancher project."
  }

  assert {
    condition = (
      module.envelope.namespace_labels["api"]["pod-security.kubernetes.io/enforce"] == "restricted" &&
      module.envelope.namespace_labels["web"]["pod-security.kubernetes.io/enforce"] == "restricted"
    )
    error_message = "Every workload namespace must carry PSA Restricted enforce labels."
  }

  assert {
    condition = (
      module.deploy.namespace_names["api"] == module.envelope.namespace_names["api"] &&
      module.deploy.namespace_names["web"] == module.envelope.namespace_names["web"]
    )
    error_message = "Every Helm release must target its own Rancher-created namespace."
  }

  assert {
    condition     = module.envelope.namespace_names["web"] == "web"
    error_message = "A workload without namespace_name must default the namespace name to its key."
  }

  assert {
    condition     = module.deploy.helm_release_names["web"] == "web"
    error_message = "A workload without release_name must default the Helm release name to its key."
  }

  assert {
    condition     = endswith(module.deploy.chart_paths["web"], "/chart")
    error_message = "A workload without chart_path must default to the root module chart path."
  }

  assert {
    condition = (
      module.deploy.helm_release_create_namespace["api"] == false &&
      module.deploy.helm_release_create_namespace["web"] == false
    )
    error_message = "Helm must not create namespaces for any workload."
  }

  assert {
    condition = (
      module.deploy.helm_release_skip_crds["api"] == true &&
      module.deploy.helm_release_skip_crds["web"] == true
    )
    error_message = "Tenant charts must not install CRDs through Helm."
  }
}
