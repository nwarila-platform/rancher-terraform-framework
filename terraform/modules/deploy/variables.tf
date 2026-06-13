# ============================================================================================ #
# variables.tf - Input variable declarations for deploy module                                 #
# ============================================================================================ #

#region ------ [ Workload Deploy Variables ] ------------------------------------------------- #

variable "workloads" {
  description = "Normalized Helm release inputs keyed by workload key."
  type = map(object({
    namespace_name = string
    release_name   = string
    chart_path     = string
    helm_values    = list(string)
  }))
  nullable = false

  validation {
    condition = (
      length(var.workloads) > 0 &&
      alltrue([for key, workload in var.workloads : (
        length(trimspace(key)) > 0 &&
        length(trimspace(workload.namespace_name)) > 0 &&
        length(trimspace(workload.release_name)) > 0 &&
        length(trimspace(workload.chart_path)) > 0 &&
        length(workload.helm_values) > 0
      )])
    )
    error_message = "workloads must contain non-empty keys, namespace_name, release_name, chart_path, and helm_values."
  }
}

#endregion --- [ Workload Deploy Variables ] ------------------------------------------------- #
