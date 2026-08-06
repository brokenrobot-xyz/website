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

  # Interpolated into ruleset filter expressions, a Cloudflare list name and a
  # Pages project name, none of which escape it.
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.apex_domain_name))
    error_message = "The apex_domain_name must be a bare lowercase domain name, such as example.com."
  }
}

variable "domain_verification_token" {
  description = "TXT domain verification token"
  type        = string
}

variable "domain_mx_records" {
  description = "List of MX records"
  type = list(object({
    host     = string
    priority = number
  }))
}

variable "domain_spf_record" {
  description = "SPF record"
  type        = string
}

variable "domain_dkim_records" {
  description = "List of DKIM records"
  type = list(object({
    host  = string
    value = string
  }))
}

variable "domain_dmarc_record" {
  description = "DMARC record"
  type        = string
}
