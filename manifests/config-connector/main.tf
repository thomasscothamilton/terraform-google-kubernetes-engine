terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
  }
}

# Local Variables
locals {
  # Define path to CRD files with fallback to avoid errors
  crd_directory = "${path.module}/config-connector/operator-system"
  crd_files     = try(fileset(local.crd_directory, "*.yaml"), [])
}

# Config Connector Custom Resource Definitions Installation
resource "kubernetes_manifest" "config_connector_crds" {
  for_each = toset(local.crd_files)

  manifest = file(each.value)
}
