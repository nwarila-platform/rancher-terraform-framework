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

run "accepts_caps_with_normalized_cpu_and_memory_quantities" {
  command = plan

  variables {
    platform_caps = {
      max_replicas       = 4
      max_hpa_replicas   = 6
      max_cpu_request    = "1"
      max_cpu_limit      = "1500m"
      max_memory_request = "1Gi"
      max_memory_limit   = "2Gi"
    }

    all_workloads = [
      {
        key      = "app"
        replicas = 4

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        hpa = {
          min_replicas                      = 2
          max_replicas                      = 6
          target_cpu_utilization_percentage = 80
        }

        resources = {
          requests = {
            cpu    = "1"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1500m"
            memory = "2Gi"
          }
        }
      }
    ]
  }
}

run "rejects_replicas_above_platform_cap" {
  command = plan

  variables {
    platform_caps = {
      max_replicas = 2
    }

    all_workloads = [
      {
        key      = "app"
        replicas = 3

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

run "rejects_hpa_max_above_platform_cap" {
  command = plan

  variables {
    platform_caps = {
      max_hpa_replicas = 5
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        hpa = {
          min_replicas                      = 2
          max_replicas                      = 6
          target_cpu_utilization_percentage = 70
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_hpa_min_above_hpa_max" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        hpa = {
          min_replicas                      = 4
          max_replicas                      = 3
          target_cpu_utilization_percentage = 70
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_hpa_target_cpu_outside_percentage_range" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        hpa = {
          min_replicas                      = 2
          max_replicas                      = 4
          target_cpu_utilization_percentage = 101
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_invalid_cpu_quantity_precision" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        resources = {
          requests = {
            cpu    = "0.0005"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_cpu_request_above_platform_cap" {
  command = plan

  variables {
    platform_caps = {
      max_cpu_request = "500m"
      max_cpu_limit   = "2"
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        resources = {
          requests = {
            cpu    = "1"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1500m"
            memory = "512Mi"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_memory_limit_above_platform_cap" {
  command = plan

  variables {
    platform_caps = {
      max_memory_limit = "1Gi"
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "2Gi"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_cpu_request_above_cpu_limit" {
  command = plan

  variables {
    platform_caps = {
      max_cpu_request = "1"
      max_cpu_limit   = "1"
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        resources = {
          requests = {
            cpu    = "750m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_memory_request_above_memory_limit" {
  command = plan

  variables {
    platform_caps = {
      max_memory_request = "1Gi"
      max_memory_limit   = "1Gi"
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}
