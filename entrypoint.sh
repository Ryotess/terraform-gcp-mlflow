#!/usr/bin/env bash
set -euo pipefail

: "${MLFLOW_DB_USER:?MLFLOW_DB_USER is required}"
: "${MLFLOW_DB_PASSWORD:?MLFLOW_DB_PASSWORD is required}"
: "${MLFLOW_DB_NAME:?MLFLOW_DB_NAME is required}"
: "${MLFLOW_DB_HOST:?MLFLOW_DB_HOST is required}"
: "${MLFLOW_ARTIFACT_ROOT:?MLFLOW_ARTIFACT_ROOT is required}"
: "${MLFLOW_AUTH_ADMIN_USERNAME:?MLFLOW_AUTH_ADMIN_USERNAME is required}"
: "${MLFLOW_AUTH_ADMIN_PASSWORD:?MLFLOW_AUTH_ADMIN_PASSWORD is required}"
: "${MLFLOW_FLASK_SERVER_SECRET_KEY:?MLFLOW_FLASK_SERVER_SECRET_KEY is required}"

PORT="${PORT:-8080}"
DB_PORT="${MLFLOW_DB_PORT:-5432}"
BACKEND_STORE_URI="postgresql+psycopg2://${MLFLOW_DB_USER}:${MLFLOW_DB_PASSWORD}@${MLFLOW_DB_HOST}:${DB_PORT}/${MLFLOW_DB_NAME}"
AUTH_DB_URI="${BACKEND_STORE_URI}"
AUTH_DEFAULT_PERMISSION="${MLFLOW_AUTH_DEFAULT_PERMISSION:-NO_PERMISSIONS}"
AUTH_CONFIG_PATH="/tmp/mlflow-basic-auth.ini"

cat > "${AUTH_CONFIG_PATH}" <<EOF
[mlflow]
default_permission = ${AUTH_DEFAULT_PERMISSION}
database_uri = ${AUTH_DB_URI}
admin_username = ${MLFLOW_AUTH_ADMIN_USERNAME}
admin_password = ${MLFLOW_AUTH_ADMIN_PASSWORD}
EOF

export MLFLOW_AUTH_CONFIG_PATH="${AUTH_CONFIG_PATH}"

python -m mlflow.server.auth db upgrade --url "${AUTH_DB_URI}"

exec mlflow server \
  --app-name basic-auth \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --backend-store-uri "${BACKEND_STORE_URI}" \
  --default-artifact-root "${MLFLOW_ARTIFACT_ROOT}" \
  --serve-artifacts
