#region ------ [ Per-Environment Composed Outputs ] -------------------------------------- #

# environments — the framework's primary output. One entry per
# environment; each entry composes references from every per-env
# resource. Tests assert against this output to verify the apply
# produced what the inputs asked for.
output "environments" {
  description = "Map keyed by prefixed environment resource key (`<environment_prefix>-<name>`). Each entry composes references from every per-env synthetic resource: the generated pet name, the creation timestamp, and pointers to the resources produced for that environment."
  value = {
    for env_key, env in local.synthetic_environments : env_key => {
      resource_key         = env.resource_key
      name                 = env.name
      owner                = env.owner
      tier                 = env.tier
      enabled              = env.enabled
      retention_days       = env.retention_days
      pet_name             = random_pet.environment[env_key].id
      created_at           = time_static.environment_created[env_key].rfc3339
      manifest_count       = length(coalesce(env.manifests, []))
      lifecycle_hook_count = length(coalesce(env.lifecycle_hooks, []))
      rotation_enabled     = env.rotation != null
      certificate_enabled  = env.certificate != null
      tags                 = env.tags
    }
  }
}

#endregion --- [ Per-Environment Composed Outputs ] -------------------------------------- #

#region ------ [ Aggregate / Roll-up Outputs ] ------------------------------------------- #

output "manifest_paths" {
  description = "Absolute path of every local_file produced by this framework, keyed by composite_key (`<environment_prefix>-<name>__filename`). Useful for downstream consumers (e.g. a runner overlay validator) to enumerate generated artifacts."
  value = {
    for k, f in local_file.manifest : k => f.filename
  }
}

output "framework_summary" {
  description = "Aggregate counts of every resource type produced by this framework. Stable across applies for a given input — useful for tests asserting on resource creation."
  value = {
    environments_total     = length(local.synthetic_environments)
    environments_with_cert = length(tls_self_signed_cert.environment)
    environments_rotating  = length(time_rotating.environment_rotation)
    manifests_total        = length(local.manifests_flat)
    lifecycle_hooks_total  = length(local.lifecycle_hooks_flat)
    runner_inventory_total = length(local.runner_inventory)
    framework_decorations  = local.framework_decorations
  }
}

output "runner_inventory" {
  description = "Runner-owned files discovered under terraform/repos/, keyed by repository-relative path. This proves overlays are consumed by the framework rather than merely copied beside it."
  value       = local.runner_inventory
}

#endregion --- [ Aggregate / Roll-up Outputs ] ------------------------------------------- #

#region ------ [ Sensitive Outputs (per-env credentials material) ] ---------------------- #

# environment_secrets — the per-env synthetic secret. Marked sensitive
# so terraform never prints it in plan/apply output and any consumer
# referencing it propagates the sensitivity automatically. This pattern
# is what real frameworks use for credentials, API tokens, etc. The
# value is a real random string in state but the CLI redacts it.
output "environment_secrets" {
  description = "Per-environment synthetic secrets. Sensitive — Terraform redacts these in CLI output and any reference to them in downstream config inherits the sensitivity flag automatically."
  sensitive   = true
  value = {
    for env_key in keys(local.synthetic_environments) : env_key => random_string.environment_secret[env_key].result
  }
}

# environment_certificates — only for environments that opted into a
# certificate. Sensitive because it contains the private key in PEM form.
# Demonstrates the conditional sensitive output pattern.
output "environment_certificates" {
  description = "Per-environment generated key + cert pairs (PEM-encoded). Sensitive due to private_key_pem. Only populated for environments where certificate != null in input."
  sensitive   = true
  value = {
    for env_key in keys(tls_self_signed_cert.environment) : env_key => {
      private_key_pem = tls_private_key.environment[env_key].private_key_pem
      cert_pem        = tls_self_signed_cert.environment[env_key].cert_pem
      not_before      = tls_self_signed_cert.environment[env_key].validity_start_time
      not_after       = tls_self_signed_cert.environment[env_key].validity_end_time
    }
  }
}

#endregion --- [ Sensitive Outputs (per-env credentials material) ] ---------------------- #
