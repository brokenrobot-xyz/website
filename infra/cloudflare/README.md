# Cloudflare infrastructure

Terraform for everything the site needs on Cloudflare: the DNS zone, the Pages project, its
custom domains (`www` + apex), the proxied DNS records, and the edge redirect that 301s the
apex to `www`. The edge security headers are not managed here — they ship with the build in
`public/_headers`.

## Applying

```sh
terraform init
terraform apply \
    -var "cloudflare_api_token=…" \
    -var "cloudflare_account_id=…" \
    -var "apex_domain_name=brokenrobot.xyz"
```

The API token needs `Zone:Edit`, `DNS:Edit`, `Zone Rulesets:Edit`, and `Cloudflare Pages:Edit`.
If the zone or Pages project already exists in the dashboard, import instead of recreating:

```sh
terraform import 'module.website.cloudflare_zone.website' '<zone_id>'
terraform import 'module.website.cloudflare_pages_project.website' '<account_id>/brokenrobot-xyz'
```

## Migration runbook (Route 53 → Cloudflare)

One-time steps, in order. Terraform covers the website records only — any other records living
in the Route 53 hosted zone (MX, TXT, verification records) must be recreated in the Cloudflare
zone by hand before the nameserver switch.

1. `terraform apply` — creates the zone (pending), records, custom domains, and redirect.
2. Copy any non-website records from Route 53 into the Cloudflare zone.
3. In the Route 53 **registered domains** console, set the nameservers to the
   `zone_name_servers` output. The zone turns active once the registry updates.
4. Verify `https://www.brokenrobot.xyz` serves from Pages (pretty URLs, the 404 page, the
   security headers from `_headers`) and that the apex 301s to `www`.
5. Transfer the registration: disable the transfer lock at Route 53, request the auth code,
   and start the transfer under Cloudflare → Domain Registration. Approve AWS's confirmation
   email to skip the waiting period.
6. After a bake period, tear down `infra/aws` (`terraform destroy`; empty the S3 buckets
   first) and delete the AWS deploy secrets and the `Production` environment from GitHub.
