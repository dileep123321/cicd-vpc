variable "project_id" {}
variable "region" { default = "us-central1" }
variable "zone" { default = "us-central1-a" }

variable "deployer_service_account" {
  description = "Service Account for OIDC-based Terraform deployer"
}

