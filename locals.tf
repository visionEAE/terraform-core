locals {
  backend    = data.terraform_remote_state.backend.outputs
  project_id = local.backend.project_id
  region     = local.backend.region
  secrets    = local.backend.secret_ids

  env = terraform.workspace

  env_config = {
    prod = {
      db_tier             = "db-f1-micro" # shared-core; the whole demo fits and the trial budget matters
      db_disk_size_gb     = 10
      db_deletion_protect = true
      gateway_min         = 0 # bump to 1 later if cold starts annoy
      service_max         = 3
      relay_schedule      = "*/5 * * * *"
    }
    # staging = { ... }  # template: copy prod and adjust
  }
  primary_workspace = "prod"
  cfg               = lookup(local.env_config, local.env, local.env_config[local.primary_workspace])

  name_prefix = "s360-${local.env}"

  # The deterministic URL every Cloud Run v2 service answers on. Computing it here — instead of
  # reading it off the created service — is what lets the gateway receive every downstream URL,
  # and each callee its own audience, AT CREATION, with no cycles and no second apply.
  services = ["s360-auth", "s360-gateway", "s360-core", "s360-lms", "s360-support", "s360-network", "s360-web"]
  run_url = {
    for s in local.services :
    s => "https://${s}-${data.google_project.current.number}.${local.region}.run.app"
  }

  labels = {
    app        = "student360"
    env        = local.env
    managed_by = "terraform"
    repo       = "terraform-core"
  }
}

resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(keys(local.env_config), local.env)
      error_message = "Workspace '${terraform.workspace}' is not configured. Run 'terraform workspace select prod', or add the environment to local.env_config in locals.tf."
    }
  }
}
