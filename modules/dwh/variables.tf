variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "topic_name" {
  type = string
}

variable "dataset_id" {
  type = string
}

variable "events_table_id" {
  type = string
}

variable "relay_job_name" {
  type = string
}

variable "relay_member" {
  description = "IAM member of the relay's runtime service account."
  type        = string
}

variable "schedule" {
  type = string
}

variable "labels" {
  type = map(string)
}
