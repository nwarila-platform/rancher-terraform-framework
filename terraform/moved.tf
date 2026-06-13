# ============================================================================================ #
# moved.tf - State-address moves for the envelope/deploy split                                 #
# ============================================================================================ #

moved {
  from = rancher2_project.tenant
  to   = module.envelope.rancher2_project.tenant
}

moved {
  from = rancher2_namespace.workload
  to   = module.envelope.rancher2_namespace.workload
}

moved {
  from = kubernetes_service_account_v1.tenant_reconciler
  to   = module.envelope.kubernetes_service_account_v1.tenant_reconciler
}

moved {
  from = kubernetes_role_v1.tenant_reconciler
  to   = module.envelope.kubernetes_role_v1.tenant_reconciler
}

moved {
  from = kubernetes_role_binding_v1.tenant_reconciler
  to   = module.envelope.kubernetes_role_binding_v1.tenant_reconciler
}

moved {
  from = helm_release.workload
  to   = module.deploy.helm_release.workload
}
