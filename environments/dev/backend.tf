terraform {
  backend "gcs" {
    bucket  = "terraform-state"
    prefix  = "dev"
  }
}
