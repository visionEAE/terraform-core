output "gateway_url" {
  value = module.gateway_service.uri
}

output "web_url" {
  value = module.web_service.uri
}

output "auth_url" {
  value = module.auth_service.uri
}

output "db_instance" {
  value = module.cloudsql.instance_name
}

output "db_private_ip" {
  value = module.cloudsql.private_ip
}

output "artifact_registry_repo_url" {
  # Re-exported from backend so the scripts read one state.
  value = local.backend.artifact_registry_repo_url
}

output "bastion_name" {
  value = google_compute_instance.bastion.name
}

output "bastion_zone" {
  value = google_compute_instance.bastion.zone
}

output "dwh_topic" {
  value = module.dwh.topic
}

output "run_urls" {
  description = "Deterministic URL per service, as wired into every env var."
  value       = local.run_url
}
