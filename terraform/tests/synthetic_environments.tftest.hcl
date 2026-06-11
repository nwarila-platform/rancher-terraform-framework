# terraform test — exercises the framework end-to-end with real
# apply against the synthetic providers. Generates real tfstate inside
# the sandbox, asserts on outputs, then tears down. No external
# services involved.

# region ------ [ Run 1: single environment, minimum required inputs ] -------------------- #

run "single_environment_minimum" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-single-env-min"

    all_environments = [
      {
        name  = "minimal"
        owner = "test-suite"
        tier  = "dev"
      }
    ]
  }

  # The framework always produces these per environment.
  assert {
    condition     = output.framework_summary.environments_total == 1
    error_message = "Expected exactly 1 environment in framework_summary; got ${output.framework_summary.environments_total}."
  }

  assert {
    condition     = output.framework_summary.environments_with_cert == 0
    error_message = "Expected 0 environments with cert when no certificate input was provided; got ${output.framework_summary.environments_with_cert}."
  }

  assert {
    condition     = output.framework_summary.environments_rotating == 0
    error_message = "Expected 0 environments with rotation when no rotation input was provided; got ${output.framework_summary.environments_rotating}."
  }

  assert {
    condition     = output.framework_summary.manifests_total == 0
    error_message = "Expected 0 manifests when none were declared; got ${output.framework_summary.manifests_total}."
  }

  assert {
    condition     = output.framework_summary.lifecycle_hooks_total == 0
    error_message = "Expected 0 lifecycle hooks when none were declared; got ${output.framework_summary.lifecycle_hooks_total}."
  }

  assert {
    condition     = output.framework_summary.runner_inventory_total >= 1
    error_message = "Expected framework to consume at least one runner inventory file from terraform/repos/."
  }

  assert {
    condition     = alltrue([for path in keys(output.runner_inventory) : startswith(path, "repos/")])
    error_message = "Expected every runner_inventory output key to live under repos/."
  }

  # Tier defaults injected from the JSON fixture (data-source-injection
  # pattern). The "dev" tier sets retention_days=7 in fixtures/tier_defaults.json.
  assert {
    condition     = contains(keys(output.environments), "demo-minimal") && output.environments["demo-minimal"].resource_key == "demo-minimal"
    error_message = "Expected environments output to be keyed by prefixed resource key demo-minimal."
  }

  assert {
    condition     = random_pet.environment["demo-minimal"].keepers["environment_prefix"] == "demo"
    error_message = "Expected random_pet environment resource address to use prefixed key demo-minimal."
  }

  assert {
    condition     = random_string.environment_secret["demo-minimal"].length >= 16
    error_message = "Expected generated random strings to be at least 16 characters."
  }

  assert {
    condition     = time_static.environment_created["demo-minimal"].triggers["framework_source"] == "NWarila/terraform-framework-template"
    error_message = "Expected time_static metadata to carry framework_source."
  }

  assert {
    condition     = output.environments["demo-minimal"].retention_days == 7
    error_message = "Expected retention_days=7 (dev tier default from data fixture); got ${output.environments["demo-minimal"].retention_days}."
  }

  # Pet name is generated and non-empty.
  assert {
    condition     = length(output.environments["demo-minimal"].pet_name) > 0
    error_message = "Expected non-empty pet_name; got empty string."
  }

  # Created-at timestamp is a non-empty RFC3339 string.
  assert {
    condition     = length(output.environments["demo-minimal"].created_at) > 0
    error_message = "Expected non-empty created_at; got empty string."
  }
}

# endregion --- [ Run 1: single environment, minimum required inputs ] -------------------- #

# region ------ [ Run 1b: secret seed hashes into random_string keepers ] ----------------- #

run "secret_seed_digest_rotates_random_string" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-secret-seed"
    secret_seed        = "unit-test-seed"

    all_environments = [
      {
        name  = "seeded"
        owner = "test-suite"
        tier  = "dev"
      }
    ]
  }

  assert {
    condition     = random_string.environment_secret["demo-seeded"].keepers["secret_seed_digest"] == sha256("unit-test-seed")
    error_message = "Expected secret_seed to be hashed into random_string keepers without storing the raw seed."
  }
}

# endregion --- [ Run 1b: secret seed hashes into random_string keepers ] ----------------- #

# region ------ [ Run 2: multi-environment with manifests + hooks ] ----------------------- #

run "multi_environment_with_iterative_children" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-multi-env-iter"

    all_environments = [
      {
        name  = "alpha"
        owner = "team-a"
        tier  = "dev"
        manifests = [
          { filename = "alpha-manifest-1.yaml", content = "alpha-content-1" },
          { filename = "alpha-manifest-2.yaml", content = "alpha-content-2" },
        ]
        lifecycle_hooks = [
          { name = "alpha-pre-deploy" },
        ]
      },
      {
        name  = "beta"
        owner = "team-b"
        tier  = "staging"
        manifests = [
          { filename = "beta-config.yaml", content = "beta-content" },
        ]
        lifecycle_hooks = [
          { name = "beta-pre-deploy" },
          { name = "beta-post-deploy", triggers = { phase = "post" } },
        ]
      },
    ]
  }

  assert {
    condition     = output.framework_summary.environments_total == 2
    error_message = "Expected 2 environments; got ${output.framework_summary.environments_total}."
  }

  # Iterative-children expansion: manifests across 2 envs = 2 + 1 = 3.
  assert {
    condition     = output.framework_summary.manifests_total == 3
    error_message = "Expected 3 manifests across both environments (2 alpha + 1 beta); got ${output.framework_summary.manifests_total}."
  }

  # Hooks: 1 alpha + 2 beta = 3.
  assert {
    condition     = output.framework_summary.lifecycle_hooks_total == 3
    error_message = "Expected 3 lifecycle hooks; got ${output.framework_summary.lifecycle_hooks_total}."
  }

  # Tier defaults differ per env: dev=7, staging=30.
  assert {
    condition     = output.environments["demo-alpha"].retention_days == 7
    error_message = "Expected alpha (dev) retention_days=7; got ${output.environments["demo-alpha"].retention_days}."
  }

  assert {
    condition     = output.environments["demo-beta"].retention_days == 30
    error_message = "Expected beta (staging) retention_days=30; got ${output.environments["demo-beta"].retention_days}."
  }

  assert {
    condition     = local_file.manifest["demo-alpha__alpha-manifest-1.yaml"].file_permission == "0644"
    error_message = "Expected manifest files to use 0644 permissions by default."
  }

  assert {
    condition     = null_resource.lifecycle_hook["demo-beta__beta-post-deploy"].triggers["framework_source"] == "NWarila/terraform-framework-template"
    error_message = "Expected lifecycle hook metadata to carry framework_source."
  }
}

# endregion --- [ Run 2: multi-environment with manifests + hooks ] ----------------------- #

# region ------ [ Run 3: certificate (single-optional dynamic block) ] -------------------- #

run "environment_with_certificate" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-cert"

    all_environments = [
      {
        name  = "secured"
        owner = "team-sec"
        tier  = "prod"
        certificate = {
          validity_period_hours = 168 # 7 days
          subject = {
            common_name  = "synthetic.example.invalid"
            organization = "Framework Example"
            country      = "US"
          }
        }
      }
    ]
  }

  assert {
    condition     = output.framework_summary.environments_with_cert == 1
    error_message = "Expected 1 environment with certificate; got ${output.framework_summary.environments_with_cert}."
  }

  assert {
    condition     = output.environments["demo-secured"].certificate_enabled == true
    error_message = "Expected secured.certificate_enabled=true; got false."
  }

  # The cert is real: validity dates are populated in state.
  assert {
    condition     = length(tls_self_signed_cert.environment["demo-secured"].cert_pem) > 0
    error_message = "Expected non-empty cert_pem; got empty."
  }

  assert {
    condition     = tls_private_key.environment["demo-secured"].algorithm == "ECDSA"
    error_message = "Expected certificate private keys to use ECDSA."
  }

  assert {
    condition     = tls_self_signed_cert.environment["demo-secured"].is_ca_certificate == false
    error_message = "Expected synthetic certificates not to be CA certificates."
  }
}

# endregion --- [ Run 3: certificate (single-optional dynamic block) ] -------------------- #

# region ------ [ Run 4: rotation (filtered for_each) ] ----------------------------------- #

run "environment_with_rotation" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-rotation"

    all_environments = [
      {
        name  = "rotating"
        owner = "team-ops"
        tier  = "prod"
        rotation = {
          rotation_days = 30
        }
      }
    ]
  }

  assert {
    condition     = output.framework_summary.environments_rotating == 1
    error_message = "Expected 1 environment with rotation; got ${output.framework_summary.environments_rotating}."
  }

  assert {
    condition     = output.environments["demo-rotating"].rotation_enabled == true
    error_message = "Expected rotating.rotation_enabled=true; got false."
  }

  assert {
    condition     = time_rotating.environment_rotation["demo-rotating"].triggers["framework_source"] == "NWarila/terraform-framework-template"
    error_message = "Expected rotation metadata to carry framework_source."
  }
}

# endregion --- [ Run 4: rotation (filtered for_each) ] ----------------------------------- #

# region ------ [ Run 5: validation rules reject bad input ] ------------------------------ #

run "tier_validation_rejects_unknown_tier" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "bad-tier"
        owner = "test"
        tier  = "production" # invalid — must be dev/staging/prod
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "name_validation_rejects_uppercase" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "BadCase" # invalid — must be lowercase
        owner = "test"
        tier  = "dev"
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "duplicate_names_rejected" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      { name = "duplicate", owner = "team-a", tier = "dev" },
      { name = "duplicate", owner = "team-b", tier = "staging" },
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "world_writable_manifest_permissions_rejected" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "bad-permissions"
        owner = "test"
        tier  = "dev"
        manifests = [
          { filename = "bad.yaml", content = "bad", permissions = "0666" },
        ]
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "certificate_validity_over_one_year_rejected" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "bad-cert-validity"
        owner = "test"
        tier  = "dev"
        certificate = {
          validity_period_hours = 8761
        }
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "ca_certificate_rejected" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "bad-ca"
        owner = "test"
        tier  = "dev"
        certificate = {
          is_ca_certificate = true
        }
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

# endregion --- [ Run 5: validation rules reject bad input ] ------------------------------ #
