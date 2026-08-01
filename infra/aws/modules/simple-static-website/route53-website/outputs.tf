output "zone_name_servers" {
  description = "Nameservers of the Route 53 hosted zone"
  value       = data.aws_route53_zone.website.name_servers
}
