# Provider is configured using environment variables: GOOGLE_REGION, GOOGLE_PROJECT, GOOGLE_CREDENTIALS.
# This can be set statically, if preferred. See docs for details.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#full-reference
provider "google" {}

data "google_client_config" "default" {}

# Defer reading the cluster data until the GKE cluster exists.
data "google_container_cluster" "default" {
  name       = "thomasscothamilton"
  location = "us-east1-b"
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.default.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  )
}

module "argocd" {
  depends_on   = [data.google_client_config.default]
  source       = "./argocd"
}

resource "kubernetes_namespace" "openapi-python-flask" {
  metadata {
    annotations = {
      name = "openapi-python-flask"
    }

    name = "openapi-python-flask"
  }
}