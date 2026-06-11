#region ------ [ Per-Environment Decorative Resources ] ---------------------------------- #

# random_pet — per environment. Drives the decorative env name used in
# composed outputs and demonstrates the basic flat-attribute pattern.

resource "random_pet" "environment" {
  for_each = local.synthetic_environments

  length    = each.value["pet"]["length"]
  separator = each.value["pet"]["separator"]
  prefix    = each.value["pet"]["prefix"]
  keepers = merge(
    each.value["common_triggers"],
    { pet_length = tostring(each.value["pet"]["length"]) },
  )
}

# random_string — per environment. Synthetic per-env "secret"; output as
# sensitive in outputs.tf.

resource "random_string" "environment_secret" {
  for_each = local.synthetic_environments

  length  = each.value["random_string_length"]
  special = false
  upper   = true
  lower   = true
  numeric = true
  keepers = merge(
    each.value["common_triggers"],
    { secret_seed_digest = local.secret_seed_digest },
  )
}

# time_static — per environment. Records a deterministic timestamp at
# creation and never changes. Used in outputs to assert apply happened.

resource "time_static" "environment_created" {
  for_each = local.synthetic_environments

  triggers = each.value["common_triggers"]
}

#endregion --- [ Per-Environment Decorative Resources ] ---------------------------------- #

#region ------ [ Iterative Children: Manifests + Lifecycle Hooks ] ----------------------- #

# local_file — one per (environment × manifest entry). The flat
# composite-keyed map in locals.tf turns the nested list-of-objects into
# a map suitable for for_each. Demonstrates the iterative-children
# expansion pattern (in proxmox-terraform-framework this is the same
# shape as `dynamic "disk"`, just expressed as a separate resource since
# local_file is its own resource type).

resource "local_file" "manifest" {
  for_each = local.manifests_flat

  filename             = "${path.module}/.synthetic-output/${each.value["environment"]}/${each.value["filename"]}"
  content              = each.value["content"]
  file_permission      = each.value["permissions"]
  directory_permission = "0755"
}

# null_resource — one per (environment × lifecycle hook). Same flat
# composite-keyed pattern. Each hook's `triggers` map records the
# combined env + hook + framework decorations so a downstream observer
# can correlate state to the apply that produced it.

resource "null_resource" "lifecycle_hook" {
  for_each = local.lifecycle_hooks_flat

  triggers = each.value["triggers"]
}

#endregion --- [ Iterative Children: Manifests + Lifecycle Hooks ] ----------------------- #

#region ------ [ Conditional (Filtered for_each) Resources ] ----------------------------- #

# time_rotating — only for environments that opted into rotation. The
# filtered for_each pattern is the standalone-resource equivalent of
# `dynamic "block" { for_each = each.value["foo"][*] }`: 0..1 of these
# per environment, conditioned on the input.

resource "time_rotating" "environment_rotation" {
  for_each = {
    for env_key, env in local.synthetic_environments : env_key => env
    if env.rotation != null
  }

  rotation_days  = each.value["rotation"]["rotation_days"]
  rotation_hours = each.value["rotation"]["rotation_hours"]
  triggers       = each.value["rotation"]["triggers"]
}

# tls_private_key — only for environments that opted into a certificate.
# Generates a P-256 EC key pair — synthetic but real crypto;
# state ends up holding the actual PEM-encoded private key (sensitive).

resource "tls_private_key" "environment" {
  for_each = {
    for env_key, env in local.synthetic_environments : env_key => env
    if env.certificate != null
  }

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# tls_self_signed_cert — paired with tls_private_key. Demonstrates the
# splat-on-optional dynamic block pattern via the `subject` block: when
# the consumer provides a subject in their input, the dynamic block
# emits exactly one block instance; when they omit it, the splat
# resolves to an empty list and the block is not emitted (the certificate
# is created without a subject — the tls provider supplies "" defaults).

resource "tls_self_signed_cert" "environment" {
  for_each = {
    for env_key, env in local.synthetic_environments : env_key => env
    if env.certificate != null
  }

  private_key_pem       = tls_private_key.environment[each.key].private_key_pem
  validity_period_hours = each.value["certificate"]["validity_period_hours"]
  early_renewal_hours   = each.value["certificate"]["early_renewal_hours"]
  is_ca_certificate     = each.value["certificate"]["is_ca_certificate"]
  set_subject_key_id    = each.value["certificate"]["set_subject_key_id"]
  allowed_uses          = each.value["certificate"]["allowed_uses"]
  # subject is emitted by the dynamic block below.

  #region ------ [ Conditional Block Properties ] ------------------------------------------ #

  dynamic "subject" {
    for_each = each.value["certificate"]["subject"][*]
    iterator = subject

    content {
      common_name         = subject.value["common_name"]
      country             = subject.value["country"]
      locality            = subject.value["locality"]
      organization        = subject.value["organization"]
      organizational_unit = subject.value["organizational_unit"]
      postal_code         = subject.value["postal_code"]
      province            = subject.value["province"]
      serial_number       = subject.value["serial_number"]
      street_address      = subject.value["street_address"]
    }
  }

  #endregion --- [ Conditional Block Properties ] ------------------------------------------ #
}

#endregion --- [ Conditional (Filtered for_each) Resources ] ----------------------------- #
