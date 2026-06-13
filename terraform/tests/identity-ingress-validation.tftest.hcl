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
      key = "app"

      ingress = {
        host = "tenant.example.test"
        path = "/"
      }
    }
  ]
}

run "accepts_unique_identities_and_rfc1123_ingress" {
  command = plan

  variables {
    all_workloads = [
      {
        key            = "api"
        namespace_name = "tenant-api"
        release_name   = "api"

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
}

run "rejects_duplicate_workload_keys" {
  command = plan

  variables {
    all_workloads = [
      {
        key            = "app"
        namespace_name = "tenant-app-a"

        ingress = {
          host = "app-a.tenant.example.test"
          path = "/"
        }
      },
      {
        key            = "app"
        namespace_name = "tenant-app-b"

        ingress = {
          host = "app-b.tenant.example.test"
          path = "/"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_duplicate_resolved_namespace_names" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "a"

        ingress = {
          host = "a.tenant.example.test"
          path = "/"
        }
      },
      {
        key            = "b"
        namespace_name = "a"

        ingress = {
          host = "b.tenant.example.test"
          path = "/"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_duplicate_ingress_hosts" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "api"

        ingress = {
          host = "tenant.example.test"
          path = "/api"
        }
      },
      {
        key = "web"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_invalid_ingress_host" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "Bad_Host!"
          path = "/"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_ingress_path_without_leading_slash" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "app"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}
