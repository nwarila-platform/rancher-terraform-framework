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
      key = "app"

      ingress = {
        host = "tenant.example.test"
        path = "/"
      }
    }
  ]
}

run "accepts_benign_values_and_valid_vault_reference" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        vault_secret_references = {
          app_config = {
            path    = "kv/data/tenants/app/config"
            engine  = "kv-v2"
            version = 1
            templates = {
              DATABASE_URL = "database_url"
            }
          }
        }

        values = {
          workload = {
            config = {
              mode              = "api"
              token_secret_name = "tenant-app-token"
            }
          }
        }
      }
    ]
  }
}

run "rejects_values_platform_reserved_key" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        values = {
          platform = {
            replicas = 99
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_values_obvious_inline_secret" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        values = {
          password = "hunter2"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_values_pem_private_key_marker" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        values = {
          tls = {
            certificate_bundle = "-----BEGIN PRIVATE KEY-----"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_vault_reference_empty_path" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        vault_secret_references = {
          app_config = {
            path = ""
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_vault_reference_invalid_engine" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        vault_secret_references = {
          app_config = {
            path   = "kv/data/tenants/app/config"
            engine = "database"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_vault_reference_non_positive_version" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        vault_secret_references = {
          app_config = {
            path    = "kv/data/tenants/app/config"
            version = 0
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}
