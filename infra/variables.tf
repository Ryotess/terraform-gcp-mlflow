variable "project_id" {
  description = "GCP project ID for the target environment."
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run and Cloud SQL."
  type        = string
}

variable "environment" {
  description = "Environment name such as dev, stg, or prd."
  type        = string
}

variable "name_prefix" {
  description = "Base prefix for resource names."
  type        = string
  default     = "platform"
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}

variable "mlflow_image" {
  description = "Immutable container image digest to deploy to Cloud Run."
  type        = string
}

variable "additional_mlflow_allowed_hosts" {
  description = "Additional MLflow Host headers to allow beyond the default Cloud Run hostname."
  type        = list(string)
  default     = []
}

variable "additional_mlflow_cors_allowed_origins" {
  description = "Additional MLflow CORS origins to allow beyond the default Cloud Run origin."
  type        = list(string)
  default     = []
}

variable "artifact_root_prefix" {
  description = "Prefix within the artifact bucket for MLflow artifacts."
  type        = string
  default     = "mlflow-artifacts"
}

variable "db_name" {
  description = "Cloud SQL database name for MLflow."
  type        = string
  default     = "mlflow"
}

variable "db_user_name" {
  description = "Cloud SQL user name for MLflow."
  type        = string
  default     = "mlflow"
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
}

variable "db_disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
}

variable "db_availability_type" {
  description = "Cloud SQL availability type."
  type        = string
  default     = "ZONAL"
}

variable "db_backup_start_time" {
  description = "Backup start time in UTC, formatted HH:MM."
  type        = string
  default     = "03:00"
}

variable "db_point_in_time_recovery_enabled" {
  description = "Whether PITR is enabled for Cloud SQL."
  type        = bool
  default     = false
}

variable "vpc_subnet_cidr" {
  description = "Primary subnet CIDR for the Cloud Run direct VPC egress subnet."
  type        = string
  default     = "10.10.0.0/24"
}

variable "private_service_access_prefix_length" {
  description = "Prefix length reserved for private services access used by Cloud SQL private IP."
  type        = number
  default     = 16
}

variable "cloud_run_cpu" {
  description = "Cloud Run CPU limit."
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Cloud Run memory limit."
  type        = string
  default     = "1Gi"
}

variable "cloud_run_timeout_seconds" {
  description = "Cloud Run request timeout."
  type        = number
  default     = 300
}

variable "cloud_run_concurrency" {
  description = "Cloud Run container concurrency."
  type        = number
  default     = 80
}

variable "cloud_run_min_instances" {
  description = "Cloud Run minimum instances."
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Cloud Run maximum instances."
  type        = number
  default     = 3
}

variable "mlflow_auth_admin_username" {
  description = "Initial MLflow basic-auth admin username."
  type        = string
  default     = "admin"
}

variable "mlflow_auth_admin_password" {
  description = "Initial MLflow basic-auth admin password."
  type        = string
  sensitive   = true
}

variable "mlflow_auth_default_permission" {
  description = "Default MLflow permission granted to authenticated users."
  type        = string
  default     = "NO_PERMISSIONS"

  validation {
    condition     = contains(["READ", "USE", "EDIT", "MANAGE", "NO_PERMISSIONS"], var.mlflow_auth_default_permission)
    error_message = "mlflow_auth_default_permission must be one of READ, USE, EDIT, MANAGE, or NO_PERMISSIONS."
  }
}

variable "mlflow_flask_server_secret_key" {
  description = "Shared Flask secret key used by MLflow basic auth for CSRF protection."
  type        = string
  sensitive   = true
}

variable "artifact_bucket_location" {
  description = "Location for the MLflow artifact bucket."
  type        = string
  default     = "asia-east1"
}

variable "artifact_bucket_force_destroy" {
  description = "Allow Terraform to delete the artifact bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "artifact_retention_days" {
  description = "Delete objects older than this many days. Set to 0 to disable lifecycle deletion."
  type        = number
  default     = 0
}

variable "deletion_protection" {
  description = "Enable deletion protection on Cloud SQL and Cloud Run."
  type        = bool
  default     = true
}
