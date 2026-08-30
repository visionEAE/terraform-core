# Same bucket as terraform-backend, different prefix: the two configurations never share a state
# file, only the bucket's versioning and access controls. Keep the literal in sync with
# terraform-backend/locals.tf.
terraform {
  backend "gcs" {
    bucket = "s360-tfstate-CHANGE-ME-PROJECT-ID"
    prefix = "terraform-core"
  }
}
