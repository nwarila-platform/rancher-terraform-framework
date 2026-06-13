# ============================================================================================ #
# outputs.tf - Output values for Rancher framework                                             #
# ============================================================================================ #

output "project_id" {
  description = "Rancher project ID for the tenant envelope."
  value       = module.envelope.project_id
}

output "project_name" {
  description = "Rancher project name for the tenant envelope."
  value       = module.envelope.project_name
}

output "namespace_ids" {
  description = "Rancher namespace IDs managed by this framework, keyed by workload key."
  value       = module.envelope.namespace_ids
}

output "namespace_names" {
  description = "Kubernetes namespace names managed by this framework, keyed by workload key."
  value       = module.envelope.namespace_names
}

output "reconcile_service_account_names" {
  description = "Restricted reconcile ServiceAccount names created in each workload namespace, keyed by workload key."
  value       = module.envelope.reconcile_service_account_names
}

output "helm_release_names" {
  description = "Helm release names deployed into tenant namespaces, keyed by workload key."
  value       = module.deploy.helm_release_names
}

output "helm_release_statuses" {
  description = "Helm release statuses reported by the Helm provider, keyed by workload key."
  value       = module.deploy.helm_release_statuses
}

output "chart_paths" {
  description = "Resolved local chart paths supplied to helm_release, keyed by workload key."
  value       = module.deploy.chart_paths
}
