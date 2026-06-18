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

# Validate required env var
if [ -z "${GOOGLE_CLOUD_PROJECT:-}" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set. Copy .env.example to .env and fill in your values." >&2
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
echo "Deploying to Agent Engine (project: ${GOOGLE_CLOUD_PROJECT}, location: ${GOOGLE_CLOUD_LOCATION:-global})..."
.venv/bin/python deploy.py
