# Cloudflare infrastructure

Terraform for everything the site needs on Cloudflare: the DNS zone, the Pages project, its
custom domains (`www` + apex), the proxied DNS records, the edge redirect that 301s the apex
to `www`, and — once the domain has transferred — the registrar settings. The edge security
headers are not managed here; they ship with the build in `public/_headers`.

## Applying

Both stacks run in Terraform Cloud, so applying means merging to `main` and letting the
workspace run; variables are workspace variables, not CLI flags. The API token behind the
workspace needs `Zone:Edit`, `DNS:Edit`, `Zone Rulesets:Edit`, and `Cloudflare Pages:Edit`.

| Workspace variable        | Default | Meaning                                                        |
| ------------------------- | ------- | -------------------------------------------------------------- |
| `cloudflare_api_token`    | —       | Cloudflare API token (sensitive)                               |
| `cloudflare_account_id`   | —       | Cloudflare account (sensitive)                                 |
| `apex_domain_name`        | —       | `brokenrobot.xyz`                                              |
| `manage_registrar_domain` | `false` | Set once the registrar transfer has completed (runbook step 5) |

## Migration runbook (AWS → Cloudflare)

Each phase is a Terraform Cloud run, driven by workspace variables; only step 4 happens
outside Terraform. The Route 53 zone holds nothing beyond the records `infra/aws` declares,
so there is nothing to copy.

1. **Merge the migration change** — the merge lets Terraform Cloud apply this stack: the zone
   comes up pending, and the Pages custom domains stay pending until DNS delegates. The
   `infra/aws` workspace no-ops because `cloudflare_name_servers` defaults to empty. Note the
   `zone_name_servers` output of this workspace and the `route53_zone_name_servers` output of
   the AWS workspace (the rollback values). The merge also removes the AWS deploy job, so the
   CloudFront copy stops receiving content — finish step 2 promptly.
2. **Delegate DNS** — on the `infra/aws` workspace, set the `cloudflare_name_servers`
   variable to the `zone_name_servers` output from step 1 and queue a run. This adopts the
   registered domain into Terraform and switches its nameservers to Cloudflare; the zone
   turns active once the registry propagates. Adoption also enforces auto-renew and WHOIS
   privacy on.
3. **Verify** — `https://www.brokenrobot.xyz` serves from Pages (pretty URLs, the 404 page,
   the `_headers` security headers) and the apex 301s to `www`. To roll back, set
   `cloudflare_name_servers` to the `route53_zone_name_servers` values and re-run — do not
   empty the variable, which only forgets the domain resource and leaves the nameservers on
   Cloudflare.
4. **Transfer the registration** — the one step outside Terraform. Set
   `domain_transfer_lock` to `false` on the `infra/aws` workspace and run, fetch the auth
   code (`aws route53domains retrieve-domain-auth-code --domain-name brokenrobot.xyz --region us-east-1`),
   start the transfer under Cloudflare → Domain Registration (one year's renewal at wholesale
   is charged and added to the expiry), and approve the confirmation email AWS sends. ICANN
   blocks transfers for 60 days after registration, a prior transfer, or a registrant contact
   change.
5. **Adopt the registrar settings** — once the transfer completes, set
   `manage_registrar_domain` to `true` on this workspace and queue a run.
6. **Tear down AWS** — after a bake period, queue a destroy run on the `infra/aws` workspace
   (empty the S3 buckets first), then delete the AWS deploy secrets and the `Production`
   environment from GitHub, and remove `infra/aws` from the repository.
