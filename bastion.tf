/**
 * The only way a human reaches the private database: a stopped-by-default e2-micro (Always
 * Free) with no external IP, SSH'd through IAP. scripts/bastion.sh starts it, opens the tunnel
 * on localhost:15432 and stops it afterwards — zero cost and zero attack surface between uses.
 */
resource "google_service_account" "bastion" {
  project      = local.project_id
  account_id   = "${local.name_prefix}-bastion"
  display_name = "s360 database bastion"
}

resource "google_secret_manager_secret_iam_member" "bastion_pg_password" {
  project   = local.project_id
  secret_id = local.secrets["postgres-password"]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.bastion.email}"
}

resource "google_compute_firewall" "bastion_iap_ssh" {
  project = local.project_id
  name    = "${local.name_prefix}-bastion-iap-ssh"
  network = module.network.network_id

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # IAP's fixed range — nothing else reaches port 22
  target_tags   = ["db-bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "bastion" {
  project      = local.project_id
  name         = "${local.name_prefix}-bastion"
  zone         = "${local.region}-a"
  machine_type = "e2-micro"

  desired_status = "TERMINATED" # stopped by default; bastion.sh up starts it

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = module.network.subnet_id
    # no access_config block → no external IP
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags   = ["db-bastion"]
  labels = local.labels

  lifecycle {
    ignore_changes = [desired_status] # bastion.sh flips it; terraform must not fight back
  }
}
