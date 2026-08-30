/**
 * Private networking for Cloud SQL. Cloud Run reaches the database through Direct VPC egress
 * with PRIVATE_RANGES_ONLY — deliberately not a Serverless VPC Access connector, which is a
 * billed pair of always-on instances, and deliberately not all-traffic egress, which would need
 * Cloud NAT for the internet (AuraDB) and add ~$32/month for nothing.
 */
resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = "${var.name}-subnet"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_service_range" {
  project       = var.project_id
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "this" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]

  # Otherwise teardown leaves the peering half-deleted and the next apply cannot recreate it.
  deletion_policy = "ABANDON"
}
