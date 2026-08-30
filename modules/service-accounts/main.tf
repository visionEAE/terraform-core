/**
 * One runtime identity per workload. Cloud Run defaults to the Compute Engine default service
 * account — which carries project Editor — so every service here runs as its own least-privilege
 * account: a couple of project roles (logging, monitoring) and per-secret accessor grants,
 * never a project-wide secret role.
 */
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_secret_manager_secret_iam_member" "secrets" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this.email}"
}
