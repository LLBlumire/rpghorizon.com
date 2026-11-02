terraform {
  required_version = "~> 1.12.0"
  backend "s3" {
    bucket                      = "personal-websites-opentofu-state-fr-par"
    key                         = "rpghorizon/infrastructure.tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    encrypt                     = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
  required_providers {
    scaleway = { source = "scaleway/scaleway", version = "~> 2.79.0" }
    porkbun  = { source = "marcfrederick/porkbun", version = "~> 1.3.3" }
  }
}
provider "scaleway" {}
provider "porkbun" {}
locals {
  organization_id = "78e60b8f-816f-472d-8c71-3ee28137a9d4"
  owner_user_id   = "03fafcc0-47d5-458e-83a4-7b268f2da283"
  bucket_name     = "rpghorizon-com-production-fr-par"
  region          = "fr-par"
}
variable "cutover" {
  type        = bool
  default     = true
  description = "False during staging or DNS rollback; true after HTTPS verification."
}
resource "scaleway_account_project" "site" {
  name            = "rpghorizon"
  description     = "RPG Horizon website storage and publishing; shared HTTPS proxy hosted separately"
  organization_id = local.organization_id
  lifecycle { prevent_destroy = true }
}
resource "scaleway_iam_application" "publisher" {
  name            = "rpghorizon-com-publisher"
  description     = "Publishes RPG Horizon from its GitHub production environment"
  organization_id = local.organization_id
  lifecycle { prevent_destroy = true }
}
resource "scaleway_iam_policy" "publisher" {
  name            = "rpghorizon-com-publisher"
  application_id  = scaleway_iam_application.publisher.id
  organization_id = local.organization_id
  rule {
    permission_set_names = ["ObjectStorageFullAccess"]
    project_ids          = [scaleway_account_project.site.id]
  }
  lifecycle { prevent_destroy = true }
}
resource "scaleway_object_bucket" "site" {
  name          = local.bucket_name
  project_id    = scaleway_account_project.site.id
  region        = local.region
  force_destroy = false
  versioning { enabled = true }
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [acl, force_destroy]
  }
}
resource "scaleway_object_bucket_acl" "site" {
  bucket     = scaleway_object_bucket.site.name
  project_id = scaleway_account_project.site.id
  region     = local.region
  acl        = "private"
  lifecycle { prevent_destroy = true }
}
resource "scaleway_object_bucket_policy" "site" {
  bucket     = scaleway_object_bucket.site.name
  project_id = scaleway_account_project.site.id
  region     = local.region
  policy = jsonencode({
    Version = "2023-04-17"
    Statement = [
      { Sid = "Public website reads", Effect = "Allow", Principal = "*", Action = ["s3:GetObject"], Resource = ["${local.bucket_name}/*"] },
      { Sid = "Publisher lists", Effect = "Allow", Principal = { SCW = "application_id:${scaleway_iam_application.publisher.id}" }, Action = ["s3:ListBucket"], Resource = [local.bucket_name] },
      { Sid = "Publisher writes", Effect = "Allow", Principal = { SCW = "application_id:${scaleway_iam_application.publisher.id}" }, Action = ["s3:PutObject", "s3:DeleteObject"], Resource = ["${local.bucket_name}/*"] },
      { Sid = "Owner administration", Effect = "Allow", Principal = { SCW = "user_id:${local.owner_user_id}" }, Action = ["*"], Resource = [local.bucket_name, "${local.bucket_name}/*"], Condition = { Bool = { "aws:SecureTransport" = "true" } } }
    ]
  })
  lifecycle { prevent_destroy = true }
}
resource "scaleway_object_bucket_website_configuration" "site" {
  bucket     = scaleway_object_bucket.site.name
  project_id = scaleway_account_project.site.id
  region     = local.region
  index_document { suffix = "index.html" }
  lifecycle { prevent_destroy = true }
}
resource "porkbun_dns_record" "apex" {
  domain    = "rpghorizon.com"
  subdomain = ""
  type      = "A"
  content   = var.cutover ? "51.159.110.43" : "76.76.21.21"
  ttl       = 600
  lifecycle { prevent_destroy = true }
}
resource "porkbun_dns_record" "www" {
  domain    = "rpghorizon.com"
  subdomain = "www"
  type      = "CNAME"
  content   = var.cutover ? "rpghorizon.com." : "cname.vercel-dns.com."
  ttl       = 600
  lifecycle { prevent_destroy = true }
}
import {
  to = porkbun_dns_record.apex
  id = "rpghorizon.com:337406004"
}
import {
  to = porkbun_dns_record.www
  id = "rpghorizon.com:337406096"
}
import {
  to = scaleway_object_bucket.site
  id = "fr-par/rpghorizon-com-production-fr-par@3784104f-34ea-4b5b-89a6-b6b311795daa"
}
output "project_id" { value = scaleway_account_project.site.id }
output "bucket_name" { value = scaleway_object_bucket.site.name }
output "publisher_application_id" { value = scaleway_iam_application.publisher.id }
