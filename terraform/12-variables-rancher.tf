#% =========================================================================================== %#
#% = File: 12-variables-rancher.tf                               | Category: variables (10-19) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#

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
