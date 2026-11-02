#!/usr/bin/env bash
set -euo pipefail
# Operator wrapper; credentials stay in the local Scaleway profile and process env.
SCW_ACCESS_KEY="${SCW_ACCESS_KEY:-$(scw config get access-key)}"
SCW_SECRET_KEY="${SCW_SECRET_KEY:-$(scw config get secret-key)}"
export SCW_ACCESS_KEY SCW_SECRET_KEY
export AWS_ACCESS_KEY_ID="${SCW_ACCESS_KEY}@${S3_PROJECT_ID:-78e60b8f-816f-472d-8c71-3ee28137a9d4}"
export AWS_SECRET_ACCESS_KEY="$SCW_SECRET_KEY"
export AWS_DEFAULT_REGION=fr-par AWS_EC2_METADATA_DISABLED=true
exec "$@"
