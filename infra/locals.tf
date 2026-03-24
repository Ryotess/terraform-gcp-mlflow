locals {
  name_prefix           = "${var.name_prefix}-${var.environment}"
  mlflow_service_name   = "${local.name_prefix}-mlflow"
  mlflow_default_host   = "${local.mlflow_service_name}-${data.google_project.current.number}.${var.region}.run.app"
  mlflow_default_origin = "https://${local.mlflow_default_host}"
  mlflow_allowed_hosts  = distinct(concat([local.mlflow_default_host], var.additional_mlflow_allowed_hosts))
  mlflow_cors_allowed_origins = distinct(
    concat([local.mlflow_default_origin], var.additional_mlflow_cors_allowed_origins)
  )
  mlflow_bucket_name      = trimsuffix(substr("${var.project_id}-${local.name_prefix}-artifacts", 0, 63), "-")
  sql_instance_name       = "${local.name_prefix}-sql"
  db_password_secret_name = "${local.name_prefix}-db-password"
  runtime_service_account = "${replace(local.mlflow_service_name, "-", "_")}-sa"
  network_name            = "${local.name_prefix}-vpc"
  subnet_name             = "${local.name_prefix}-subnet"
  private_service_range   = "${local.name_prefix}-private-services"
  artifact_root           = "gs://${google_storage_bucket.artifacts.name}/${var.artifact_root_prefix}"
  labels = merge(
    {
      environment = var.environment
      service     = "mlflow"
      managed_by  = "terraform"
    },
    var.labels
  )
}
