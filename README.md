# RPG Horizon

The Eleventy articles site at <https://rpghorizon.com>. Source content lives in
`src/`; the generated website is `_site/`.

## Build and publish

Enter the pinned Nix development shell, then run:

```sh
nix develop -c scripts/build.sh
nix develop -c yarn serve --host=0.0.0.0
```

On rdev, put build commands and development-shell initialization behind
`/home/llblumire/.local/bin/build-gate`. Run persistent preview servers separately
after a gated build. The default Eleventy preview port is 8080.

Pushing `main` runs `.github/workflows/deploy.yml`. The `production` GitHub
environment holds `SCW_ACCESS_KEY_ID` (the publisher access key with `@PROJECT_ID`
appended) and `SCW_SECRET_ACCESS_KEY`. They belong to the dedicated publisher
application, which has Object Storage access only in the `rpghorizon` Project.
Credentials stay outside source control and OpenTofu state.

The publisher uploads assets first, then HTML and the Atom feed. Previous assets
are retained for clients holding earlier documents; bucket versioning preserves
replaced or deleted objects. HTML and feed cache lifetimes are 60 seconds and
asset lifetimes are one hour. Publishing does not modify DNS or server config.

## Hosting ownership

`infra/main.tf` owns the independent `rpghorizon` Scaleway Project, its versioned
`rpghorizon-com-production-fr-par` bucket, publisher identity/policy, and the apex
and `www` Porkbun records. NRO resources, `thebar.rpghorizon.com`, mail and TXT
records are outside this state.

The bucket ACL is private. Its policy permits public object reads for the website
without public bucket listing; only the publisher and account owner can write.
The public website bucket must contain generated public files only.

The shared server `nro-prod-paris` (`51.159.110.43`) runs nginx as the HTTPS proxy.
`infra/nginx.conf` maps only the two RPG Horizon hostnames, uses an independent
certificate and a bounded 512 MB cache, verifies the bucket origin's TLS
certificate, and redirects `www` to the apex with the path and query preserved.
HTML is not cached by nginx. The site shares this server's availability with NRO,
but no NRO runtime, publisher credential, bucket or certificate is needed to
publish its content.

## Infrastructure operations

The private, versioned `personal-websites-opentofu-state-fr-par` bucket holds the
remote state under `rpghorizon/infrastructure.tfstate`. This bootstrap bucket
lives in the account's `default` Project
(`78e60b8f-816f-472d-8c71-3ee28137a9d4`) and is deliberately outside the website
state so an apply cannot delete its own backend. Native S3 state locking is on.

The operator's local Scaleway configuration supplies the account credentials.
An ignored, mode-0600 `.env.local` supplies `PORKBUN_API_KEY` and
`PORKBUN_SECRET_API_KEY`; API access must be enabled for `rpghorizon.com`.
`scripts/with-scaleway.sh` selects the state Project explicitly for S3 requests.
All durable infrastructure resources have destruction protection.

```sh
nix develop -c scripts/tofu.sh init
nix develop -c scripts/tofu.sh plan -out=/private/path/production.tfplan
nix develop -c scripts/tofu.sh show /private/path/production.tfplan
# Apply only after reviewing the saved plan.
nix develop -c scripts/tofu.sh apply /private/path/production.tfplan
```

Before the initial DNS cutover, use `-var=cutover=false` when planning. This imports
the existing two records and retains their Vercel destinations while storage,
publishing and HTTPS are staged. The final `cutover=true` plan changes only those
two records. To roll back during the Vercel retention period, review and apply a
saved plan with `-var=cutover=false`.

## HTTPS certificate and proxy

On the proxy, `/usr/local/sbin/certbot-rpghorizon-dns` is installed from
`infra/certbot-rpghorizon-dns`. Its root-owned mode-0600 credentials are at
`/etc/letsencrypt/rpghorizon-porkbun.json`, containing `apikey` and `secretapikey`.
The hook accepts only `rpghorizon.com` and `www.rpghorizon.com`, verifies DNS
propagation, and deletes only the exact TXT records it created.

```sh
sudo certbot certonly --non-interactive --agree-tos --manual \
  --preferred-challenges dns \
  --manual-auth-hook '/usr/local/sbin/certbot-rpghorizon-dns auth' \
  --manual-cleanup-hook '/usr/local/sbin/certbot-rpghorizon-dns cleanup' \
  --cert-name rpghorizon-com --keep-until-expiring \
  -d rpghorizon.com -d www.rpghorizon.com
sudo bash infra/install-proxy.sh
sudo certbot renew --cert-name rpghorizon-com --dry-run --run-deploy-hooks --no-random-sleep-on-renew
```

`certbot.timer` handles renewal; the existing nginx deploy hook validates and
reloads nginx. The installer validates the certificate and nginx config, restores
the previous site config on failure, and reloads nginx without restarting it.

Before DNS cutover, test HTTPS with
`curl --resolve rpghorizon.com:443:51.159.110.43 https://rpghorizon.com/`, plus article
URLs, CSS/images, `/feed.xml`, missing paths, HTTP and `www` redirects. Check NRO's
API readiness and existing static sites after the nginx reload. Retain the Vercel
project until public DNS and content checks complete; deleting it is separate
from changing the website DNS.
