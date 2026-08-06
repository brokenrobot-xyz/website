###############################################################################
# Domain verification
###############################################################################

resource "cloudflare_dns_record" "domain_verification_record" {
  zone_id = var.domain_zone_id
  name    = "@"
  type    = "TXT"
  content = "\"${var.domain_verification_token}\""
  ttl     = 300
}

###############################################################################
# MX records
###############################################################################

resource "cloudflare_dns_record" "domain_mx_records" {
  for_each = { for record in var.domain_mx_records : record.host => record }

  zone_id  = var.domain_zone_id
  name     = "@"
  type     = "MX"
  content  = each.value.host
  priority = each.value.priority
  ttl      = 300
}

###############################################################################
# SPF record
###############################################################################

resource "cloudflare_dns_record" "domain_spf_record" {
  zone_id = var.domain_zone_id
  name    = "@"
  type    = "TXT"
  content = "\"${var.domain_spf_record}\""
  ttl     = 300
}

###############################################################################
# DKIM records
###############################################################################

resource "cloudflare_dns_record" "domain_dkim_records" {
  for_each = { for record in var.domain_dkim_records : record.host => record }

  zone_id = var.domain_zone_id
  name    = each.value.host
  type    = "CNAME"
  content = each.value.value
  ttl     = 300
  proxied = false
}

###############################################################################
# DMARC record
###############################################################################

resource "cloudflare_dns_record" "domain_dmarc_record" {
  zone_id = var.domain_zone_id
  name    = "_dmarc"
  type    = "TXT"
  content = "\"${var.domain_dmarc_record}\""
  ttl     = 300
}
