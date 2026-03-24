#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
: "${GCP_REGION:?GCP_REGION is required}"

ARTIFACT_REPOSITORY="${ARTIFACT_REPOSITORY:-mlflow}"
IMAGE_NAME="${IMAGE_NAME:-mlflow}"
IMAGE_TAG="${IMAGE_TAG:-${CI_COMMIT_SHA:-manual}}"

REPOSITORY_HOST="${GCP_REGION}-docker.pkg.dev"
IMAGE_URI="${REPOSITORY_HOST}/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

gcloud artifacts repositories describe "${ARTIFACT_REPOSITORY}" \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}" >/dev/null 2>&1 || \
gcloud artifacts repositories create "${ARTIFACT_REPOSITORY}" \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}" \
  --repository-format=docker \
  --description="MLflow container images"

gcloud builds submit --suppress-logs --tag "${IMAGE_URI}" .

DIGEST="$(gcloud artifacts docker images describe "${IMAGE_URI}" --format='value(image_summary.digest)')"

mkdir -p .tmp
cat > .tmp/image.env <<EOF
TF_VAR_mlflow_image=${REPOSITORY_HOST}/${GCP_PROJECT_ID}/${ARTIFACT_REPOSITORY}/${IMAGE_NAME}@${DIGEST}
EOF
