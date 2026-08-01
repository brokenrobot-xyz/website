###############################################################################
# Zone
###############################################################################
# The zone must be active (nameservers switched at the registrar) before the
# Pages custom domains and the redirect rule below can serve traffic.

resource "cloudflare_zone" "website" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.apex_domain_name
  type = "full"
}

###############################################################################
# Cloudflare Pages
###############################################################################

resource "cloudflare_pages_project" "website" {
  account_id        = var.cloudflare_account_id
  name              = replace(var.apex_domain_name, ".", "-")
  production_branch = "main"
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.website.name
  name         = "www.${var.apex_domain_name}"
}

resource "cloudflare_pages_domain" "apex" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.website.name
  name         = var.apex_domain_name
}

###############################################################################
# DNS
###############################################################################
# Both records are proxied CNAMEs to the project's pages.dev hostname; the
# apex CNAME is flattened by Cloudflare automatically.

resource "cloudflare_dns_record" "www" {
  zone_id = cloudflare_zone.website.id
  name    = "www.${var.apex_domain_name}"
  type    = "CNAME"
  content = cloudflare_pages_project.website.subdomain
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "apex" {
  zone_id = cloudflare_zone.website.id
  name    = var.apex_domain_name
  type    = "CNAME"
  content = cloudflare_pages_project.website.subdomain
  proxied = true
  ttl     = 1
}

###############################################################################
# Redirect - apex to www
###############################################################################
# Runs at the edge before the request reaches Pages, replacing the CloudFront
# viewer-request function's apex redirect. The index.html rewrite that function
# also did is native Pages behaviour and needs no rule.

resource "cloudflare_ruleset" "redirect_apex_to_www" {
  zone_id = cloudflare_zone.website.id
  name    = "Redirect apex to www"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "redirect_apex_to_www"
      description = "301 apex requests to www, preserving path and query"
      expression  = "(http.host eq \"${var.apex_domain_name}\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://www.${var.apex_domain_name}\", http.request.uri.path)"
          }
        }
      }
    }
  ]
}

###############################################################################
# 404 Error Page
###############################################################################
# Cloudflare Pages will automatically serve a public/404.html file as the custom error page for 404 errors.
# No additional Terraform resource is required.
