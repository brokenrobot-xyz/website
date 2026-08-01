###############################################################################
# Simple Static Website
###############################################################################

module "website" {
  source    = "./modules/simple-static-website"
  providers = { cloudflare = cloudflare }

  cloudflare_account_id = var.cloudflare_account_id
  apex_domain_name      = var.apex_domain_name
}
