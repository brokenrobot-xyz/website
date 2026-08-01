# Cloudflare infrastructure

Terraform for everything the site needs on Cloudflare: the DNS zone, the Pages project, its
custom domains (`www` + apex), the proxied DNS records, the edge redirect that 301s the apex
to `www`, and — once the domain has transferred — the registrar settings. The edge security
headers are not managed here; they ship with the build in `public/_headers`.

## Applying

```sh
terraform init
terraform apply \
    -var "cloudflare_api_token=…" \
    -var "cloudflare_account_id=…" \
    -var "apex_domain_name=brokenrobot.xyz"
```

The API token needs `Zone:Edit`, `DNS:Edit`, `Zone Rulesets:Edit`, and `Cloudflare Pages:Edit`.

## Migration runbook (AWS → Cloudflare)

Every step is a `terraform apply` except step 4, which no provider can perform. The Route 53
zone holds nothing beyond the records `infra/aws` declares, so there is nothing to copy.

1. **Create the Cloudflare side** — `terraform apply` here. The zone comes up pending; note
   the `zone_name_servers` output.
2. **Delegate DNS** — `terraform apply` in `infra/aws` with
   `-var 'cloudflare_name_servers=["…", "…"]'` (the output from step 1). This adopts the
   registered domain into Terraform and switches its nameservers to Cloudflare; the zone
   turns active once the registry propagates. Adoption also enforces auto-renew and WHOIS
   privacy on.
3. **Verify** — `https://www.brokenrobot.xyz` serves from Pages (pretty URLs, the 404 page,
   the `_headers` security headers) and the apex 301s to `www`. Roll back by re-applying
   `infra/aws` with the nameserver variable empty.
4. **Transfer the registration** — the one step outside Terraform. Unlock with
   `-var domain_transfer_lock=false` on `infra/aws`, fetch the auth code
   (`aws route53domains retrieve-domain-auth-code --domain-name brokenrobot.xyz --region us-east-1`),
   start the transfer under Cloudflare → Domain Registration (one year's renewal at wholesale
   is charged and added to the expiry), and approve the confirmation email AWS sends. ICANN
   blocks transfers for 60 days after registration, a prior transfer, or a registrant contact
   change.
5. **Adopt the registrar settings** — once the transfer completes, `terraform apply` here
   with `-var manage_registrar_domain=true`.
6. **Tear down AWS** — after a bake period, `terraform destroy` in `infra/aws` (empty the S3
   buckets first), then delete the AWS deploy secrets and the `Production` environment from
   GitHub.
