provider "google" {
  project = local.backend.project_id
  region  = local.backend.region

  default_labels = {
    app        = "student360"
    managed_by = "terraform"
  }
}
