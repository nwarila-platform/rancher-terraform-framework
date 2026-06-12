#% =========================================================================================== %#
#% = File: 10-variables.tf                                       | Category: variables (10-19) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#

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
