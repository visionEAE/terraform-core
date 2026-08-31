/**
 * terraform-core — the disposable half: everything here can be destroyed and rebuilt from zero
 * against terraform-backend's outputs. Consumes that repo's state as a published contract.
 */

module "network" {
  source     = "./modules/network"
  project_id = local.project_id
  region     = local.region
  name       = "${local.name_prefix}-net"
}

# Passwords come straight from Secret Manager — they exist in exactly one place.
data "google_secret_manager_secret_version" "db" {
  for_each = toset([
    "postgres-password", "auth-db-password", "core-db-password",
    "lms-db-password", "support-db-password", "network-db-password", "dwh-relay-db-password",
  ])
  secret = local.secrets[each.key]
}

module "cloudsql" {
  source = "./modules/cloudsql"

  project_id          = local.project_id
  region              = local.region
  name                = "${local.name_prefix}-pg"
  tier                = local.cfg.db_tier
  disk_size_gb        = local.cfg.db_disk_size_gb
  deletion_protection = local.cfg.db_deletion_protect
  network_id          = module.network.network_id
  labels              = local.labels

  user_names = ["postgres", "auth_user", "core_user", "lms_user", "support_user", "network_user", "dwh_relay"]

  user_passwords = {
    postgres     = data.google_secret_manager_secret_version.db["postgres-password"].secret_data
    auth_user    = data.google_secret_manager_secret_version.db["auth-db-password"].secret_data
    core_user    = data.google_secret_manager_secret_version.db["core-db-password"].secret_data
    lms_user     = data.google_secret_manager_secret_version.db["lms-db-password"].secret_data
    support_user = data.google_secret_manager_secret_version.db["support-db-password"].secret_data
    network_user = data.google_secret_manager_secret_version.db["network-db-password"].secret_data
    dwh_relay    = data.google_secret_manager_secret_version.db["dwh-relay-db-password"].secret_data
  }

  depends_on = [module.network]
}

# ------------------------------------------------------------------------- runtime identities
module "auth_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-auth"
  display_name = "s360 auth-service runtime"
  secret_ids = [
    local.secrets["auth-db-password"],
    local.secrets["jwt-private-pem"],
    local.secrets["seed-student-password"],
    local.secrets["seed-staff-password"],
  ]
}

module "gateway_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-gateway"
  display_name = "s360 gateway runtime"
}

module "core_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-core"
  display_name = "s360 core-service runtime"
  secret_ids   = [local.secrets["core-db-password"]]
}

module "lms_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-lms"
  display_name = "s360 lms-service runtime"
  secret_ids   = [local.secrets["lms-db-password"]]
}

module "support_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-support"
  display_name = "s360 support-service runtime"
  secret_ids   = [local.secrets["support-db-password"], local.secrets["pseudonym-secret"]]
}

module "network_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-network"
  display_name = "s360 network-service runtime"
  secret_ids = [
    local.secrets["network-db-password"],
    local.secrets["neo4j-uri"],
    local.secrets["neo4j-password"],
  ]
}

module "web_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-web"
  display_name = "s360 web runtime"
  # Static files off nginx: no secrets, nothing to reach privately.
}

module "relay_sa" {
  source       = "./modules/service-accounts"
  project_id   = local.project_id
  account_id   = "${local.name_prefix}-run-relay"
  display_name = "s360 dwh relay runtime"
  secret_ids   = [local.secrets["dwh-relay-db-password"]]
}

# ------------------------------------------------------------------------------- the services
locals {
  db_env = {
    POSTGRES_HOST = module.cloudsql.private_ip
    POSTGRES_PORT = "5432"
    POSTGRES_DB   = module.cloudsql.database
    # db-f1-micro's max_connections is tiny and every instance of every service brings its own
    # pool: five services x Hikari's default 10 exhausted it on the very first boot. Relaxed
    # binding turns these into spring.datasource.hikari.* without touching any image.
    SPRING_DATASOURCE_HIKARI_MAXIMUMPOOLSIZE = "3"
    SPRING_DATASOURCE_HIKARI_MINIMUMIDLE     = "0"
  }
}

module "auth_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-auth"
  image                 = var.auth_image
  service_account_email = module.auth_sa.email
  container_port        = 8081
  memory                = "768Mi"
  min_instances         = 0
  max_instances         = local.cfg.service_max
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  allow_public_access   = true # the SSO is the front door; login/refresh/JWKS are public by design
  labels                = local.labels

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    JWT_ISSUER             = local.run_url["s360-auth"]
    JWT_KEY_ID             = "student360-${local.env}"
    JWT_PRIVATE_KEY_PATH   = "/secrets/jwt/jwt-private.pem"
  })

  secret_env = {
    AUTH_DB_PASSWORD      = local.secrets["auth-db-password"]
    SEED_STUDENT_PASSWORD = local.secrets["seed-student-password"]
    SEED_STAFF_PASSWORD   = local.secrets["seed-staff-password"]
  }

  secret_volumes = {
    jwt = {
      secret_id  = local.secrets["jwt-private-pem"]
      filename   = "jwt-private.pem"
      mount_path = "/secrets/jwt"
    }
  }

  depends_on = [module.cloudsql]
}

module "gateway_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-gateway"
  image                 = var.gateway_image
  service_account_email = module.gateway_sa.email
  container_port        = 8080
  memory                = "768Mi"
  min_instances         = local.cfg.gateway_min
  max_instances         = local.cfg.service_max
  allow_public_access   = true
  labels                = local.labels
  # No VPC: the gateway only talks to the other services' public run.app endpoints.

  env = {
    SPRING_PROFILES_ACTIVE = "prod"
    JWT_ISSUER             = local.run_url["s360-auth"]
    AUTH_SERVICE_URL       = local.run_url["s360-auth"]
    CORE_SERVICE_URL       = local.run_url["s360-core"]
    LMS_SERVICE_URL        = local.run_url["s360-lms"]
    SUPPORT_SERVICE_URL    = local.run_url["s360-support"]
    NETWORK_SERVICE_URL    = local.run_url["s360-network"]
    FRONTEND_ORIGIN        = local.run_url["s360-web"]
  }
}

module "core_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-core"
  image                 = var.core_image
  service_account_email = module.core_sa.email
  container_port        = 8082
  min_instances         = 0
  max_instances         = local.cfg.service_max
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  labels                = local.labels

  invoker_members = [module.gateway_sa.member, module.support_sa.member, module.network_sa.member]

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    SERVICE_AUDIENCE       = local.run_url["s360-core"]
  })

  secret_env = {
    CORE_DB_PASSWORD = local.secrets["core-db-password"]
  }

  depends_on = [module.cloudsql]
}

module "lms_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-lms"
  image                 = var.lms_image
  service_account_email = module.lms_sa.email
  container_port        = 8083
  min_instances         = 0
  max_instances         = local.cfg.service_max
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  labels                = local.labels

  invoker_members = [module.gateway_sa.member, module.support_sa.member]

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    SERVICE_AUDIENCE       = local.run_url["s360-lms"]
  })

  secret_env = {
    LMS_DB_PASSWORD = local.secrets["lms-db-password"]
  }

  depends_on = [module.cloudsql]
}

module "support_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-support"
  image                 = var.support_image
  service_account_email = module.support_sa.email
  container_port        = 8084
  memory                = "768Mi"
  min_instances         = 0
  max_instances         = local.cfg.service_max
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  labels                = local.labels

  invoker_members = [module.gateway_sa.member]

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    SERVICE_AUDIENCE       = local.run_url["s360-support"]
    CORE_SERVICE_URL       = local.run_url["s360-core"]
    LMS_SERVICE_URL        = local.run_url["s360-lms"]
  })

  secret_env = {
    SUPPORT_DB_PASSWORD = local.secrets["support-db-password"]
    PSEUDONYM_SECRET    = local.secrets["pseudonym-secret"]
  }

  depends_on = [module.cloudsql]
}

module "network_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-network"
  image                 = var.network_image
  service_account_email = module.network_sa.email
  container_port        = 8085
  min_instances         = 0
  max_instances         = local.cfg.service_max
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  labels                = local.labels

  invoker_members = [module.gateway_sa.member]

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    SERVICE_AUDIENCE       = local.run_url["s360-network"]
    CORE_SERVICE_URL       = local.run_url["s360-core"]
    NEO4J_USER             = "neo4j"
  })

  secret_env = {
    NETWORK_DB_PASSWORD = local.secrets["network-db-password"]
    NEO4J_URI           = local.secrets["neo4j-uri"]
    NEO4J_PASSWORD      = local.secrets["neo4j-password"]
  }

  depends_on = [module.cloudsql]
}

module "web_service" {
  source = "./modules/cloud-run-service"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-web"
  image                 = var.web_image
  service_account_email = module.web_sa.email
  container_port        = 8080
  memory                = "256Mi"
  min_instances         = 0
  max_instances         = local.cfg.service_max
  allow_public_access   = true
  labels                = local.labels

  # nginx serving static files: no VPC, no secrets, and probes on / instead of actuator.
  startup_probe_path          = "/"
  liveness_probe_path         = "/"
  startup_probe_initial_delay = 0
  startup_probe_failures      = 6
}

# ------------------------------------------------------------------------------ the DWH relay
module "relay_job" {
  source = "./modules/cloud-run-job"

  project_id            = local.project_id
  region                = local.region
  name                  = "s360-relay"
  image                 = var.relay_image
  service_account_email = module.relay_sa.email
  vpc_network_id        = module.network.network_id
  vpc_subnet_id         = module.network.subnet_id
  labels                = local.labels

  env = merge(local.db_env, {
    SPRING_PROFILES_ACTIVE = "prod"
    PUBSUB_TOPIC           = "student360-events"
    RELAY_BATCH_SIZE       = "100"
    GOOGLE_CLOUD_PROJECT   = local.project_id
  })

  secret_env = {
    DWH_RELAY_DB_PASSWORD = local.secrets["dwh-relay-db-password"]
  }

  depends_on = [module.cloudsql]
}

module "dwh" {
  source = "./modules/dwh"

  project_id      = local.project_id
  project_number  = data.google_project.current.number
  region          = local.region
  name_prefix     = local.name_prefix
  topic_name      = "student360-events"
  dataset_id      = local.backend.bigquery_dataset_id
  events_table_id = local.backend.bigquery_events_table_id
  relay_job_name  = module.relay_job.name
  relay_member    = module.relay_sa.member
  schedule        = local.cfg.relay_schedule
  labels          = local.labels
}

# ------------------------------------------------- deployer grants (access lives with the target)
locals {
  deployer_targets = {
    "s360-auth"    = { service = module.auth_service.name, sa = module.auth_sa.name }
    "s360-gateway" = { service = module.gateway_service.name, sa = module.gateway_sa.name }
    "s360-core"    = { service = module.core_service.name, sa = module.core_sa.name }
    "s360-lms"     = { service = module.lms_service.name, sa = module.lms_sa.name }
    "s360-support" = { service = module.support_service.name, sa = module.support_sa.name }
    "s360-network" = { service = module.network_service.name, sa = module.network_sa.name }
    "s360-web"     = { service = module.web_service.name, sa = module.web_sa.name }
  }
}

# developer, not admin: the pipeline rolls revisions but can never rewrite a service's IAM.
resource "google_cloud_run_v2_service_iam_member" "deployer" {
  for_each = local.deployer_targets

  project  = local.project_id
  location = local.region
  name     = each.value.service
  role     = "roles/run.developer"
  member   = local.backend.github_deployer_member
}

# Cloud Run treats "deploy as this runtime SA" as impersonation.
resource "google_service_account_iam_member" "deployer_act_as" {
  for_each = merge(local.deployer_targets, {
    "s360-relay" = { service = module.relay_job.name, sa = module.relay_sa.name }
  })

  service_account_id = each.value.sa
  role               = "roles/iam.serviceAccountUser"
  member             = local.backend.github_deployer_member
}

resource "google_cloud_run_v2_job_iam_member" "deployer_relay" {
  project  = local.project_id
  location = local.region
  name     = module.relay_job.name
  role     = "roles/run.developer"
  member   = local.backend.github_deployer_member
}
