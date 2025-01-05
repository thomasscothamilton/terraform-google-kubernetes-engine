# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.14.1"
    }
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

# This is used to set local variable google_zone.
# This can be replaced with a statically-configured zone, if preferred.
data "google_compute_zones" "available" {
  provider = google-beta
}

locals {
  google_zone = "us-east1-b"  # Replace with your preferred zone
}

data "google_container_engine_versions" "supported" {
  provider = google-beta

  location       = local.google_zone
  version_prefix = var.kubernetes_version
}

resource "google_service_account" "cnrmsa" {
  account_id   = "cnrmsa"
  display_name = "Config Connector Service Account"
  create_ignore_already_exists = true
}

# resource "google_project_iam_member" "editor_role" {
#   project = "thomasscothamilton"
#   role    = "roles/editor"
#   member  = "serviceAccount:${google_service_account.cnrmsa.email}"
# }

resource "google_project_iam_member" "role_bindings" {
  for_each = toset([
    "roles/iam.roleAdmin",
    "roles/iam.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/cloudsql.client",
    "roles/iam.serviceAccountTokenCreator"
  ])
  project = "thomasscothamilton"
  role    = each.value
  member  = "serviceAccount:${google_service_account.cnrmsa.email}"
}

# Bind the Service Account to a Kubernetes Service Account
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.cnrmsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:thomasscothamilton.svc.id.goog[cnrm-system/cnrm-controller-manager]"
}

resource "google_container_cluster" "default" {
  provider = google-beta

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "thomasscothamilton.svc.id.goog"
  }

  name               = var.cluster_name
  location           = local.google_zone
  initial_node_count = var.workers_count
  min_master_version = data.google_container_engine_versions.supported.latest_master_version
  # node version must match master version
  # https://www.terraform.io/docs/providers/google/r/container_cluster.html#node_version
  node_version       = data.google_container_engine_versions.supported.latest_master_version

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  release_channel {
    channel = "RAPID"
  }

#   node_locations = [
#     "us-east1-b",
#   ]

  node_config {
    spot = true
#     preemptible  = true
    machine_type = "e2-standard-2"
    disk_size_gb = 10

    service_account = google_service_account.cnrmsa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/sqlservice.admin",
      "https://www.googleapis.com/auth/devstorage.read_write"
    ]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  addons_config {
    config_connector_config {
      enabled = true
    }
  }

  identity_service_config {
    enabled = var.idp_enabled
  }

  deletion_protection = false
}
