variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "tier" {
  type = string
}

variable "disk_size_gb" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "network_id" {
  type = string
}

variable "database" {
  type    = string
  default = "student360"
}

variable "user_names" {
  description = "DB roles to create. Split from the passwords: for_each keys must not be sensitive."
  type        = list(string)
}

variable "user_passwords" {
  description = "DB user name → password (sensitive, read from Secret Manager by the caller)."
  type        = map(string)
  sensitive   = true
}

variable "labels" {
  type = map(string)
}
