# ============================================================================================ #
# providers.tf — Provider configuration for Rancher framework                                   #
# ============================================================================================ #

#region ------ [ Rancher Provider ] ---------------------------------------------------------- #

provider "rancher2" {

  # Configure Rancher admin-mode API access from caller-supplied credentials.
  api_url   = var.rancher_config.api_url
  token_key = var.rancher_config.token_key
  insecure  = var.rancher_config.insecure
  ca_certs  = var.rancher_config.ca_certs

}

#endregion --- [ Rancher Provider ] ---------------------------------------------------------- #


#region ------ [ Kubernetes Provider ] ------------------------------------------------------- #

provider "kubernetes" {

  # Use the platform envelope's admin downstream-cluster context for RBAC creation.
  config_path            = var.kubernetes_admin.config_path
  config_paths           = var.kubernetes_admin.config_paths
  config_context         = var.kubernetes_admin.config_context
  host                   = var.kubernetes_admin.host
  username               = var.kubernetes_admin.username
  password               = var.kubernetes_admin.password
  token                  = var.kubernetes_admin.token
  insecure               = var.kubernetes_admin.insecure
  tls_server_name        = var.kubernetes_admin.tls_server_name
  client_certificate     = var.kubernetes_admin.client_certificate
  client_key             = var.kubernetes_admin.client_key
  cluster_ca_certificate = var.kubernetes_admin.cluster_ca_certificate
  proxy_url              = var.kubernetes_admin.proxy_url

}

#endregion --- [ Kubernetes Provider ] ------------------------------------------------------- #


#region ------ [ Helm Provider ] ------------------------------------------------------------- #

provider "helm" {

  # Authenticate to the Rancher-managed downstream cluster.
  kubernetes = {
    config_path            = var.helm_kubernetes.config_path
    config_paths           = var.helm_kubernetes.config_paths
    config_context         = var.helm_kubernetes.config_context
    host                   = var.helm_kubernetes.host
    username               = var.helm_kubernetes.username
    password               = var.helm_kubernetes.password
    token                  = var.helm_kubernetes.token
    insecure               = var.helm_kubernetes.insecure
    tls_server_name        = var.helm_kubernetes.tls_server_name
    client_certificate     = var.helm_kubernetes.client_certificate
    client_key             = var.helm_kubernetes.client_key
    cluster_ca_certificate = var.helm_kubernetes.cluster_ca_certificate
    proxy_url              = var.helm_kubernetes.proxy_url
  }

}

#endregion --- [ Helm Provider ] ------------------------------------------------------------- #
