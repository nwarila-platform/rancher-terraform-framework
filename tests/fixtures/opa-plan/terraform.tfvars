rancher_config = {
  api_url   = "https://rancher.test.invalid"
  token_key = "test-token-not-a-secret"
  insecure  = true
}

helm_kubernetes = {
  host     = "https://kubernetes.test.invalid"
  token    = "test-token-not-a-secret"
  insecure = true
}

cluster_id                         = "c-mock"
project_name                       = "tenant-project"
namespace_name                     = "tenant-app"
release_name                       = "tenant-release"
chart_path                         = "../../../tests/fixtures/opa-plan/chart"
tenant_reconciler_role_template_id = "nwarila-tenant-reconciler"
tenant_reconciler_principal = {
  group_principal_id = "local://tenant-reconcilers"
}

ingress = {
  host = "tenant.example.test"
  path = "/"
}

values = {
  workload = {
    image = {
      repository = "registry.example.test/app"
      digest     = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
    }
  }
}
