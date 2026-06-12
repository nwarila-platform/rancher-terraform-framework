# terraform_plan - Rancher envelope/input plan-aware policy.
#
# This package consumes normalized `terraform show -json tfplan` output from
# tools/build_plan_input.py. It is intentionally scoped to the visible
# Rancher envelope and tenant input surface; workload policy is enforced by
# tenant chart rendering plus in-cluster PSA/Kyverno admission.

package terraform_plan

import rego.v1

resource(type, name) := found if {
	found := input.resources[_]
	found.type == type
	found.name == name
}

has_resource(type, name) if {
	_ := resource(type, name)
}

first_block(item, key) := block if {
	blocks := object.get(item, key, [])
	count(blocks) > 0
	block := blocks[0]
}

project_quota(name) := quota if {
	project := resource("rancher2_project", "tenant")
	resource_quota := first_block(project.values, "resource_quota")
	quota := first_block(resource_quota, name)
}

namespace_quota := quota if {
	namespace := resource("rancher2_namespace", "tenant")
	resource_quota := first_block(namespace.values, "resource_quota")
	quota := first_block(resource_quota, "limit")
}

quota_locks_load_balancers_and_node_ports(quota) if {
	object.get(quota, "services_load_balancers", "") == "0"
	object.get(quota, "services_node_ports", "") == "0"
}

helm_platform_values := platform if {
	helm := resource("helm_release", "tenant")
	values := object.get(helm.values, "values", [])
	count(values) > 0
	rendered := yaml.unmarshal(values[0])
	platform := object.get(rendered, "platform", {})
}

cpu_millicores(value) := millicores if {
	is_string(value)
	regex.match("^[1-9][0-9]*m$", value)
	millicores := to_number(trim_suffix(value, "m"))
}

memory_mib(value) := mib if {
	is_string(value)
	regex.match("^[1-9][0-9]*Mi$", value)
	mib := to_number(trim_suffix(value, "Mi"))
}

memory_mib(value) := mib if {
	is_string(value)
	regex.match("^[1-9][0-9]*Gi$", value)
	mib := to_number(trim_suffix(value, "Gi")) * 1024
}

value_within(value, min, max) if {
	value >= min
	value <= max
}

resources_within_caps(resources, caps) if {
	request_cpu := cpu_millicores(resources.requests.cpu)
	limit_cpu := cpu_millicores(resources.limits.cpu)
	min_request_cpu := cpu_millicores(caps.min_cpu_request)
	max_request_cpu := cpu_millicores(caps.max_cpu_request)
	min_limit_cpu := cpu_millicores(caps.min_cpu_limit)
	max_limit_cpu := cpu_millicores(caps.max_cpu_limit)

	request_memory := memory_mib(resources.requests.memory)
	limit_memory := memory_mib(resources.limits.memory)
	min_request_memory := memory_mib(caps.min_memory_request)
	max_request_memory := memory_mib(caps.max_memory_request)
	min_limit_memory := memory_mib(caps.min_memory_limit)
	max_limit_memory := memory_mib(caps.max_memory_limit)

	value_within(request_cpu, min_request_cpu, max_request_cpu)
	value_within(limit_cpu, min_limit_cpu, max_limit_cpu)
	request_cpu <= limit_cpu
	value_within(request_memory, min_request_memory, max_request_memory)
	value_within(limit_memory, min_limit_memory, max_limit_memory)
	request_memory <= limit_memory
}

persistent_storage_within_caps(storage, caps) if {
	storage == null
}

persistent_storage_within_caps(storage, caps) if {
	storage_size := memory_mib(storage.size)
	max_size := memory_mib(caps.max_persistent_storage_size)
	storage_size <= max_size
	storage_size > 0
	caps.allowed_storage_classes[_] == storage.storage_class
}

deny contains msg if {
	required := {
		"helm_release.tenant": ["helm_release", "tenant"],
		"rancher2_namespace.tenant": ["rancher2_namespace", "tenant"],
		"rancher2_project.tenant": ["rancher2_project", "tenant"],
		"rancher2_project_role_template_binding.tenant_reconciler": [
			"rancher2_project_role_template_binding",
			"tenant_reconciler",
		],
	}
	some address, parts in required
	not has_resource(parts[0], parts[1])
	msg := sprintf("%s must be planned", [address])
}

deny contains msg if {
	namespace := resource("rancher2_namespace", "tenant")
	labels := object.get(namespace.values, "labels", {})
	object.get(labels, "pod-security.kubernetes.io/enforce", "") != "restricted"
	msg := sprintf("%s must enforce PSA restricted", [namespace.address])
}

deny contains msg if {
	namespace := resource("rancher2_namespace", "tenant")
	labels := object.get(namespace.values, "labels", {})
	object.get(labels, "pod-security.kubernetes.io/audit", "") != "restricted"
	msg := sprintf("%s must audit PSA restricted", [namespace.address])
}

deny contains msg if {
	namespace := resource("rancher2_namespace", "tenant")
	labels := object.get(namespace.values, "labels", {})
	object.get(labels, "pod-security.kubernetes.io/warn", "") != "restricted"
	msg := sprintf("%s must warn PSA restricted", [namespace.address])
}

deny contains msg if {
	quota := project_quota("project_limit")
	not quota_locks_load_balancers_and_node_ports(quota)
	msg := "rancher2_project.tenant project_limit must keep LoadBalancer and NodePort quotas at 0"
}

deny contains msg if {
	quota := project_quota("namespace_default_limit")
	not quota_locks_load_balancers_and_node_ports(quota)
	msg := "rancher2_project.tenant namespace_default_limit must keep LoadBalancer and NodePort quotas at 0"
}

deny contains msg if {
	quota := namespace_quota
	not quota_locks_load_balancers_and_node_ports(quota)
	msg := "rancher2_namespace.tenant limit must keep LoadBalancer and NodePort quotas at 0"
}

deny contains msg if {
	helm := resource("helm_release", "tenant")
	object.get(helm.values, "create_namespace", true) != false
	msg := sprintf("%s must not create namespaces", [helm.address])
}

deny contains msg if {
	helm := resource("helm_release", "tenant")
	object.get(helm.values, "skip_crds", false) != true
	msg := sprintf("%s must skip CRDs", [helm.address])
}

deny contains msg if {
	helm := resource("helm_release", "tenant")
	object.get(helm.values, "disable_crd_hooks", false) != true
	msg := sprintf("%s must disable CRD hooks", [helm.address])
}

deny contains msg if {
	helm := resource("helm_release", "tenant")
	namespace := resource("rancher2_namespace", "tenant")
	object.get(helm.values, "namespace", "") != object.get(namespace.values, "name", "")
	msg := sprintf("%s must target the Rancher-created namespace", [helm.address])
}

deny contains msg if {
	platform := helm_platform_values
	platform.replicas > platform.platform_caps.max_replicas
	msg := "helm_release.tenant values replicas must stay within platform caps"
}

deny contains msg if {
	platform := helm_platform_values
	platform.hpa.max_replicas > platform.platform_caps.max_hpa_replicas
	msg := "helm_release.tenant values HPA max_replicas must stay within platform caps"
}

deny contains msg if {
	platform := helm_platform_values
	platform.hpa.min_replicas > platform.hpa.max_replicas
	msg := "helm_release.tenant values HPA min_replicas must be <= max_replicas"
}

deny contains msg if {
	platform := helm_platform_values
	not resources_within_caps(platform.resources, platform.platform_caps)
	msg := "helm_release.tenant values resources must stay within platform caps"
}

deny contains msg if {
	platform := helm_platform_values
	not persistent_storage_within_caps(platform.persistent_storage, platform.platform_caps)
	msg := "helm_release.tenant values persistent_storage must stay within platform caps"
}
