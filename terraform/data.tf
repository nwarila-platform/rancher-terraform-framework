# Data sources.
#
# Real frameworks use data sources to look up values from the platform
# they manage — e.g., proxmox-terraform-framework reads existing VM
# templates from the Proxmox API to inject template node_name/vm_id
# into clone configurations.
#
# This do-nothing showcase has no live platform to query, so the
# data-source-injection pattern is demonstrated against a local JSON
# fixture instead. The shape of the lookup, the way locals.tf consumes
# the result, and the way main.tf indirectly references the
# injected values is identical to a real framework.

data "local_file" "tier_defaults" {
  filename = "${path.module}/fixtures/tier_defaults.json"
}

data "local_file" "runner_inventory" {
  for_each = toset(local.runner_inventory_paths)

  filename = "${path.module}/${each.value}"
}
