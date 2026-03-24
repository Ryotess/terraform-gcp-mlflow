#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ENV="${1:-${DEPLOY_ENV:-dev}}"
mkdir -p .tmp

case "${DEPLOY_ENV}" in
  dev)
    : "${GCP_PROJECT_ID_DEV:?GCP_PROJECT_ID_DEV is required}"
    GCP_PROJECT_ID="${GCP_PROJECT_ID_DEV}"
    ;;
  stg)
    : "${GCP_PROJECT_ID_STG:?GCP_PROJECT_ID_STG is required}"
    GCP_PROJECT_ID="${GCP_PROJECT_ID_STG}"
    ;;
  prd)
    : "${GCP_PROJECT_ID_PRD:?GCP_PROJECT_ID_PRD is required}"
    GCP_PROJECT_ID="${GCP_PROJECT_ID_PRD}"
    ;;
  *)
    echo "Unsupported DEPLOY_ENV: ${DEPLOY_ENV}" >&2
    exit 1
    ;;
esac

: "${GCP_REGION:?GCP_REGION is required}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${TF_STATE_PREFIX:?TF_STATE_PREFIX is required}"

cat > .tmp/deploy.env <<EOF
export DEPLOY_ENV=${DEPLOY_ENV}
export GCP_PROJECT_ID=${GCP_PROJECT_ID}
export GCP_REGION=${GCP_REGION}
export TF_STATE_BUCKET=${TF_STATE_BUCKET}
export TF_STATE_PREFIX=${TF_STATE_PREFIX}
EOF

