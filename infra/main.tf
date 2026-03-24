resource "google_project_service" "required_apis" {
  provider = google-beta
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "current" {
  provider   = google-beta
  project_id = var.project_id
}

resource "google_service_account" "mlflow_runtime" {
  provider     = google-beta
  project      = var.project_id
  account_id   = substr(replace(local.runtime_service_account, "_", "-"), 0, 30)
  display_name = "${local.mlflow_service_name} runtime"
}

resource "google_project_service_identity" "run_service_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "run.googleapis.com"

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "artifacts" {
  provider                    = google-beta
  project                     = var.project_id
  name                        = local.mlflow_bucket_name
  location                    = var.artifact_bucket_location
  force_destroy               = var.artifact_bucket_force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.labels

  versioning {
    enabled = true
  }

  dynamic "lifecycle_rule" {
    for_each = var.artifact_retention_days > 0 ? [1] : []
    content {
      condition {
        age = var.artifact_retention_days
      }
      action {
        type = "Delete"
      }
    }
  }

  depends_on = [google_project_service.required_apis]
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  provider  = google-beta
  project   = var.project_id
  secret_id = local.db_password_secret_name
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  provider    = google-beta
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret_iam_member" "runtime_secret_accessor" {
  provider = google-beta
  for_each = {
    db_password = google_secret_manager_secret.db_password.id
  }
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.mlflow_runtime.email}"
}

resource "google_storage_bucket_iam_member" "runtime_artifact_access" {
  provider = google-beta
  bucket   = google_storage_bucket.artifacts.name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.mlflow_runtime.email}"
}

resource "google_project_iam_member" "runtime_cloudsql_client" {
  provider = google-beta
  project  = var.project_id
  role     = "roles/cloudsql.client"
  member   = "serviceAccount:${google_service_account.mlflow_runtime.email}"
}

resource "google_project_iam_member" "run_service_agent_artifact_reader" {
  provider = google-beta
  project  = var.project_id
  # Cloud Run's Google-managed service agent must be able to read the private image.
  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_project_service_identity.run_service_agent.email}"
}

resource "google_compute_network" "mlflow" {
  provider                = google-beta
  project                 = var.project_id
  name                    = local.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mlflow" {
  provider                 = google-beta
  project                  = var.project_id
  name                     = local.subnet_name
  region                   = var.region
  network                  = google_compute_network.mlflow.id
  ip_cidr_range            = var.vpc_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_service_access" {
  provider      = google-beta
  project       = var.project_id
  name          = local.private_service_range
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  network       = google_compute_network.mlflow.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = google_compute_network.mlflow.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]

  depends_on = [google_project_service.required_apis]
}

resource "google_sql_database_instance" "mlflow" {
  provider            = google-beta
  project             = var.project_id
  name                = local.sql_instance_name
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection

  settings {
    # PostgreSQL 16 defaults to Enterprise Plus unless the edition is pinned.
    edition           = "ENTERPRISE"
    tier              = var.db_tier
    availability_type = var.db_availability_type
    disk_type         = "PD_SSD"
    disk_size         = var.db_disk_size_gb
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = var.db_backup_start_time
      point_in_time_recovery_enabled = var.db_point_in_time_recovery_enabled
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.mlflow.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled = true
    }

    user_labels = local.labels
  }

  depends_on = [
    google_project_service.required_apis,
    google_service_networking_connection.private_vpc_connection,
  ]
}

resource "google_sql_database" "mlflow" {
  provider = google-beta
  project  = var.project_id
  name     = var.db_name
  instance = google_sql_database_instance.mlflow.name
}

resource "google_sql_user" "mlflow" {
  provider = google-beta
  project  = var.project_id
  name     = var.db_user_name
  instance = google_sql_database_instance.mlflow.name
  password = random_password.db_password.result
}

resource "google_cloud_run_v2_service" "mlflow" {
  provider            = google-beta
  project             = var.project_id
  name                = local.mlflow_service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    service_account                  = google_service_account.mlflow_runtime.email
    timeout                          = "${var.cloud_run_timeout_seconds}s"
    max_instance_request_concurrency = var.cloud_run_concurrency
    labels                           = local.labels

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.mlflow.name
        subnetwork = google_compute_subnetwork.mlflow.name
      }
    }

    containers {
      image = var.mlflow_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu
          memory = var.cloud_run_memory
        }
      }

      env {
        name  = "MLFLOW_DB_USER"
        value = google_sql_user.mlflow.name
      }

      env {
        name  = "MLFLOW_DB_NAME"
        value = google_sql_database.mlflow.name
      }

      env {
        name  = "MLFLOW_DB_HOST"
        value = google_sql_database_instance.mlflow.private_ip_address
      }

      env {
        name  = "MLFLOW_DB_PORT"
        value = "5432"
      }

      env {
        name  = "MLFLOW_ARTIFACT_ROOT"
        value = local.artifact_root
      }

      env {
        name  = "MLFLOW_SERVER_ALLOWED_HOSTS"
        value = join(",", local.mlflow_allowed_hosts)
      }

      env {
        name  = "MLFLOW_SERVER_CORS_ALLOWED_ORIGINS"
        value = join(",", local.mlflow_cors_allowed_origins)
      }

      env {
        name = "MLFLOW_DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "MLFLOW_AUTH_ADMIN_USERNAME"
        value = var.mlflow_auth_admin_username
      }

      env {
        name  = "MLFLOW_AUTH_ADMIN_PASSWORD"
        value = var.mlflow_auth_admin_password
      }

      env {
        name  = "MLFLOW_AUTH_DEFAULT_PERMISSION"
        value = var.mlflow_auth_default_permission
      }

      env {
        name  = "MLFLOW_FLASK_SERVER_SECRET_KEY"
        value = var.mlflow_flask_server_secret_key
      }
    }
  }

  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret_iam_member.runtime_secret_accessor,
    google_storage_bucket_iam_member.runtime_artifact_access,
    google_project_iam_member.runtime_cloudsql_client,
    google_project_iam_member.run_service_agent_artifact_reader,
  ]
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  provider = google-beta
  project  = var.project_id
  location = google_cloud_run_v2_service.mlflow.location
  service  = google_cloud_run_v2_service.mlflow.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
