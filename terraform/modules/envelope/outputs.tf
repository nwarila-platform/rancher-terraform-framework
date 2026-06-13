# ============================================================================================ #
# outputs.tf - Output values for envelope module                                               #
# ============================================================================================ #

output "project_id" {
  description = "Rancher project ID for the tenant envelope."
  value       = rancher2_project.tenant.id
}

output "project_cluster_id" {
  description = "Rancher downstream cluster ID configured on the tenant project."
  value       = rancher2_project.tenant.cluster_id
}

output "project_name" {
  description = "Rancher project name for the tenant envelope."
  value       = rancher2_project.tenant.name
}

output "project_limit_cpu" {
  description = "Project-level CPU limit quota applied to the tenant envelope."
  value       = rancher2_project.tenant.resource_quota[0].project_limit[0].limits_cpu
}

output "namespace_ids" {
  description = "Rancher namespace IDs managed by this envelope, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.id }
}

output "namespace_names" {
  description = "Kubernetes namespace names managed by this envelope, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.name }
}

output "namespace_project_ids" {
  description = "Rancher project IDs assigned to each workload namespace, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.project_id }
}

output "namespace_labels" {
  description = "Labels applied to each workload namespace, keyed by workload key."
  value       = { for key, namespace in rancher2_namespace.workload : key => namespace.labels }
}

output "namespace_psa_labels" {
  description = "PSA Restricted labels applied to every workload namespace."
  value       = local.namespace_psa_labels
}

output "reconcile_service_account_names" {
  description = "Restricted reconcile ServiceAccount names created in each workload namespace, keyed by workload key."
  value       = { for key, account in kubernetes_service_account_v1.tenant_reconciler : key => account.metadata[0].name }
}

output "reconcile_service_account_namespaces" {
  description = "Restricted reconcile ServiceAccount namespaces, keyed by workload key."
  value       = { for key, account in kubernetes_service_account_v1.tenant_reconciler : key => account.metadata[0].namespace }
}

output "reconcile_service_account_automount" {
  description = "Restricted reconcile ServiceAccount automount flags, keyed by workload key."
  value       = { for key, account in kubernetes_service_account_v1.tenant_reconciler : key => account.automount_service_account_token }
}

output "reconcile_role_names" {
  description = "Restricted reconcile Role names, keyed by workload key."
  value       = { for key, role in kubernetes_role_v1.tenant_reconciler : key => role.metadata[0].name }
}

output "reconcile_role_rules" {
  description = "Namespace-local reconcile Role rules mirrored from the approved Kyverno kind allowlist."
  value       = local.tenant_reconcile_role_rules
}

output "reconcile_role_binding_subjects" {
  description = "Restricted reconcile RoleBinding subjects, keyed by workload key."
  value       = { for key, binding in kubernetes_role_binding_v1.tenant_reconciler : key => binding.subject[0] }
}

output "reconcile_role_binding_role_refs" {
  description = "Restricted reconcile RoleBinding role references, keyed by workload key."
  value       = { for key, binding in kubernetes_role_binding_v1.tenant_reconciler : key => binding.role_ref[0] }
}
