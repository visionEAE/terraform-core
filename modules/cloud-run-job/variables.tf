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

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "timeout" {
  type    = string
  default = "300s"
}

variable "max_retries" {
  type    = number
  default = 1
}

variable "env" {
  type    = map(string)
  default = {}
}

variable "secret_env" {
  type    = map(string)
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

variable "labels" {
  type = map(string)
}
