# ============================================================================================ #
# variables.tf — Input variable declarations for Rancher framework                              #
# ============================================================================================ #

#region ------ [ Tenant Workload Variables ] ------------------------------------------------- #

variable "namespace_name" {
  description = "Tenant namespace name created inside the Rancher project."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.namespace_name)) > 0
    error_message = "namespace_name must not be empty."
  }
}

variable "release_name" {
  description = "Helm release name for the tenant-owned local chart."
  type        = string
  default     = "tenant-workload"
  nullable    = false

  validation {
    condition     = length(trimspace(var.release_name)) > 0
    error_message = "release_name must not be empty."
  }
}

variable "chart_path" {
  description = "Path to the tenant-owned local Helm chart. Null resolves to path.root/chart."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.chart_path == null || length(trimspace(var.chart_path)) > 0
    error_message = "chart_path must be null or a non-empty path."
  }
}

variable "values" {
  description = "Additional non-secret Helm values for the tenant chart. Raw secret values are forbidden."
  type        = map(any)
  default     = {}
  nullable    = false
}

variable "ingress" {
  description = "Tenant ingress request surfaced to the chart values contract."
  type = object({
    host = string
    path = optional(string, "/")
  })
  nullable = false

  validation {
    condition     = length(trimspace(var.ingress.host)) > 0 && length(trimspace(var.ingress.path)) > 0
    error_message = "ingress.host and ingress.path must not be empty."
  }
}

variable "replicas" {
  description = "Requested steady-state workload replica count. Step 3 enforces platform caps."
  type        = number
  default     = 2
  nullable    = false
}

variable "hpa" {
  description = "Horizontal Pod Autoscaler request surfaced to the chart values contract."
  type = object({
    enabled                           = optional(bool, true)
    min_replicas                      = optional(number, 2)
    max_replicas                      = optional(number, 4)
    target_cpu_utilization_percentage = optional(number, 70)
  })
  default  = {}
  nullable = false
}

variable "resources" {
  description = "Container resource requests and limits surfaced to the chart values contract."
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
  nullable = false
}

variable "vault_secret_references" {
  description = "Vault references for in-cluster secret materialization. Values must be references, never secrets."
  type = map(object({
    path      = string
    engine    = optional(string, "kv-v2")
    version   = optional(number)
    templates = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}

variable "persistent_storage" {
  description = "Optional persistent-storage escape hatch request. Step 3 enforces size and class allowlists."
  type = object({
    size          = string
    storage_class = string
    mount_path    = optional(string, "/data")
  })
  default  = null
  nullable = true
}

variable "escape_hatches" {
  description = "Two non-storage audited escape hatches; persistent_storage is the third escape hatch."
  type = object({
    api_access_service_account_token = optional(bool, false)
    net_bind_service                 = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "platform_caps" {
  description = "Platform caps that Step 3 validation and OPA will enforce against tenant inputs."
  type = object({
    max_replicas                = optional(number, 10)
    max_hpa_replicas            = optional(number, 10)
    max_cpu_request             = optional(string, "500m")
    max_cpu_limit               = optional(string, "1000m")
    max_memory_request          = optional(string, "512Mi")
    max_memory_limit            = optional(string, "1Gi")
    max_persistent_storage_size = optional(string, "10Gi")
    allowed_storage_classes     = optional(list(string), ["standard"])
  })
  default  = {}
  nullable = false
}

#endregion --- [ Tenant Workload Variables ] ------------------------------------------------- #


#region ------ [ Rancher Envelope Variables ] ------------------------------------------------ #

# Define Provider Configuration Options.
variable "rancher_config" {
  description = "Rancher API configuration. Provide values via tfvars or TF_VAR_rancher_config; never commit real tokens."
  type = object({
    api_url   = string
    token_key = string
    insecure  = optional(bool, false)
    ca_certs  = optional(string)
  })
  nullable  = false
  sensitive = true

  validation {
    condition = (
      length(trimspace(var.rancher_config.api_url)) > 0 &&
      length(trimspace(var.rancher_config.token_key)) > 0
    )
    error_message = "rancher_config.api_url and rancher_config.token_key must not be empty."
  }
}

variable "helm_kubernetes" {
  description = "Sensitive Kubernetes auth configuration for the Helm provider targeting the downstream cluster."
  type = object({
    config_path            = optional(string)
    config_paths           = optional(list(string))
    config_context         = optional(string)
    host                   = optional(string)
    username               = optional(string)
    password               = optional(string)
    token                  = optional(string)
    insecure               = optional(bool)
    tls_server_name        = optional(string)
    client_certificate     = optional(string)
    client_key             = optional(string)
    cluster_ca_certificate = optional(string)
    proxy_url              = optional(string)
  })
  default   = {}
  nullable  = false
  sensitive = true
}

variable "cluster_id" {
  description = "Rancher downstream cluster ID that owns the tenant project."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cluster_id)) > 0
    error_message = "cluster_id must not be empty."
  }
}

variable "project_name" {
  description = "Rancher project name created for this tenant workload."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name must not be empty."
  }
}

variable "project_description" {
  description = "Description applied to the Rancher tenant project."
  type        = string
  default     = "NWarila tenant project managed by Terraform."
  nullable    = false
}

variable "tenant_reconciler_role_template_id" {
  description = "Existing Rancher role template ID for the tenant chart reconcile identity. Step 3 makes this custom and kind-allowlisted."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.tenant_reconciler_role_template_id)) > 0
    error_message = "tenant_reconciler_role_template_id must not be empty."
  }
}

variable "tenant_reconciler_principal" {
  description = "User or group principal bound to the tenant reconcile role template."
  type = object({
    group_id           = optional(string)
    group_principal_id = optional(string)
    user_id            = optional(string)
    user_principal_id  = optional(string)
  })
  nullable = false
}

variable "platform_resource_quota" {
  description = "Rancher project and namespace quota/default limit envelope. Step 3 validates these against caps."
  type = object({
    project_limit = optional(object({
      config_maps              = optional(string)
      limits_cpu               = optional(string, "2000m")
      limits_memory            = optional(string, "2Gi")
      persistent_volume_claims = optional(string, "1")
      pods                     = optional(string, "20")
      replication_controllers  = optional(string)
      requests_cpu             = optional(string, "1000m")
      requests_memory          = optional(string, "1Gi")
      requests_storage         = optional(string, "10Gi")
      secrets                  = optional(string, "10")
      services_load_balancers  = optional(string, "0")
      services_node_ports      = optional(string, "0")
    }), {})
    namespace_default_limit = optional(object({
      config_maps              = optional(string)
      limits_cpu               = optional(string, "1000m")
      limits_memory            = optional(string, "1Gi")
      persistent_volume_claims = optional(string, "1")
      pods                     = optional(string, "10")
      replication_controllers  = optional(string)
      requests_cpu             = optional(string, "500m")
      requests_memory          = optional(string, "512Mi")
      requests_storage         = optional(string, "5Gi")
      secrets                  = optional(string, "5")
      services_load_balancers  = optional(string, "0")
      services_node_ports      = optional(string, "0")
    }), {})
    namespace_limit = optional(object({
      config_maps              = optional(string)
      limits_cpu               = optional(string, "1000m")
      limits_memory            = optional(string, "1Gi")
      persistent_volume_claims = optional(string, "1")
      pods                     = optional(string, "10")
      replication_controllers  = optional(string)
      requests_cpu             = optional(string, "500m")
      requests_memory          = optional(string, "512Mi")
      requests_storage         = optional(string, "5Gi")
      secrets                  = optional(string, "5")
      services_load_balancers  = optional(string, "0")
      services_node_ports      = optional(string, "0")
    }), {})
    container_resource_limit = optional(object({
      limits_cpu      = optional(string, "500m")
      limits_memory   = optional(string, "512Mi")
      requests_cpu    = optional(string, "100m")
      requests_memory = optional(string, "128Mi")
    }), {})
  })
  default  = {}
  nullable = false
}

#endregion --- [ Rancher Envelope Variables ] ------------------------------------------------ #
