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
