output "zone_name_servers" {
  description = "Nameservers Cloudflare assigns to the zone; set these at the registrar"
  value       = cloudflare_zone.website.name_servers
}

output "pages_subdomain" {
  description = "The project's pages.dev hostname"
  value       = cloudflare_pages_project.website.subdomain
}
