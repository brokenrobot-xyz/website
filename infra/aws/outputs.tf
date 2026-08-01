# Contains outputs from the resources created in main.tf

output "route53_zone_name_servers" {
  description = "Nameservers of the Route 53 hosted zone - the rollback values for cloudflare_name_servers during the DNS cutover"
  value       = module.simple_static_website.route53_zone_name_servers
}
