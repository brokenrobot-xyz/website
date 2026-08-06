variable "domain_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
  sensitive   = true
}

variable "domain_verification_token" {
  description = "Domain verification token"
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
