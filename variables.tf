variable "state_bucket" {
  description = <<-EOT
    Bucket holding both configurations' state. A variable only because the remote-state data
    source accepts one while the backend block cannot; the default must match backend.tf.
  EOT
  type        = string
  default     = "s360-tfstate-project-42179253-bad9-49f0-835"
}

# Images are read ONLY at service creation — the cloud-run modules ignore_changes on the image
# afterwards, because CI owns which build is live and Terraform owns the shape.
#
# Deliberately asymmetric on first apply: the six Java services need REAL images (a placeholder
# fails the /actuator/health startup probe and aborts the apply — push them first with
# scripts/deploy.sh), while web and the relay start from Google's hello image: web's real image
# cannot exist yet (Vite bakes the gateway URL, which this apply creates) and the relay is a job
# that nothing probes.
variable "auth_image" {
  type = string
}

variable "gateway_image" {
  type = string
}

variable "core_image" {
  type = string
}

variable "lms_image" {
  type = string
}

variable "support_image" {
  type = string
}

variable "network_image" {
  type = string
}

variable "web_image" {
  type    = string
  default = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "relay_image" {
  type    = string
  default = "us-docker.pkg.dev/cloudrun/container/hello"
}
