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
.venv/bin/pip install --upgrade pip -q
.venv/bin/pip install "google-adk[gcp]" -r requirements.txt -q

# Deploy via ADK CLI
AGENT_NAME=$(grep '^name:' skill/SKILL.md | head -1 | sed 's/name: *//')
echo "Deploying '${AGENT_NAME}' to Google Cloud Agent Runtime (project: ${GOOGLE_CLOUD_PROJECT}, location: ${GOOGLE_CLOUD_LOCATION:-us-central1})..."

# Build minimal staging directory with a valid Python identifier name
# (ADK uses the directory basename as agent name — dots are not allowed)
STAGING_BASE="/tmp/agent_deploy_$$"
mkdir -p "${STAGING_BASE}"
trap "rm -rf ${STAGING_BASE}" EXIT

cp -r agent/ "${STAGING_BASE}/"
cp -r skill/ "${STAGING_BASE}/"
cp requirements.txt "${STAGING_BASE}/"

"${SCRIPT_DIR}/.venv/bin/adk" deploy agent_engine \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --region="${GOOGLE_CLOUD_LOCATION:-us-central1}" \
  --display_name="${AGENT_NAME}" \
  --artifact_service_uri="${STAGING_BUCKET}" \
  "${STAGING_BASE}"
