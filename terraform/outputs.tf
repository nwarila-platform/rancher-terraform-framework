# ============================================================================================ #
# outputs.tf — Output values for Rancher framework                                              #
# ============================================================================================ #

output "project_id" {
  description = "Rancher project ID for the tenant envelope."
  value       = rancher2_project.tenant.id
}

output "project_name" {
  description = "Rancher project name for the tenant envelope."
  value       = rancher2_project.tenant.name
}

output "namespace_ids" {
  description = "Rancher namespace IDs managed by this framework, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.id }
}

output "namespace_names" {
  description = "Kubernetes namespace names managed by this framework, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.name }
}

output "helm_release_names" {
  description = "Helm release names deployed into tenant namespaces, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.name }
}

output "helm_release_statuses" {
  description = "Helm release statuses reported by the Helm provider, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.status }
}

output "chart_paths" {
  description = "Resolved local chart paths supplied to helm_release, keyed by workload key."
  value       = { for key, workload in local.workloads : key => workload.chart_path }
}
