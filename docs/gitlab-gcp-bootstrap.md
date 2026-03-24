# GitLab OIDC and GCP Bootstrap Guide

This guide bootstraps the GCP prerequisites for this repository's GitLab CI pipeline:
- Workload Identity Federation (WIF) for GitLab OIDC
- Two service accounts:
  - `GCP_TERRAFORM_SA`
  - `GCP_ARTIFACT_PUSH_SA`
- A GCS bucket for Terraform remote state

## Prerequisites
- `gcloud` is installed and authenticated
- You have permission to create IAM resources, service accounts, and storage buckets in the target GCP project
- Your GitLab OIDC metadata endpoint (`https://<gitlab-host>/.well-known/openid-configuration`) is reachable anonymously
- The JWKS URL referenced by that metadata is reachable anonymously

## 1. Set Variables
Replace `your-gcp-project-id` before running the commands.

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

export GITLAB_HOST="gitlab.example.com"
export GITLAB_ISSUER="https://${GITLAB_HOST}/"
export GITLAB_AUDIENCE="https://${GITLAB_HOST}"
export GITLAB_PROJECT_PATH="your-group/terraform-gcp-mlflow"

export POOL_ID="gitlab-mlflow-pool"
export PROVIDER_ID="gitlab-oidc-provider"
export TF_SA_NAME="mlflow-terraform-sa"
export AR_SA_NAME="mlflow-artifact-push-sa"
export TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
export AR_SA_EMAIL="${AR_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
export TF_STATE_BUCKET="${PROJECT_ID}-mlflow-tfstate"
```

## 2. Set the Active Project
```bash
gcloud config set project "$PROJECT_ID"
```

## 3. Enable Required APIs
```bash
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  serviceusage.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com
```

## 4. Create the Workload Identity Pool
```bash
gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitLab CI pool"
```

## 5. Create the OIDC Provider
This provider is restricted to the GitLab project path from `GITLAB_PROJECT_PATH`.

```bash
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" \
  --display-name="GitLab OIDC provider" \
  --issuer-uri="$GITLAB_ISSUER" \
  --allowed-audiences="$GITLAB_AUDIENCE" \
  --attribute-mapping="google.subject=assertion.sub,attribute.project_path=assertion.project_path,attribute.namespace_path=assertion.namespace_path,attribute.ref=assertion.ref,attribute.ref_type=assertion.ref_type,attribute.ref_protected=assertion.ref_protected,attribute.user_login=assertion.user_login" \
  --attribute-condition="assertion.project_path=='${GITLAB_PROJECT_PATH}'"
```

## 6. Create the Service Accounts
```bash
gcloud iam service-accounts create "$TF_SA_NAME" \
  --display-name="MLflow Terraform SA"

gcloud iam service-accounts create "$AR_SA_NAME" \
  --display-name="MLflow Artifact Push SA"
```

## 7. Grant Roles to the Terraform Service Account
This is a pragmatic bootstrap role set for the current Terraform in this repository. Tighten it later if needed.

```bash
for ROLE in \
  roles/serviceusage.serviceUsageAdmin \
  roles/run.admin \
  roles/cloudsql.admin \
  roles/artifactregistry.reader \
  roles/storage.admin \
  roles/secretmanager.admin \
  roles/compute.networkAdmin \
  roles/servicenetworking.networksAdmin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountUser \
  roles/resourcemanager.projectIamAdmin
do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${TF_SA_EMAIL}" \
    --role="$ROLE"
done
```


## 8. Grant Roles to the Artifact Push Service Account
This repository's CI bootstrap step creates the Artifact Registry repository if it does not already exist and submits builds to Cloud Build.

Practical note:
- The narrower role combination was not sufficient in this environment.
- The role set below reflects the permissions that actually worked end to end for the artifact push path.

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/cloudbuild.builds.viewer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/serviceusage.serviceUsageConsumer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${AR_SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"
```

Note:
- In your current environment, this broader role set is the known-good baseline for `GCP_ARTIFACT_PUSH_SA`.
- You can tighten it later once the delivery path is stable.
- The CI pipeline uses `gcloud builds submit --suppress-logs` so the caller does not need broad Viewer access just to stream logs from the default Cloud Build logs bucket.

## 9. Allow GitLab to Impersonate Both Service Accounts

```bash
export GITLAB_PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.project_path/${GITLAB_PROJECT_PATH}"

gcloud iam service-accounts add-iam-policy-binding "$TF_SA_EMAIL" \
  --member="$GITLAB_PRINCIPAL" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding "$AR_SA_EMAIL" \
  --member="$GITLAB_PRINCIPAL" \
  --role="roles/iam.workloadIdentityUser"
```

## 10. Create the Terraform State Bucket
The state bucket is regional in `REGION` and has versioning enabled.

```bash
gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --uniform-bucket-level-access

gcloud storage buckets update "gs://${TF_STATE_BUCKET}" \
  --versioning
```

## 11. Set GitLab CI Variables
After the bootstrap is complete, configure these GitLab CI variables:

```text
GCP_PROJECT_ID_DEV=<PROJECT_ID>
GCP_PROJECT_ID_STG=<PROJECT_ID for now if same>
GCP_PROJECT_ID_PRD=<PROJECT_ID for now if same>
GCP_REGION=<REGION>
GCP_WIF_PROVIDER=projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/<POOL_ID>/providers/<PROVIDER_ID>
GCP_TERRAFORM_SA=<TF_SA_EMAIL>
GCP_ARTIFACT_PUSH_SA=<AR_SA_EMAIL>
TF_STATE_BUCKET=<TF_STATE_BUCKET>
TF_STATE_PREFIX=mlflow
GITLAB_OIDC_AUDIENCE=https://<gitlab-host>
TF_VAR_mlflow_auth_admin_password=<shared-mlflow-admin-password>
TF_VAR_mlflow_flask_server_secret_key=<stable-random-secret-key>
```

## 12. Repository-Specific Notes
- This repository now authenticates to GCP using GitLab OIDC and Google Workload Identity Federation.
- If you only have a `dev` GCP project right now, you can temporarily set all three `GCP_PROJECT_ID_*` variables to the same project.
- The currently known-good `GCP_TERRAFORM_SA` roles include `roles/artifactregistry.reader` so Terraform can deploy Cloud Run services from private Artifact Registry images.
- The currently known-good `GCP_ARTIFACT_PUSH_SA` roles are:
  - `roles/artifactregistry.admin`
  - `roles/cloudbuild.builds.builder`
  - `roles/cloudbuild.builds.editor`
  - `roles/cloudbuild.builds.viewer`
  - `roles/iam.serviceAccountUser`
  - `roles/serviceusage.serviceUsageConsumer`
  - `roles/storage.admin`
