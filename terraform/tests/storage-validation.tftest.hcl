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

run "accepts_persistent_storage_with_allowed_class_and_size" {
  command = plan

  variables {
    platform_caps = {
      max_persistent_storage_size = "10Gi"
      allowed_storage_classes     = ["standard", "fast-ssd"]
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        persistent_storage = {
          size          = "512Mi"
          storage_class = "fast-ssd"
          mount_path    = "/data"
        }
      }
    ]
  }
}

run "accepts_null_persistent_storage" {
  command = plan

  variables {
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
}

run "rejects_persistent_storage_size_above_platform_cap" {
  command = plan

  variables {
    platform_caps = {
      max_persistent_storage_size = "10Gi"
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        persistent_storage = {
          size          = "20Gi"
          storage_class = "standard"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_persistent_storage_class_outside_allowlist" {
  command = plan

  variables {
    platform_caps = {
      allowed_storage_classes = ["standard"]
    }

    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        persistent_storage = {
          size          = "5Gi"
          storage_class = "fast-ssd"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_invalid_persistent_storage_size_quantity" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        persistent_storage = {
          size          = "1Ti"
          storage_class = "standard"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}

run "rejects_persistent_storage_mount_path_without_leading_slash" {
  command = plan

  variables {
    all_workloads = [
      {
        key = "app"

        ingress = {
          host = "tenant.example.test"
          path = "/"
        }

        persistent_storage = {
          size          = "5Gi"
          storage_class = "standard"
          mount_path    = "data"
        }
      }
    ]
  }

  expect_failures = [
    var.all_workloads,
  ]
}
