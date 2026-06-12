package terraform_plan_test

import data.terraform_plan
import rego.v1

safe_helm := {
	"address": "module.framework.helm_release.tenant",
	"type": "helm_release",
	"name": "tenant",
	"values": {
		"create_namespace": false,
		"disable_crd_hooks": true,
		"namespace": "tenant-app",
		"skip_crds": true,
		"values": [`platform:
  replicas: 2
  hpa:
    min_replicas: 2
    max_replicas: 4
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  persistent_storage: null
  platform_caps:
    max_replicas: 10
    max_hpa_replicas: 10
    min_cpu_request: 50m
    max_cpu_request: 500m
    min_cpu_limit: 50m
    max_cpu_limit: 1000m
    min_memory_request: 64Mi
    max_memory_request: 512Mi
    min_memory_limit: 64Mi
    max_memory_limit: 1Gi
    max_persistent_storage_size: 10Gi
    allowed_storage_classes:
    - standard
`],
	},
}

safe_namespace := {
	"address": "module.framework.rancher2_namespace.tenant",
	"type": "rancher2_namespace",
	"name": "tenant",
	"values": {
		"name": "tenant-app",
		"labels": {
			"pod-security.kubernetes.io/enforce": "restricted",
			"pod-security.kubernetes.io/audit": "restricted",
			"pod-security.kubernetes.io/warn": "restricted",
		},
		"resource_quota": [{
			"limit": [{
				"services_load_balancers": "0",
				"services_node_ports": "0",
			}],
		}],
	},
}

safe_project := {
	"address": "module.framework.rancher2_project.tenant",
	"type": "rancher2_project",
	"name": "tenant",
	"values": {
		"resource_quota": [{
			"project_limit": [{
				"services_load_balancers": "0",
				"services_node_ports": "0",
			}],
			"namespace_default_limit": [{
				"services_load_balancers": "0",
				"services_node_ports": "0",
			}],
		}],
	},
}

safe_binding := {
	"address": "module.framework.rancher2_project_role_template_binding.tenant_reconciler",
	"type": "rancher2_project_role_template_binding",
	"name": "tenant_reconciler",
	"values": {
		"group_principal_id": "local://tenant-reconcilers",
		"role_template_id": "nwarila-tenant-reconciler",
	},
}

safe_input := {"resources": [safe_helm, safe_namespace, safe_project, safe_binding]}

with_resource(address, replacement) := {"resources": resources} if {
	kept := [resource | resource := safe_input.resources[_]; resource.address != address]
	resources := array.concat(kept, [replacement])
}

test_safe_plan_allowed if {
	count(terraform_plan.deny) == 0 with input as safe_input
}

test_missing_namespace_denied if {
	denials := terraform_plan.deny with input as {
		"resources": [safe_helm, safe_project, safe_binding],
	}
	some msg in denials
	contains(msg, "rancher2_namespace.tenant must be planned")
}

test_namespace_without_psa_enforce_denied if {
	bad_values := object.union(
		safe_namespace.values,
		{"labels": {"pod-security.kubernetes.io/enforce": "baseline"}},
	)
	bad_namespace := object.union(safe_namespace, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(
		safe_namespace.address,
		bad_namespace,
	)
	some msg in denials
	contains(msg, "must enforce PSA restricted")
}

test_project_load_balancer_quota_denied if {
	bad_project := object.union(
		safe_project,
		{"values": {"resource_quota": [{
			"project_limit": [{
				"services_load_balancers": "1",
				"services_node_ports": "0",
			}],
			"namespace_default_limit": [{
				"services_load_balancers": "0",
				"services_node_ports": "0",
			}],
		}]}},
	)
	denials := terraform_plan.deny with input as with_resource(safe_project.address, bad_project)
	some msg in denials
	contains(msg, "project_limit must keep LoadBalancer and NodePort quotas at 0")
}

test_namespace_node_port_quota_denied if {
	bad_values := object.union(
		safe_namespace.values,
		{"resource_quota": [{
			"limit": [{
				"services_load_balancers": "0",
				"services_node_ports": "1",
			}],
		}]},
	)
	bad_namespace := object.union(safe_namespace, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(
		safe_namespace.address,
		bad_namespace,
	)
	some msg in denials
	contains(msg, "limit must keep LoadBalancer and NodePort quotas at 0")
}

test_helm_create_namespace_denied if {
	bad_values := object.union(safe_helm.values, {"create_namespace": true})
	bad_helm := object.union(safe_helm, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(safe_helm.address, bad_helm)
	some msg in denials
	contains(msg, "must not create namespaces")
}

test_helm_crds_denied if {
	bad_values := object.union(safe_helm.values, {"skip_crds": false})
	bad_helm := object.union(safe_helm, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(safe_helm.address, bad_helm)
	some msg in denials
	contains(msg, "must skip CRDs")
}

test_replicas_above_cap_denied if {
	bad_values := object.union(safe_helm.values, {"values": [`platform:
  replicas: 11
  hpa:
    min_replicas: 2
    max_replicas: 4
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  persistent_storage: null
  platform_caps:
    max_replicas: 10
    max_hpa_replicas: 10
    min_cpu_request: 50m
    max_cpu_request: 500m
    min_cpu_limit: 50m
    max_cpu_limit: 1000m
    min_memory_request: 64Mi
    max_memory_request: 512Mi
    min_memory_limit: 64Mi
    max_memory_limit: 1Gi
    max_persistent_storage_size: 10Gi
    allowed_storage_classes:
    - standard
`]})
	bad_helm := object.union(safe_helm, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(safe_helm.address, bad_helm)
	some msg in denials
	contains(msg, "values replicas must stay within platform caps")
}

test_resources_above_cap_denied if {
	bad_values := object.union(safe_helm.values, {"values": [`platform:
  replicas: 2
  hpa:
    min_replicas: 2
    max_replicas: 4
  resources:
    requests:
      cpu: 600m
      memory: 128Mi
    limits:
      cpu: 700m
      memory: 512Mi
  persistent_storage: null
  platform_caps:
    max_replicas: 10
    max_hpa_replicas: 10
    min_cpu_request: 50m
    max_cpu_request: 500m
    min_cpu_limit: 50m
    max_cpu_limit: 1000m
    min_memory_request: 64Mi
    max_memory_request: 512Mi
    min_memory_limit: 64Mi
    max_memory_limit: 1Gi
    max_persistent_storage_size: 10Gi
    allowed_storage_classes:
    - standard
`]})
	bad_helm := object.union(safe_helm, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(safe_helm.address, bad_helm)
	some msg in denials
	contains(msg, "values resources must stay within platform caps")
}

test_persistent_storage_class_denied if {
	bad_values := object.union(safe_helm.values, {"values": [`platform:
  replicas: 2
  hpa:
    min_replicas: 2
    max_replicas: 4
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  persistent_storage:
    size: 1Gi
    storage_class: fast
  platform_caps:
    max_replicas: 10
    max_hpa_replicas: 10
    min_cpu_request: 50m
    max_cpu_request: 500m
    min_cpu_limit: 50m
    max_cpu_limit: 1000m
    min_memory_request: 64Mi
    max_memory_request: 512Mi
    min_memory_limit: 64Mi
    max_memory_limit: 1Gi
    max_persistent_storage_size: 10Gi
    allowed_storage_classes:
    - standard
`]})
	bad_helm := object.union(safe_helm, {"values": bad_values})
	denials := terraform_plan.deny with input as with_resource(safe_helm.address, bad_helm)
	some msg in denials
	contains(msg, "values persistent_storage must stay within platform caps")
}
