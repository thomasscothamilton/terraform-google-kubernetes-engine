# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.14.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
  }
}

# Provider is configured using environment variables: GOOGLE_REGION, GOOGLE_PROJECT, GOOGLE_CREDENTIALS.
# This can be set statically, if preferred. See docs for details.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#full-reference
provider "google" {}

# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {
  depends_on = [module.gke-cluster]
}

# Defer reading the cluster data until the GKE cluster exists.
data "google_container_cluster" "default" {
  name       = local.cluster_name
  location = "us-east1-b"
  depends_on = [module.gke-cluster]
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.default.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.default.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.default.master_auth[0].cluster_ca_certificate,
    )
  }
}

module "gke-cluster" {
  source       = "./gke-cluster"
  cluster_name = local.cluster_name
}

module "kubernetes-config" {
  source = "./kubernetes-config"
  cluster_name = local.cluster_name
}

# //+ Config Connector GKE
# module "wi" {
#   source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
#   version             = "~> 35.0"
#   gcp_sa_name         = "cnrmsa"
#   cluster_name        = local.cluster_name
#   name                = "cnrm-controller-manager"
#   location            = "us-east1-b"
#   use_existing_k8s_sa = true
#   annotate_k8s_sa     = false
#   namespace           = "cnrm-system"
#   project_id          = "thomasscothamilton"
#   roles               = ["roles/owner"]
# }

//- Config Connector GKE


