#!/usr/bin/env bash
set -euo pipefail

TERRAFORM_VERSION="${1:?terraform version is required}"
ARCHIVE="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"

if command -v terraform >/dev/null 2>&1; then
  exit 0
fi

curl -fsSLo "/tmp/${ARCHIVE}" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${ARCHIVE}"
unzip -o "/tmp/${ARCHIVE}" -d /usr/local/bin >/dev/null

