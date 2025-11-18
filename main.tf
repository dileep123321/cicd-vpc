terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "google" {
  project                         = var.project_id
  region                          = var.region
  zone                            = var.zone
  impersonate_service_account     = var.deployer_service_account
}

# ------------------------------------------------------
# VPC Network
# ------------------------------------------------------
resource "google_compute_network" "secure_vpc" {
  name                    = "prod-secure-vpc"
  auto_create_subnetworks = false
}

# ------------------------------------------------------
# Public Subnet
# ------------------------------------------------------
resource "google_compute_subnetwork" "public_subnet" {
  name                  = "prod-public-sn"
  ip_cidr_range         = "10.20.1.0/24"
  network               = google_compute_network.secure_vpc.id
  region                = var.region
}

# ------------------------------------------------------
# Private Subnet
# ------------------------------------------------------
resource "google_compute_subnetwork" "private_subnet" {
  name                      = "prod-private-sn"
  ip_cidr_range             = "10.20.2.0/24"
  network                   = google_compute_network.secure_vpc.id
  region                    = var.region
  private_ip_google_access  = true
}

# ------------------------------------------------------
# Firewall Rule for IAP SSH
# ------------------------------------------------------
resource "google_compute_firewall" "iap_ssh" {
  name    = "prod-iap-ssh"
  network = google_compute_network.secure_vpc.name

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["prod-private-tag"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ------------------------------------------------------
# Cloud Router
# ------------------------------------------------------
resource "google_compute_router" "router" {
  name    = "prod-router"
  region  = var.region
  network = google_compute_network.secure_vpc.name
}

# ------------------------------------------------------
# Cloud NAT
# ------------------------------------------------------
resource "google_compute_router_nat" "nat" {
  name                               = "prod-nat-gw"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# ------------------------------------------------------
# Private VM (NO Public IP)
# ------------------------------------------------------
resource "google_compute_instance" "private_vm" {
  name         = "prod-private-vm"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["prod-private-tag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id

    # No external IP
    access_config {
      nat_ip = null
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

