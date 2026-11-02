#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
: "${S3_BUCKET:?Set S3_BUCKET to the RPG Horizon bucket}"
[[ "$S3_BUCKET" == rpghorizon-com-production-fr-par ]] || {
  echo 'Refusing to publish to an unexpected bucket.' >&2; exit 1;
}
test -f _site/index.html
test -f _site/feed.xml
export AWS_DEFAULT_REGION=fr-par AWS_EC2_METADATA_DISABLED=true
readonly endpoint=https://s3.fr-par.scw.cloud
# Upload assets first. Retain older assets for readers with cached documents.
aws --endpoint-url "$endpoint" s3 sync _site/ "s3://${S3_BUCKET}/" \
  --exclude '*.html' --exclude '*.xml' \
  --cache-control 'public, max-age=3600, stale-while-revalidate=86400' --only-show-errors
# Only obsolete documents are deleted; object versioning retains recovery copies.
aws --endpoint-url "$endpoint" s3 sync _site/ "s3://${S3_BUCKET}/" \
  --delete --exclude '*' --include '*.html' \
  --content-type 'text/html; charset=utf-8' \
  --cache-control 'public, max-age=60, must-revalidate' --only-show-errors
aws --endpoint-url "$endpoint" s3 sync _site/ "s3://${S3_BUCKET}/" \
  --exclude '*' --include '*.xml' \
  --content-type 'application/atom+xml; charset=utf-8' \
  --cache-control 'public, max-age=60, must-revalidate' --only-show-errors
