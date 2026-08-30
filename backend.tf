# Same bucket as terraform-backend, different prefix: the two configurations never share a state
# file, only the bucket's versioning and access controls. Keep the literal in sync with
# terraform-backend/locals.tf.
terraform {
  backend "gcs" {
    bucket = "s360-tfstate-project-42179253-bad9-49f0-835"
    prefix = "terraform-core"
  }
}
