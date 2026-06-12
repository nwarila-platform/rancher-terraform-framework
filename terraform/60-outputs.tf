#% =========================================================================================== %#
#% Outputs: 60-outputs.tf                                          | Category: Outputs (60-69) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% Output values make information about your infrastructure available on the command line, and %#
#%   can expose information for other Terraform configurations to use. Output values are       %#
#%   similar to return values in programming languages.                                        %#
#% =========================================================================================== %#

output "project_id" {
  description = "Rancher project ID for the tenant envelope."
  value       = rancher2_project.tenant.id
}

output "project_name" {
  description = "Rancher project name for the tenant envelope."
  value       = rancher2_project.tenant.name
}

output "namespace_id" {
  description = "Rancher namespace ID managed by this framework."
  value       = rancher2_namespace.tenant.id
}

output "namespace_name" {
  description = "Kubernetes namespace name managed by this framework."
  value       = rancher2_namespace.tenant.name
}

output "helm_release_name" {
  description = "Helm release name deployed into the tenant namespace."
  value       = helm_release.tenant.name
}

output "helm_release_status" {
  description = "Helm release status reported by the Helm provider."
  value       = helm_release.tenant.status
}

output "chart_path" {
  description = "Resolved local chart path supplied to helm_release."
  value       = local.chart_path
}
