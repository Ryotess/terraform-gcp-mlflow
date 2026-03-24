#!/usr/bin/env bash
set -euo pipefail

: "${DEPLOY_ENV:?DEPLOY_ENV is required}"
: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
: "${GCP_REGION:?GCP_REGION is required}"
: "${GCP_TERRAFORM_SA:?GCP_TERRAFORM_SA is required}"
: "${GCP_ARTIFACT_PUSH_SA:?GCP_ARTIFACT_PUSH_SA is required}"
: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
: "${TF_STATE_PREFIX:?TF_STATE_PREFIX is required}"

CONFIRM_VALUE="${DESTROY_CONFIRM:-}"
EXPECTED_CONFIRM="destroy-${DEPLOY_ENV}"

if [[ "${CONFIRM_VALUE}" != "${EXPECTED_CONFIRM}" ]]; then
  echo "Refusing to destroy ${DEPLOY_ENV}. Set DESTROY_CONFIRM=${EXPECTED_CONFIRM} when running the manual job." >&2
  exit 1
fi

TF_ROOT="${TF_ROOT:-infra}"
ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-mlflow}"
IMAGE_NAME="${IMAGE_NAME:-mlflow}"
PLACEHOLDER_IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY}/${IMAGE_NAME}:destroy-placeholder"
MLFLOW_IMAGE="${TF_VAR_mlflow_image:-${PLACEHOLDER_IMAGE}}"

source scripts/ci/setup_gcp_wif.sh "${GCP_TERRAFORM_SA}"

cd "${TF_ROOT}"
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${TF_STATE_PREFIX}/${DEPLOY_ENV}"

terraform destroy \
  -var="project_id=${GCP_PROJECT_ID}" \
  -var="region=${GCP_REGION}" \
  -var="mlflow_image=${MLFLOW_IMAGE}" \
  -var="artifact_bucket_force_destroy=true" \
  -var="deletion_protection=false" \
  -var-file="environments/${DEPLOY_ENV}.tfvars"
cd - >/dev/null

source scripts/ci/setup_gcp_wif.sh "${GCP_ARTIFACT_PUSH_SA}"

if gcloud artifacts repositories describe "${ARTIFACT_REPOSITORY}" \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}" >/dev/null 2>&1; then
  gcloud artifacts repositories delete "${ARTIFACT_REPOSITORY}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}" \
    --quiet
fi
