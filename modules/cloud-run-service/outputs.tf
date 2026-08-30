output "name" {
  value = google_cloud_run_v2_service.this.name
}

# One canonical URL for links; `urls` carries every hostname Cloud Run answers on — anything
# that must ACCEPT a request (CORS) uses urls, anything that EMITS a link uses uri.
output "uri" {
  value = google_cloud_run_v2_service.this.uri
}

output "urls" {
  value = google_cloud_run_v2_service.this.urls
}
