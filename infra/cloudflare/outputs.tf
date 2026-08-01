output "zone_name_servers" {
  description = "Nameservers Cloudflare assigns to the zone; set these at the registrar"
  value       = module.website.zone_name_servers
}

output "pages_subdomain" {
  description = "The project's pages.dev hostname"
  value       = module.website.pages_subdomain
}
