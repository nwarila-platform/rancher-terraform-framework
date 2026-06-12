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

run "valid_contract_accepts_defaults" {
  command = plan

  assert {
    condition     = var.replicas <= var.platform_caps.max_replicas
    error_message = "The valid contract fixture must stay within replica caps."
  }

  assert {
    condition = (
      !can(regex("privileged|host_network|host_pid|host_ipc|host_path", lower(jsonencode(var.escape_hatches)))) &&
      !can(regex("privileged|hostNetwork|hostPID|hostIPC|hostPath", helm_release.tenant.values[0]))
    )
    error_message = "Only the audited escape hatches may be exposed."
  }
}

run "rejects_replica_above_platform_cap" {
  command = plan

  variables {
    replicas = 11
  }

  expect_failures = [
    var.replicas,
  ]
}

run "rejects_hpa_above_platform_cap" {
  command = plan

  variables {
    hpa = {
      min_replicas                      = 2
      max_replicas                      = 11
      target_cpu_utilization_percentage = 70
    }
  }

  expect_failures = [
    var.hpa,
  ]
}

run "rejects_cpu_quantities_outside_caps" {
  command = plan

  variables {
    resources = {
      requests = {
        cpu    = "600m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "700m"
        memory = "512Mi"
      }
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "rejects_memory_request_above_limit" {
  command = plan

  variables {
    platform_caps = {
      max_memory_request = "1Gi"
    }
    resources = {
      requests = {
        cpu    = "100m"
        memory = "768Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
  }

  expect_failures = [
    var.resources,
  ]
}

run "rejects_invalid_ingress_host_and_path" {
  command = plan

  variables {
    ingress = {
      host = "Bad_Host.example.test"
      path = "app"
    }
  }

  expect_failures = [
    var.ingress,
  ]
}

run "rejects_persistent_storage_outside_caps" {
  command = plan

  variables {
    platform_caps = {
      max_persistent_storage_size = "1Gi"
      allowed_storage_classes     = ["standard"]
    }
    persistent_storage = {
      size          = "2Gi"
      storage_class = "standard"
    }
  }

  expect_failures = [
    var.persistent_storage,
  ]
}

run "rejects_disallowed_storage_class" {
  command = plan

  variables {
    platform_caps = {
      allowed_storage_classes = ["standard"]
    }
    persistent_storage = {
      size          = "1Gi"
      storage_class = "fast"
    }
  }

  expect_failures = [
    var.persistent_storage,
  ]
}

run "rejects_empty_vault_reference_path" {
  command = plan

  variables {
    vault_secret_references = {
      app_config = {
        path = ""
      }
    }
  }

  expect_failures = [
    var.vault_secret_references,
  ]
}

run "rejects_raw_secret_looking_values" {
  command = plan

  variables {
    values = {
      application = {
        apiKey = "inline-secret"
      }
    }
  }

  expect_failures = [
    var.values,
  ]
}

run "rejects_load_balancer_quota_override" {
  command = plan

  variables {
    platform_resource_quota = {
      project_limit = {
        services_load_balancers = "1"
      }
    }
  }

  expect_failures = [
    var.platform_resource_quota,
  ]
}

run "rejects_invalid_platform_cap_quantities" {
  command = plan

  variables {
    platform_caps = {
      min_cpu_request = "0.1"
    }
  }

  expect_failures = [
    var.platform_caps,
  ]
}

run "rejects_multiple_reconciler_principals" {
  command = plan

  variables {
    tenant_reconciler_principal = {
      group_principal_id = "local://tenant-reconcilers"
      user_principal_id  = "local://tenant-user"
    }
  }

  expect_failures = [
    var.tenant_reconciler_principal,
  ]
}
