variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

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

variable "manage_registrar_domain" {
  description = "Whether the domain is at Cloudflare Registrar (set after the transfer completes)"
  type        = bool
  default     = false
  sensitive   = false
}
