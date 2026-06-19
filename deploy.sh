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

echo "============================================================"
echo "1. Setting up local environment"
echo "============================================================"
if [ ! -d .venv ]; then
  echo "   - Creating virtual environment..."
  python3 -m venv .venv
fi
echo "   - Installing dependencies..."
.venv/bin/pip install --upgrade pip -q
.venv/bin/pip install "google-adk[gcp]" -r requirements.txt -q

# Build minimal staging directory with a valid Python identifier name
# (ADK uses the directory basename as agent name — dots are not allowed)
STAGING_BASE="/tmp/agent_deploy_$$"
mkdir -p "${STAGING_BASE}"

cp -r agent/ "${STAGING_BASE}/"
cp -r skill/ "${STAGING_BASE}/"
cp requirements.txt "${STAGING_BASE}/"

DEPLOY_LOG="$(mktemp)"
trap "rm -rf ${STAGING_BASE} ${DEPLOY_LOG}" EXIT

AGENT_NAME=$(grep '^name:' skill/SKILL.md | head -1 | sed 's/name: *//')
REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"

echo ""
echo "============================================================"
echo "2. Deploying '${AGENT_NAME}' to Google Cloud Agent Runtime"
echo "============================================================"
echo "   - Project: ${GOOGLE_CLOUD_PROJECT}"
echo "   - Region:  ${REGION}"
echo ""

"${SCRIPT_DIR}/.venv/bin/adk" deploy agent_engine \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --region="${REGION}" \
  --display_name="${AGENT_NAME}" \
  --artifact_service_uri="${STAGING_BUCKET}" \
  "${STAGING_BASE}" 2>&1 | tee "${DEPLOY_LOG}"

REASONING_ENGINE_ID=$(grep -oE 'projects/[0-9]+/locations/[a-z0-9-]+/reasoningEngines/[0-9]+' "${DEPLOY_LOG}" | tail -1)

echo ""
echo "============================================================"
echo "3. Connect to Gemini Enterprise Admin Console"
echo "============================================================"
echo "   - Log in to your Gemini Enterprise Admin Console."
echo "   - Navigate to 'Agents' in the left sidebar."
echo "   - Click '+ Add Agent' and select 'Custom agent via Agent Engine'."
echo "   - Enter the following Reasoning Engine Resource ID (Copy & Paste):"
echo "     👉 ${REASONING_ENGINE_ID:-projects/$GOOGLE_CLOUD_PROJECT/locations/$REGION/reasoningEngines/...}"
echo ""
