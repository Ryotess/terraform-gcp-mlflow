#!/usr/bin/env bash
set -euo pipefail

SERVICE_ACCOUNT_EMAIL="${1:?service account email is required}"

: "${GCP_WIF_PROVIDER:?GCP_WIF_PROVIDER is required}"
: "${GITLAB_OIDC_TOKEN:?GITLAB_OIDC_TOKEN is required}"

if [[ ! "${GCP_WIF_PROVIDER}" =~ ^projects/[0-9]+/locations/global/workloadIdentityPools/[^/]+/providers/[^/]+$ ]]; then
  echo "GCP_WIF_PROVIDER must be in the format: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID" >&2
  exit 1
fi

WORKDIR="${PWD}"
mkdir -p "${WORKDIR}/.gcp/config"

OIDC_TOKEN_FILE="${WORKDIR}/.gcp/gitlab-oidc-token"
CRED_FILE="${WORKDIR}/.gcp/gcp-wif-cred.json"

printf '%s' "${GITLAB_OIDC_TOKEN}" > "${OIDC_TOKEN_FILE}"

gcloud iam workload-identity-pools create-cred-config "${GCP_WIF_PROVIDER}" \
  --service-account="${SERVICE_ACCOUNT_EMAIL}" \
  --credential-source-file="${OIDC_TOKEN_FILE}" \
  --output-file="${CRED_FILE}"

export CLOUDSDK_CONFIG="${WORKDIR}/.gcp/config"
export GOOGLE_APPLICATION_CREDENTIALS="${CRED_FILE}"
export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="${CRED_FILE}"

if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
  gcloud --quiet config set project "${GCP_PROJECT_ID}" >/dev/null
fi
