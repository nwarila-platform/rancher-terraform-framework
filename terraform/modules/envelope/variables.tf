# ============================================================================================ #
# variables.tf - Input variable declarations for envelope module                               #
# ============================================================================================ #

#region ------ [ Workload Envelope Variables ] ----------------------------------------------- #

variable "workloads" {
  description = "Normalized workload namespace envelopes keyed by workload key."
  type = map(object({
    namespace_name = string
  }))
  nullable = false

  validation {
    condition = (
      length(var.workloads) > 0 &&
      alltrue([for key, workload in var.workloads : (
        length(trimspace(key)) > 0 &&
        length(trimspace(workload.namespace_name)) > 0
      )])
    )
    error_message = "workloads must contain at least one non-empty key and namespace_name."
  }
}

#endregion --- [ Workload Envelope Variables ] ----------------------------------------------- #


#region ------ [ Rancher Envelope Variables ] ------------------------------------------------ #

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
  description = "Rancher project name created for this tenant's workloads."
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

variable "platform_resource_quota" {
  description = "Rancher project and namespace quota/default limit envelope."
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
