variable "s3_bucket_website" {
  type = object({
    id                   = string
    bucket               = string
    regional_domain_name = string
  })
  nullable = false
}

variable "s3_bucket_logs" {
  type = object({
    bucket_domain_name = string
  })
  nullable = false
}

variable "aws_acm_certificate_arn" {
  type     = string
  nullable = false
}

variable "aws_cloudfront_function_viewer_request_arn" {
  type     = string
  nullable = false
}

# Edge half of a two-layer Content-Security-Policy. Astro emits a <meta> policy into every page
# carrying per-build script/style hashes; this header carries what a <meta> element cannot —
# frame-ancestors — and also covers non-HTML responses and error pages. Browsers enforce both, so a
# resource must satisfy each. Keep this in sync with `nginx.conf` and `server.headers` in
# `astro.config.ts` (the latter is what `astro preview`, and so the Playwright suite, serves).
#
# 'unsafe-inline' on script-src/style-src is deliberate: a static header cannot carry the per-page
# hashes, so without it this layer would block the inline scripts and styles the <meta> policy has
# already vetted. The <meta> policy is the strict one.
variable "content_security_policy" {
  type     = string
  default  = "default-src 'none'; child-src 'none'; connect-src 'self'; font-src 'self'; frame-src 'none'; img-src 'self'; manifest-src 'none'; media-src 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; script-src-attr 'none'; style-src 'self' 'unsafe-inline'; style-src-attr 'none'; worker-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none';"
  nullable = false
}

variable "aliases" {
  type     = list(string)
  default  = []
  nullable = false
}

variable "tags" {
  type     = map(string)
  default  = {}
  nullable = false
}
