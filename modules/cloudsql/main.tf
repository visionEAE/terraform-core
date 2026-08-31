/**
 * One PostgreSQL instance, private IP only, holding every service's schema — the same layout
 * infra/init-db creates locally. Users are declared here (passwords from Secret Manager, so
 * they exist in exactly one place); schemas, ownership and grants are SQL, run once by
 * scripts/db-init.sh, because Terraform has no resource for them.
 */
resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = var.name
  region           = var.region
  database_version = "POSTGRES_16"

  settings {
    edition           = "ENTERPRISE" # ENTERPRISE_PLUS rejects shared-core tiers and costs ~2×
    tier              = var.tier
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "07:00"
      point_in_time_recovery_enabled = false # trial budget; the demo data is reseedable
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 8
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled = true
    }

    # Headroom over the shared-core default (25): 6 workloads x small pools x up to 3 instances.
    database_flags {
      name  = "max_connections"
      value = "50"
    }

    user_labels = var.labels
  }

  deletion_protection = var.deletion_protection

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_user" "users" {
  for_each = toset(var.user_names)

  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = each.key
  password = var.user_passwords[each.key]
}
