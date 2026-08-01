variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

variable "apex_domain_name" {
  description = "Apex domain name"
  type        = string
  sensitive   = false
}
