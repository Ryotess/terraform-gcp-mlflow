output "cloud_run_service_name" {
  description = "Deployed Cloud Run service name."
  value       = google_cloud_run_v2_service.mlflow.name
}

output "cloud_run_uri" {
  description = "Cloud Run service URI."
  value       = google_cloud_run_v2_service.mlflow.uri
}

output "artifact_bucket_name" {
  description = "GCS bucket used for MLflow artifacts."
  value       = google_storage_bucket.artifacts.name
}

output "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name."
  value       = google_sql_database_instance.mlflow.connection_name
}

output "cloudsql_private_ip_address" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.mlflow.private_ip_address
}

output "runtime_service_account_email" {
  description = "Service account attached to Cloud Run."
  value       = google_service_account.mlflow_runtime.email
}

output "db_password_secret_id" {
  description = "Secret Manager secret ID containing the MLflow DB password."
  value       = google_secret_manager_secret.db_password.secret_id
}

output "mlflow_auth_admin_username" {
  description = "Initial MLflow basic-auth admin username."
  value       = var.mlflow_auth_admin_username
}
