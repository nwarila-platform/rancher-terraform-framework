# ============================================================================================ #
# resources.tf - Root composition for Rancher framework modules                                #
# ============================================================================================ #


#region ------ [ Compose Platform Envelope Module ] ----------------------------------------- #

module "envelope" {
  source = "./modules/envelope"

  cluster_id              = var.cluster_id
  project_name            = var.project_name
  project_description     = var.project_description
  platform_resource_quota = var.platform_resource_quota

  workloads = {
    for key, workload in local.workloads : key => {
      namespace_name = workload.namespace_name
    }
  }
}

#endregion --- [ Compose Platform Envelope Module ] ----------------------------------------- #


#region ------ [ Compose Tenant Deploy Module ] --------------------------------------------- #

module "deploy" {
  source = "./modules/deploy"

  workloads = {
    for key, workload in local.workloads : key => {
      namespace_name = module.envelope.namespace_names[key]
      release_name   = workload.release_name
      chart_path     = workload.chart_path
      helm_values    = workload.helm_values
    }
  }
}

#endregion --- [ Compose Tenant Deploy Module ] --------------------------------------------- #
