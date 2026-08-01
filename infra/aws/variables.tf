variable "website_alarms_endpoints" {
  description = "The endpoints for the alarms SNS topic subscription"
  type        = list(string)
  nullable    = false
  sensitive   = false
}

variable "cloudflare_name_servers" {
  description = "Nameservers of the Cloudflare zone (the zone_name_servers output of infra/cloudflare); leave empty until the DNS cutover"
  type        = list(string)
  default     = []
  nullable    = false
  sensitive   = false
}

variable "domain_transfer_lock" {
  description = "Whether the domain registration is locked against registrar transfer; disable to start the transfer to Cloudflare"
  type        = bool
  default     = true
  nullable    = false
  sensitive   = false
}
