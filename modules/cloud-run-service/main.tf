/**
 * The reusable Cloud Run v2 service. Terraform owns the SHAPE — resources, probes, env,
 * secrets, scaling, identity; the deploy pipeline owns WHICH BUILD IS LIVE, which is why the
 * image is ignored after creation: a terraform apply must never roll a service back to the
 * image the tfvars happened to name.
 */
resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL" # privacy comes from IAM, not from ingress —
  # internal-only ingress would force all-traffic VPC egress on every caller (Cloud NAT money)
  # and break direct egress to AuraDB.

  template {
    service_account                  = var.service_account_email
    max_instance_request_concurrency = var.concurrency
    timeout                          = var.request_timeout

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

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

    dynamic "volumes" {
      for_each = var.secret_volumes
      content {
        name = volumes.key
        secret {
          secret = volumes.value.secret_id
          items {
            version = "latest"
            path    = volumes.value.filename
          }
        }
      }
    }

    containers {
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = true
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

      dynamic "volume_mounts" {
        for_each = var.secret_volumes
        content {
          name       = volume_mounts.key
          mount_path = volume_mounts.value.mount_path
        }
      }

      startup_probe {
        initial_delay_seconds = var.startup_probe_initial_delay
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = var.startup_probe_failures
        http_get {
          path = var.startup_probe_path
        }
      }

      liveness_probe {
        period_seconds    = 30
        timeout_seconds   = 5
        failure_threshold = 3
        http_get {
          path = var.liveness_probe_path
        }
      }
    }
  }

  labels = var.labels

  lifecycle {
    precondition {
      condition     = var.vpc_subnet_id == null || var.max_instances <= 10
      error_message = "max_instances must be <= 10 on a service with Direct VPC egress until the project's quota is raised; requested ${var.max_instances}."
    }
    ignore_changes = [
      template[0].containers[0].image, # CI rolls by digest; Terraform never rolls back a build
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = each.value
}
