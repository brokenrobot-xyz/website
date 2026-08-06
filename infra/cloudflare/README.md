# Cloudflare infrastructure

Operational notes for this stack. These record the reasoning and the traps that the
Terraform files themselves cannot express — read this before changing redirects,
caching, or API tokens.

## Zone rules cannot touch `*.pages.dev`

`brokenrobot-xyz.pages.dev` is served by Cloudflare Pages **outside** the `brokenrobot.xyz`
zone. Zone-level rulesets — the apex→www redirect, the response headers, the cache
rule — are invisible to it. Anything that has to act on the Pages hostname must be
**account-level**.

That is why the pages.dev→www redirect is a Bulk Redirect (`cloudflare_list` +
`cloudflare_list_item` + an account-level `cloudflare_ruleset`) rather than another
entry in the zone's redirect ruleset.

`include_subdomains = true` on the list item is load-bearing: every
`wrangler pages deploy` mints a `<hash>.brokenrobot-xyz.pages.dev` URL, so closing only
the base hostname would leave those reachable.

## Only one entry point ruleset exists per phase, per account

Cloudflare allows at most one _root_ (entry point) ruleset per phase at the account
level. Creating a second returns:

```
20217 'root' is not a valid value for kind because exceeded maximum number of
root rulesets for phase http_request_redirect
```

Every Bulk Redirect Rule in the account — for every site — lands in that one ruleset,
and a Terraform `cloudflare_ruleset` owns its `rules` list outright: the API `PUT`
replaces the whole array, so rules it does not declare are deleted. One ruleset that
only one stack can own does not fit a module instantiated once per site.

So the two halves are split by who can own them:

|                                    | Owner                            |
| ---------------------------------- | -------------------------------- |
| Bulk Redirect **Rule** (all sites) | Created by hand in the dashboard |
| Bulk Redirect **List** + items     | This module, one List per site   |

Lists are not singletons, so each site keeps its own in Terraform. Only the Rules are
manual, and only because they share the ruleset.

Consequences:

- **A new site needs one manual step.** Terraform creates its List; you then add a
  Rule pointing at that List by hand. Applying before the Rule exists is harmless —
  the List simply redirects nothing until a Rule references it.
- **Never reintroduce a `cloudflare_ruleset` for this phase.** It will fail with 20217
  if a Rule already exists, and silently delete every other site's Rule if it does not.
- **The dashboard shows rules, not rulesets.** An empty entry point renders as an
  empty Bulk Redirects page — indistinguishable from no ruleset at all. Only the API
  can tell them apart:

    ```
    curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/rulesets/phases/http_request_redirect/entrypoint"
    ```

## Edge caching hides deployments

The zone caches everything with a one-year edge TTL and `origin_cache_control = false`,
so Cloudflare ignores what Pages says about caching. Without intervention **a deploy is
invisible on the custom domain** — `wrangler` reports success while the edge keeps
serving the old copy. Cloudflare documents this for Pages custom domains.

`deploy.yml` therefore purges the zone after every deployment. That purge is what makes
the long TTL safe; the two are a pair, and removing one without the other reintroduces
the bug.

The purge clears the **edge** only. `browser_ttl` is a separate 4 hour override, so a
visitor who loaded the site before a deploy can keep serving it from their own cache for
up to four hours afterwards, purge or no purge. That window is accepted deliberately —
for a site that changes a few times a year it costs nothing — but it does mean "purged"
is not the same as "everyone sees the new version".

For the same reason the deploy job queues rather than cancels (`cancel-in-progress:
false`). A run stopped between the `wrangler` upload and the purge would leave the edge
pinned to the previous deployment for up to a year.

Diagnosing staleness: a large `age` header with an unchanged `last-modified` means the
purge is not running.

```
curl -sI https://www.brokenrobot.xyz/ | grep -iE '^(age|cf-cache-status|last-modified)'
```

A per-file-type cache split (long for images, short for the rest) was considered and
rejected: the site is static, so nothing changes between deploys, and the purge already
invalidates everything. The usual "HTML short, assets long" pattern depends on
content-hashed filenames, which `public/` does not use.

## API token permissions are finely split

Related-looking operations need separate grants, and a missing one fails late:

| Operation                    | Permission                  | Scope   |
| ---------------------------- | --------------------------- | ------- |
| Bulk Redirect List and items | Account Filter Lists → Edit | Account |
| Cache purge from CI          | Zone → Cache Purge → Purge  | Zone    |
| Pages deploy                 | Cloudflare Pages → Edit     | Account |

The Terraform token deliberately does **not** carry _Bulk URL Redirects → Edit_. That
grant covers the account redirect ruleset, which Terraform no longer manages (see
above), and withholding it makes the split enforceable rather than merely documented —
a stray `cloudflare_ruleset` fails on permissions instead of deleting another site's
Bulk Redirect Rule.

Reading the failure:

- **403** — authenticated, insufficient permission.
- **400** — authenticated and permitted, rejected on semantics (this is what error
  20217 above looks like; the token was fine).
- **401** — Cloudflare returns this, not 403, when a token has no access to the
  _resource_ at all. A Pages-only token hitting a zone endpoint gets 401 with
  `code: 10000 Authentication error`. Check the token's **resource scope**, not just
  its permission list.

## Terraform Cloud runs race the deploy workflow

`cloudflare_pages_project` exposes `latest_deployment` and `canonical_deployment`, both
computed, both mutating as a deployment moves through queued → building → success. If a
Pages deploy is in flight while an apply runs, Terraform plans against one value and
applies against another:

```
Provider produced inconsistent result after apply
.latest_deployment: inconsistent values for sensitive attribute
```

This is a scheduling problem, not drift — the same apply re-run with no deploy in flight
succeeds with no changes. It is _not_ the perpetual-diff bug reported upstream
(cloudflare/terraform-provider-cloudflare#5928); that would still show a diff when idle.

Both sides are now path-scoped so the two never fire on the same push: the Terraform
Cloud workspace only triggers on `infra/cloudflare/`, and `deploy.yml` only triggers on
`public/`. Scoping the workspace alone would not have been enough — `deploy.yml`
previously ran on Pipeline's success, and Pipeline runs on every push, so an infra-only
push still deployed and still raced.

Keep the two path filters disjoint. A single push touching both trees brings the race
back.

## Zone-wide configuration belongs to the `domain` module

The zone settings (SSL mode, TLS floor, HTTPS redirection) and the two zone rulesets
(response headers, cache) live in `modules/domain`, not in `modules/simple-static-website`,
even though the website is the only thing that benefits from them today.

The reason is the same entry-point constraint as above, applied at zone scope: one
ruleset per phase, per zone. Both zone rulesets use `expression = "true"`, so they match
every hostname in the zone regardless of which site is being served. Had they stayed in
the website module, adding a second site would have meant a second module instance
trying to create a ruleset that already exists.

The apex→www redirect is the exception and stays with the website: it exists to point at
`www`, which is a property of the site rather than of the zone. If a second site is ever
added, that redirect ruleset needs revisiting first.

## HSTS is served without `preload`

The `Strict-Transport-Security` header carries `max-age` and `includeSubDomains` but
deliberately **not** `preload`. The domain is not on the browser preload list and the
token alone does nothing — submission is a separate manual step.

That step was declined on purpose. Preloading is enforced from inside the browser binary,
removal rides browser release trains for months, and `includeSubDomains` would bind every
future subdomain to valid HTTPS with no click-through on failure. For a static site with
no login and no user data, the only gain is the very first request from a browser that
has never visited.

If it is ever reconsidered, note the domain is currently **ineligible**: preload requires
port 80 to redirect to HTTPS on the _same_ host first, and `http://<apex>` currently
redirects straight to `https://www.<apex>` because the apex→www rule matches before
`always_use_https` runs. Adding `and ssl` to that rule's expression would fix the chain
at the cost of one extra hop.

## Zone settings cannot be destroyed

`cloudflare_zone_setting` resources always exist on the zone; only their value can
change. Terraform warns about this on create. Removing one from the configuration
leaves the setting at its last applied value rather than reverting it — for example
`min_tls_version` stays at `1.2` and must be changed back by hand.
