output "cloudfront_website" {
  value = {
    arn = module.cloudfront_website.arn
  }
}

output "route53_zone_name_servers" {
  description = "Nameservers of the Route 53 hosted zone"
  value       = module.route53_website.zone_name_servers
}
