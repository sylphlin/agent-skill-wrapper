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
.venv/bin/pip install -q -e .

# Deploy
echo "Deploying to Google Cloud Agent Runtime (project: ${GOOGLE_CLOUD_PROJECT}, location: ${GOOGLE_CLOUD_LOCATION:-us-central1})..."

.venv/bin/python - <<'EOF'
import os
import vertexai
from vertexai.preview.reasoning_engines import AdkApp, ReasoningEngine
from agent.agent import root_agent

vertexai.init(
    project=os.environ["GOOGLE_CLOUD_PROJECT"],
    location=os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"),
    staging_bucket=os.environ["STAGING_BUCKET"],
)

app = AdkApp(agent=root_agent, enable_tracing=True)
remote = ReasoningEngine.create(
    app,
    requirements=[
        "google-adk>=2.0.0",
        "google-cloud-aiplatform[agent_engines]>=1.87.0",
        "pyyaml>=6.0",
        "python-dotenv>=1.0",
    ],
    display_name=root_agent.name,
    description=f"Agent Skills agent: {root_agent.name}",
)
print(f"Deployed: {remote.resource_name}")
EOF
