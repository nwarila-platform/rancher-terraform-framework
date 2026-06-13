# ============================================================================================ #
# outputs.tf - Output values for deploy module                                                 #
# ============================================================================================ #

output "helm_release_names" {
  description = "Helm release names deployed into tenant namespaces, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.name }
}

output "helm_release_statuses" {
  description = "Helm release statuses reported by the Helm provider, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.status }
}

output "helm_release_create_namespace" {
  description = "Helm create_namespace settings, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.create_namespace }
}

output "helm_release_skip_crds" {
  description = "Helm skip_crds settings, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.skip_crds }
}

output "helm_release_values" {
  description = "Rendered Helm values payloads supplied to each release, keyed by workload key."
  value       = { for key, release in helm_release.workload : key => release.values }
}

output "chart_paths" {
  description = "Resolved local chart paths supplied to helm_release, keyed by workload key."
  value       = { for key, workload in var.workloads : key => workload.chart_path }
}

output "namespace_names" {
  description = "Kubernetes namespace names targeted by helm_release, keyed by workload key."
  value       = { for key, workload in var.workloads : key => workload.namespace_name }
}
