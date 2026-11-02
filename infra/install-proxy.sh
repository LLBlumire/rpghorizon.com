#!/usr/bin/env bash
set -euo pipefail
(( EUID == 0 )) || { echo 'Run as root on the HTTPS proxy.' >&2; exit 1; }
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
readonly target=/etc/nginx/conf.d/rpghorizon.conf
readonly cert=/etc/letsencrypt/live/rpghorizon-com/fullchain.pem
openssl x509 -in "$cert" -noout -checkend 604800 >/dev/null
openssl x509 -in "$cert" -noout -checkhost rpghorizon.com >/dev/null
openssl x509 -in "$cert" -noout -checkhost www.rpghorizon.com >/dev/null
backup=$(mktemp -d)
committed=0
if [[ -e "$target" ]]; then cp -a "$target" "$backup/previous"; fi
restore() {
  if (( ! committed )); then
    if [[ -f "$backup/previous" ]]; then
      cp -a "$backup/previous" "$target"
    else
      rm -f -- "$target"
    fi
    nginx -t && systemctl reload nginx.service || true
  fi
  rm -rf -- "$backup"
}
trap restore EXIT
install -d -o www-data -g www-data -m 0750 /var/cache/nginx/rpghorizon
install -o root -g root -m 0644 nginx.conf "$target"
nginx -t
systemctl reload nginx.service
committed=1
