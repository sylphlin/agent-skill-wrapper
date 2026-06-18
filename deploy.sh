#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env if present
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# Validate required env vars
if [ -z "${GOOGLE_CLOUD_PROJECT:-}" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set. Copy .env.example to .env and fill in your values." >&2
  exit 1
fi
if [ -z "${STAGING_BUCKET:-}" ]; then
  echo "Error: STAGING_BUCKET is not set (e.g. gs://your-project-id-agent-staging)." >&2
  exit 1
fi

# Set up venv if not present
if [ ! -d .venv ]; then
  echo "Creating virtual environment..."
  python3 -m venv .venv
fi

# Install dependencies
echo "Installing dependencies..."
.venv/bin/pip install -q --upgrade "google-adk[gcp]" pyyaml python-dotenv

# Deploy via ADK CLI
AGENT_NAME=$(grep '^name:' skill/SKILL.md | head -1 | sed 's/name: *//')
echo "Deploying '${AGENT_NAME}' to Google Cloud Agent Runtime (project: ${GOOGLE_CLOUD_PROJECT}, location: ${GOOGLE_CLOUD_LOCATION:-us-central1})..."

.venv/bin/adk deploy agent_engine \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --region="${GOOGLE_CLOUD_LOCATION:-us-central1}" \
  --display_name="${AGENT_NAME}" \
  --artifact_service_uri="${STAGING_BUCKET}" \
  --requirements_file=requirements.txt \
  .
