/**
 * A Cloud Run job: same shape philosophy as the service module — Terraform owns the job's
 * definition, the pipeline owns the image (ignored after creation), the scheduler owns when it
 * runs.
 */
resource "google_cloud_run_v2_job" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  deletion_protection = false

  template {
    template {
      service_account = var.service_account_email
      timeout         = var.timeout
      max_retries     = var.max_retries

      dynamic "vpc_access" {
        for_each = var.vpc_subnet_id == null ? [] : [1]
        content {
          egress = "PRIVATE_RANGES_ONLY"
          network_interfaces {
            network    = var.vpc_network_id
            subnetwork = var.vpc_subnet_id
          }
        }
      }

      containers {
        image = var.image

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  labels = var.labels

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}
