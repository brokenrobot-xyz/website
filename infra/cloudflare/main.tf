###############################################################################
# Domain
###############################################################################

module "domain" {
  source = "./modules/domain"

  apex_domain_name = var.apex_domain_name
}

###############################################################################
# Email
###############################################################################

module "email" {
  source = "./modules/email"

  domain_zone_id            = module.domain.domain_zone.zone_id
  domain_verification_token = var.domain_verification_token
  domain_mx_records         = var.domain_mx_records
  domain_spf_record         = var.domain_spf_record
  domain_dkim_records       = var.domain_dkim_records
  domain_dmarc_record       = var.domain_dmarc_record
}

###############################################################################
# Simple Static Website
###############################################################################

module "website" {
  source = "./modules/simple-static-website"

  cloudflare_account_id = var.cloudflare_account_id
  domain_zone_id        = module.domain.domain_zone.zone_id
  apex_domain_name      = var.apex_domain_name
}
