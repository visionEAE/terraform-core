variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "image" {
  type = string
}

variable "service_account_email" {
  type = string
}

variable "container_port" {
  type = number
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "cpu_idle" {
  description = "true bills CPU only during requests; false keeps it allocated between them."
  type        = bool
  default     = true
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 3
}

variable "concurrency" {
  type    = number
  default = 80
}

variable "request_timeout" {
  type    = string
  default = "300s"
}

variable "env" {
  type    = map(string)
  default = {}
}

variable "secret_env" {
  description = "Env var name → fully-qualified secret id, injected as latest."
  type        = map(string)
  default     = {}
}

variable "secret_volumes" {
  description = "Volume name → {secret_id, filename, mount_path}."
  type = map(object({
    secret_id  = string
    filename   = string
    mount_path = string
  }))
  default = {}
}

variable "vpc_network_id" {
  type    = string
  default = null
}

variable "vpc_subnet_id" {
  type    = string
  default = null
}

variable "startup_probe_path" {
  type    = string
  default = "/actuator/health"
}

variable "startup_probe_initial_delay" {
  type    = number
  default = 20
}

variable "startup_probe_failures" {
  description = "With period 10s: failures × 10s + initial delay must stay inside Cloud Run's 240s ceiling."
  type        = number
  default     = 20
}

variable "liveness_probe_path" {
  type    = string
  default = "/actuator/health"
}

variable "allow_public_access" {
  type    = bool
  default = false
}

variable "invoker_members" {
  description = "IAM members granted run.invoker (the private-service allowlist)."
  type        = list(string)
  default     = []
}

variable "labels" {
  type = map(string)
}
