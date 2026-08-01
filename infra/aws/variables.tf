variable "website_alarms_endpoints" {
  description = "The endpoints for the alarms SNS topic subscription"
  type        = list(string)
  nullable    = false
  sensitive   = false
}
