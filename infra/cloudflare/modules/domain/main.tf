###############################################################################
# Cloudflare Zone (domain)
###############################################################################

data "cloudflare_zone" "domain_zone" {
  filter = {
    name = var.apex_domain_name
  }
}

###############################################################################
# Cloudflare Zone (domain settings)
###############################################################################

data "cloudflare_zone_dns_settings" "domain_zone_dns_settings" {
  zone_id = data.cloudflare_zone.domain_zone.zone_id
}

###############################################################################
# Cloudflare Zone (DNSSEC)
###############################################################################

resource "cloudflare_zone_dnssec" "domain_dnssec" {
  zone_id = data.cloudflare_zone.domain_zone.zone_id
  status  = "active"
}

###############################################################################
# Cloudflare Zone (security and performance)
###############################################################################
#
# These apply to the whole zone, not to any one site on it. The two rulesets in
# particular are entry points, and Cloudflare permits only one per phase per
# zone -- a second site defining its own would fail to create. They live here so
# that the zone has exactly one owner.

# 301 every HTTP request -> HTTPS
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = data.cloudflare_zone.domain_zone.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# Automatic HTTPS rewrites
resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  zone_id    = data.cloudflare_zone.domain_zone.zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

# Enable TLS 1.3 between Cloudflare and visitors
resource "cloudflare_zone_setting" "tls13" {
  zone_id    = data.cloudflare_zone.domain_zone.zone_id
  setting_id = "tls_1_3"
  value      = "on"
}

# Refuse the deprecated TLS versions
resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = data.cloudflare_zone.domain_zone.zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Strict end-to-end SSL mode (visitor -> CF -> origin)
resource "cloudflare_zone_setting" "ssl_mode" {
  zone_id    = data.cloudflare_zone.domain_zone.zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Security and performance response headers
resource "cloudflare_ruleset" "security_and_performance_response_headers" {
  zone_id = data.cloudflare_zone.domain_zone.zone_id
  name    = "Static security and performance headers"
  kind    = "zone"
  phase   = "http_response_headers_transform"

  rules = [
    {
      enabled     = true
      description = "Static response headers"
      expression  = "true"
      action      = "rewrite"

      action_parameters = {
        headers = {
          # No `preload` token: see the README. The zone is not on the preload
          # list, and getting on it is a near-irreversible commitment for every
          # current and future subdomain.
          "Strict-Transport-Security" = {
            operation = "set"
            value     = "max-age=31536000; includeSubDomains"
          }
          "X-Content-Type-Options" = {
            operation = "set"
            value     = "nosniff"
          }
          "X-Frame-Options" = {
            operation = "set"
            value     = "DENY"
          }
          "Permissions-Policy" = {
            operation = "set"
            value     = "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), fullscreen=(self), magnetometer=(), microphone=(), midi=(), payment=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), speaker-selection=(), usb=(), web-share=(), xr-spatial-tracking=()"
          }
          "Referrer-Policy" = {
            operation = "set"
            value     = "same-origin"
          }
          # script-src covers the Web Analytics beacon; because it is
          # auto-installed the beacon posts to the same-origin /cdn-cgi/rum,
          # hence connect-src 'self' rather than the Cloudflare host.
          # style-src allows the inline styles in index.html and 404.html.
          "Content-Security-Policy" = {
            operation = "set"
            value     = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; script-src https://static.cloudflareinsights.com; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
          }
        }
      }
    }
  ]
}

# Edge caching: cache everything
resource "cloudflare_ruleset" "cache_everything" {
  zone_id = data.cloudflare_zone.domain_zone.zone_id
  name    = "Cache everything at the edge"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules = [
    {
      enabled     = true
      description = "Cache everything at the edge"
      expression  = "true"
      action      = "set_cache_settings"

      action_parameters = {
        cache = true
        edge_ttl = {
          mode    = "override_origin"
          default = 31536000
        }
        browser_ttl = {
          mode    = "override_origin"
          default = 14400
        }
        origin_cache_control = false
      }
    }
  ]
}
