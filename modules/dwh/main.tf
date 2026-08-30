/**
 * The data warehouse feed: outbox → relay (Cloud Run job, scheduled) → Pub/Sub → BigQuery
 * subscription → the dataset terraform-backend owns. The topic carries no schema and the
 * subscription writes metadata + raw envelope, so the payload can evolve without a schema
 * mismatch ever dropping events. No ordering keys: the BigQuery subscription writes unordered
 * regardless, the envelope carries timestamps, and ordering keys would only cap throughput.
 */
resource "google_pubsub_topic" "events" {
  project = var.project_id
  name    = var.topic_name
  labels  = var.labels
}

# Pub/Sub's own service agent writes into BigQuery; grant it on the dataset.
resource "google_bigquery_dataset_iam_member" "pubsub_writer" {
  project    = var.project_id
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "to_bigquery" {
  project = var.project_id
  name    = "${var.topic_name}-to-bq"
  topic   = google_pubsub_topic.events.id

  bigquery_config {
    table          = "${var.project_id}.${var.dataset_id}.${var.events_table_id}"
    write_metadata = true
  }

  # If BigQuery rejects a message there is no dead-letter yet: keep retrying for a week.
  message_retention_duration = "604800s"
  expiration_policy {
    ttl = "" # never expire the subscription itself
  }

  labels = var.labels

  depends_on = [google_bigquery_dataset_iam_member.pubsub_writer]
}

# The relay may publish to this topic and nothing else.
resource "google_pubsub_topic_iam_member" "relay_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.events.name
  role    = "roles/pubsub.publisher"
  member  = var.relay_member
}

# Cloud Scheduler triggers the job through the Cloud Run Admin API with an OAuth token of a
# dedicated identity that may invoke this one job and nothing else.
resource "google_service_account" "scheduler" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-scheduler"
  display_name = "Cloud Scheduler → dwh relay"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = var.relay_job_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "relay" {
  project   = var.project_id
  region    = var.region
  name      = "${var.name_prefix}-relay"
  schedule  = var.schedule
  time_zone = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${var.relay_job_name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }

  retry_config {
    retry_count = 1
  }
}
