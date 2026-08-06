###############################################################################
# Cloudflare Pages
###############################################################################

locals {
  domain_subdomain = "www"
}

resource "cloudflare_pages_project" "website" {
  account_id        = var.cloudflare_account_id
  name              = replace(var.apex_domain_name, ".", "-")
  production_branch = "main"
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.website.name
  name         = "${local.domain_subdomain}.${var.apex_domain_name}"
}

resource "cloudflare_dns_record" "www_cname" {
  zone_id = var.domain_zone_id
  name    = local.domain_subdomain
  type    = "CNAME"
  content = "${cloudflare_pages_project.website.name}.pages.dev"
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "apex_placeholder" {
  zone_id = var.domain_zone_id
  name    = "@"
  type    = "A"
  content = "192.0.2.1"
  proxied = true
  ttl     = 1
}

###############################################################################
# Redirects
###############################################################################

# Redirect pages.dev to www
#
# The *.pages.dev hostname is served outside this zone, so zone rulesets cannot
# match it. Bulk Redirects run at the account level, which is why they can.
#
# This module owns the Bulk Redirect List only. The Bulk Redirect Rule that
# points at it is created by hand -- see the README: every Rule in the account
# shares one entry point ruleset, so no per-site module can own it.
resource "cloudflare_list" "pages_dev_redirect" {
  account_id  = var.cloudflare_account_id
  name        = "${replace(var.apex_domain_name, ".", "_")}_pages_dev_redirect"
  description = "Redirect the Pages default hostname to the custom domain"
  kind        = "redirect"
}

resource "cloudflare_list_item" "pages_dev_to_www" {
  account_id = var.cloudflare_account_id
  list_id    = cloudflare_list.pages_dev_redirect.id

  redirect = {
    source_url  = "${cloudflare_pages_project.website.name}.pages.dev/"
    target_url  = "https://${local.domain_subdomain}.${var.apex_domain_name}/"
    status_code = 301

    # Also covers the per-deployment <hash>.<project>.pages.dev hostnames
    include_subdomains    = true
    subpath_matching      = true
    preserve_path_suffix  = true
    preserve_query_string = true
  }
}

# Redirect apex domain to www
resource "cloudflare_ruleset" "apex_to_www" {
  zone_id = var.domain_zone_id
  name    = "Redirect apex domain to www"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [
    {
      enabled     = true
      description = "Redirect apex domain to www"
      ref         = "apex_to_www_rule"
      action      = "redirect"
      expression  = "(http.host eq \"${var.apex_domain_name}\")"

      action_parameters = {
        from_value = {
          status_code = 301

          preserve_query_string = true
          subpath_matching      = true
          preserve_path_suffix  = true
          include_subdomains    = false

          target_url = {
            expression = "concat(\"https://${local.domain_subdomain}.${var.apex_domain_name}\", http.request.uri.path)"
          }
        }
      }
    }
  ]
}

###############################################################################
# Cloudflare Web Analytics
###############################################################################
resource "cloudflare_web_analytics_site" "www_analytics" {
  account_id = var.cloudflare_account_id
  zone_tag   = var.domain_zone_id

  auto_install = true
  enabled      = true
  lite         = false
}


###############################################################################
# 404 Error Page
###############################################################################
# Cloudflare Pages will automatically serve a public/404.html file as the custom error page for 404 errors.
# No additional Terraform resource is required.
