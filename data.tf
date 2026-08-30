data "terraform_remote_state" "backend" {
  backend   = "gcs"
  workspace = terraform.workspace # a staging core reads staging's backend state

  config = {
    bucket = var.state_bucket
    prefix = "terraform-backend"
  }
}

data "google_project" "current" {
  project_id = local.backend.project_id
}
