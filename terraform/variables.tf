# ============================================================================================ #
# variables.tf — Input variable declarations for Rancher framework                              #
# ============================================================================================ #

#region ------ [ Tenant Workload Variables ] ------------------------------------------------- #

variable "all_workloads" {
  description = "Tenant workload envelopes deployed as per-workload namespaces and Helm releases."
  type = list(object({
    key            = string
    namespace_name = optional(string)
    release_name   = optional(string)
    chart_path     = optional(string)

    ingress = object({
      host = string
      path = optional(string, "/")
    })

    replicas = optional(number, 2)

    hpa = optional(object({
      enabled                           = optional(bool, true)
      min_replicas                      = optional(number, 2)
      max_replicas                      = optional(number, 4)
      target_cpu_utilization_percentage = optional(number, 70)
    }), {})

    resources = optional(
      object({
        requests = object({
          cpu    = string
          memory = string
        })
        limits = object({
          cpu    = string
          memory = string
        })
      }),
      {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    )

    vault_secret_references = optional(map(object({
      path      = string
      engine    = optional(string, "kv-v2")
      version   = optional(number)
      templates = optional(map(string), {})
    })), {})

    persistent_storage = optional(object({
      size          = string
      storage_class = string
      mount_path    = optional(string, "/data")
    }))

    escape_hatches = optional(object({
      api_access_service_account_token = optional(bool, false)
      net_bind_service                 = optional(bool, false)
    }), {})

    values = optional(map(any), {})
  }))
  nullable = false

  validation {
    condition = (
      length(var.all_workloads) > 0 &&
      alltrue([for workload in var.all_workloads : length(trimspace(workload.key)) > 0])
    )
    error_message = "all_workloads must contain at least one workload, and every workload.key must not be empty."
  }

  validation {
    condition = alltrue([
      for workload in var.all_workloads :
      workload.replicas >= 1 &&
      workload.replicas == floor(workload.replicas) &&
      workload.replicas <= var.platform_caps.max_replicas
    ])
    error_message = "all_workloads[*].replicas must be a whole number between 1 and platform_caps.max_replicas."
  }

  validation {
    condition = alltrue([
      for workload in var.all_workloads :
      workload.hpa.min_replicas >= 1 &&
      workload.hpa.min_replicas == floor(workload.hpa.min_replicas) &&
      workload.hpa.max_replicas >= workload.hpa.min_replicas &&
      workload.hpa.max_replicas == floor(workload.hpa.max_replicas) &&
      workload.hpa.max_replicas <= var.platform_caps.max_hpa_replicas &&
      workload.hpa.target_cpu_utilization_percentage >= 1 &&
      workload.hpa.target_cpu_utilization_percentage <= 100
    ])
    error_message = "all_workloads[*].hpa must use whole min/max replicas with min <= max, max <= platform_caps.max_hpa_replicas, and target_cpu_utilization_percentage between 1 and 100."
  }

  validation {
    condition = alltrue([
      for workload in var.all_workloads :
      can(regex(local.cpu_quantity_pattern, workload.resources.requests.cpu)) &&
      can(regex(local.cpu_quantity_pattern, workload.resources.limits.cpu)) &&
      can(regex(local.memory_quantity_pattern, workload.resources.requests.memory)) &&
      can(regex(local.memory_quantity_pattern, workload.resources.limits.memory)) &&
      try(
        endswith(workload.resources.requests.cpu, "m")
        ? tonumber(trimsuffix(workload.resources.requests.cpu, "m"))
        : tonumber(workload.resources.requests.cpu) * 1000,
        -1
      ) > 0 &&
      try(
        endswith(workload.resources.limits.cpu, "m")
        ? tonumber(trimsuffix(workload.resources.limits.cpu, "m"))
        : tonumber(workload.resources.limits.cpu) * 1000,
        -1
      ) > 0 &&
      try(
        tonumber(trimsuffix(trimsuffix(workload.resources.requests.memory, "Mi"), "Gi")) *
        (endswith(workload.resources.requests.memory, "Gi") ? 1024 : 1),
        -1
      ) > 0 &&
      try(
        tonumber(trimsuffix(trimsuffix(workload.resources.limits.memory, "Mi"), "Gi")) *
        (endswith(workload.resources.limits.memory, "Gi") ? 1024 : 1),
        -1
      ) > 0
    ])
    error_message = "all_workloads[*].resources must use positive CPU quantities (whole/decimal cores or m) and memory quantities in Mi or Gi."
  }

  validation {
    condition = alltrue([
      for workload in var.all_workloads :
      can(regex(local.cpu_quantity_pattern, var.platform_caps.max_cpu_request)) &&
      can(regex(local.cpu_quantity_pattern, var.platform_caps.max_cpu_limit)) &&
      can(regex(local.memory_quantity_pattern, var.platform_caps.max_memory_request)) &&
      can(regex(local.memory_quantity_pattern, var.platform_caps.max_memory_limit)) &&
      (
        try(
          endswith(workload.resources.requests.cpu, "m")
          ? tonumber(trimsuffix(workload.resources.requests.cpu, "m"))
          : tonumber(workload.resources.requests.cpu) * 1000,
          -1
        ) <= local.platform_cap_cpu_millicores.max_request
      ) &&
      (
        try(
          endswith(workload.resources.limits.cpu, "m")
          ? tonumber(trimsuffix(workload.resources.limits.cpu, "m"))
          : tonumber(workload.resources.limits.cpu) * 1000,
          -1
        ) <= local.platform_cap_cpu_millicores.max_limit
      ) &&
      (
        try(
          tonumber(trimsuffix(trimsuffix(workload.resources.requests.memory, "Mi"), "Gi")) *
          (endswith(workload.resources.requests.memory, "Gi") ? 1024 : 1),
          -1
        ) <= local.platform_cap_memory_mib.max_request
      ) &&
      (
        try(
          tonumber(trimsuffix(trimsuffix(workload.resources.limits.memory, "Mi"), "Gi")) *
          (endswith(workload.resources.limits.memory, "Gi") ? 1024 : 1),
          -1
        ) <= local.platform_cap_memory_mib.max_limit
      )
    ])
    error_message = "all_workloads[*].resources requests and limits must be less than or equal to the matching platform_caps max resource caps."
  }

  validation {
    condition = alltrue([
      for workload in var.all_workloads :
      try(
        (
          endswith(workload.resources.requests.cpu, "m")
          ? tonumber(trimsuffix(workload.resources.requests.cpu, "m"))
          : tonumber(workload.resources.requests.cpu) * 1000
          ) - (
          endswith(workload.resources.limits.cpu, "m")
          ? tonumber(trimsuffix(workload.resources.limits.cpu, "m"))
          : tonumber(workload.resources.limits.cpu) * 1000
        ),
        1
      ) <= 0 &&
      try(
        (
          tonumber(trimsuffix(trimsuffix(workload.resources.requests.memory, "Mi"), "Gi")) *
          (endswith(workload.resources.requests.memory, "Gi") ? 1024 : 1)
          ) - (
          tonumber(trimsuffix(trimsuffix(workload.resources.limits.memory, "Mi"), "Gi")) *
          (endswith(workload.resources.limits.memory, "Gi") ? 1024 : 1)
        ),
        1
      ) <= 0
    ])
    error_message = "all_workloads[*].resources requests must be less than or equal to their matching limits after CPU and memory unit normalization."
  }
}

variable "platform_caps" {
  description = "Platform caps that later validation and OPA will enforce against tenant inputs."
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

variable "tenant_reconciler_role_template_id" {
  description = "Existing Rancher role template ID for the tenant chart reconcile identity."
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
