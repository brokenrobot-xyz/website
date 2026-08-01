###############################################################################
# Cloudflare Pages
###############################################################################

resource "cloudflare_pages_project" "website" {
  account_id        = var.cloudflare_account_id
  name              = replace(var.apex_domain_name, ".", "-")
  production_branch = "main"
}

###############################################################################
# 404 Error Page
###############################################################################
# Cloudflare Pages will automatically serve a public/404.html file as the custom error page for 404 errors.
# No additional Terraform resource is required.
