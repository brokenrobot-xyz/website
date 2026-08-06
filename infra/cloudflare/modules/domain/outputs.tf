###############################################################################
# Cloudflare Zone (domain)
###############################################################################
output "domain_zone" {
  value = {
    zone_id = data.cloudflare_zone.domain_zone.zone_id
    name    = data.cloudflare_zone.domain_zone.name
    status  = data.cloudflare_zone.domain_zone.status
  }
}

###############################################################################
# Cloudflare Zone (domain settings)
###############################################################################
output "domain_zone_dns_settings" {
  value = data.cloudflare_zone_dns_settings.domain_zone_dns_settings
}

###############################################################################
# Cloudflare Zone (DNSSEC)
###############################################################################
output "domain_dnssec" {
  value = cloudflare_zone_dnssec.domain_dnssec
}
