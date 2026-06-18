# Agent Skill Wrapper for Google Cloud Agent Runtime

A lightweight framework for running [Agent Skills](https://agentskills.io/specification) on [Google Cloud Agent Runtime](https://cloud.google.com/vertex-ai/generative-ai/docs/agent-engine/overview) (formerly Vertex AI Agent Engine).

Each deployment is a single-skill agent: the skill defines the agent's entire behavior. Swapping the `skill/` directory and redeploying creates a different agent — similar to Google Gems or ChatGPT GPTs.

## How It Works

```
skill/SKILL.md  →  system prompt
skill/scripts/  →  run_script tool
skill/assets/   →  read_asset tool
skill/references/
```

At startup, the agent loads `skill/SKILL.md` and uses its body as the LLM's system prompt. The LLM can call two tools when the skill instructions require them:

- **`run_script(script, args)`** — execute a Python script from `skill/scripts/`
- **`read_asset(path)`** — read a reference or asset file from the skill directory

The skill format follows the open [Agent Skills specification](https://agentskills.io/specification).

## Quickstart

### 1. Clone and configure

```bash
git clone <this-repo>
cd agent-skill-wrapper
cp .env.example .env
```

Edit `.env`:

```bash
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=global
```

### 2. Write your skill

Replace `skill/SKILL.md` with your own skill:

```markdown
---
name: my-skill
description: What this agent does and when to use it.
---

You are a helpful assistant that ...

(Instructions for the LLM go here.)
```

Add Python scripts to `skill/scripts/` and reference files to `skill/references/` or `skill/assets/` as needed.

### 3. Deploy

```bash
./deploy.sh
```

This creates a virtual environment, installs dependencies, and deploys the agent to Google Cloud Agent Runtime.

## Skill Directory Layout

```
skill/
├── SKILL.md          # Required: YAML frontmatter + instructions
├── scripts/          # Optional: Python scripts the LLM can run
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: templates, data files
```

`SKILL.md` frontmatter fields:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (lowercase letters, numbers, hyphens) |
| `description` | Yes | What the skill does and when to use it |
| `license` | No | License name or reference |
| `compatibility` | No | Environment requirements |
| `metadata` | No | Arbitrary key-value pairs |

## Configuration

All settings are read from `.env` (or environment variables):

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_CLOUD_PROJECT` | required | GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | `us-central1` | Agent Runtime deployment region |
| `MODEL_LOCATION` | `global` | Gemini model endpoint region (newer models require `global`) |
| `MODEL` | `gemini-3.5-flash` | Gemini model ID |
| `THINKING_LEVEL` | `MEDIUM` | Thinking level: `LOW`, `MEDIUM`, `HIGH` |
| `SCRIPT_TIMEOUT_SECONDS` | `60` | Script execution timeout |

## Switching Skills

To deploy a different agent, replace the `skill/` directory and redeploy:

```bash
# Copy in a new skill
cp -r path/to/new-skill/* skill/

# Redeploy
./deploy.sh
```

No code changes required — the wrapper is skill-agnostic.

## Project Structure

```
agent-skill-wrapper/
├── agent/
│   ├── agent.py          # LlmAgent construction
│   ├── skill_loader.py   # SKILL.md parser
│   └── tools.py          # run_script and read_asset tools
├── skill/                # The bundled skill (replace to change agent behavior)
├── deploy.sh             # Deployment script (Agent Runtime)
└── pyproject.toml
```

## Development

```bash
# Install with dev dependencies
pip install -e ".[dev]"

# Run tests
pytest -v
```

## Requirements

- Python 3.11+
- Google Cloud project with Agent Runtime (formerly Vertex AI Agent Engine) API enabled
- `gcloud` authenticated (`gcloud auth application-default login`)
