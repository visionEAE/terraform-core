variable "project_id" {
  type = string
}

variable "account_id" {
  type = string
}

variable "display_name" {
  type = string
}

variable "project_roles" {
  type    = list(string)
  default = ["roles/logging.logWriter", "roles/monitoring.metricWriter"]
}

variable "secret_ids" {
  description = "Fully-qualified secret ids this identity may read."
  type        = list(string)
  default     = []
}
