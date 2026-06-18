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

## Usage Examples

### Example 1: run_script

The LLM can execute Python scripts bundled in `skill/scripts/`. Scripts are called by filename and receive the skill directory as working context.

**SKILL.md instruction:**
```markdown
If the user asks for a report, use the `run_script` tool with script `generate_report.py`
and pass the topic as the first argument.
```

**Conversation:**
```
User:  Generate a report on Q3 sales.
Agent: [calls run_script("generate_report.py", ["Q3 sales"])]
       Here is the Q3 sales report: ...
```

### Example 2: read_asset

The LLM can read any file inside the skill directory — templates, reference docs, configuration — using `read_asset`.

**SKILL.md instruction:**
```markdown
When the user asks for a greeting template, use the `read_asset` tool
with path `assets/greeting_templates.md` and share the relevant template.
```

**Conversation:**
```
User:  Give me a formal greeting template in Japanese.
Agent: [calls read_asset("assets/greeting_templates.md")]
       Here's a formal Japanese greeting: こんにちは、{name}さん！
```

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

### 2. Drop in your skill

Copy your skill package into the `skill/` directory:

```bash
cp -r path/to/your-skill/* skill/
```

At minimum, `skill/SKILL.md` must exist with a `name` and `description` in the frontmatter:

```markdown
---
name: my-skill
description: What this agent does and when to use it.
---

You are a helpful assistant that ...
```

Optionally include `skill/scripts/` for Python scripts and `skill/assets/` or `skill/references/` for files the LLM can read on demand.

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
| `STAGING_BUCKET` | required | GCS bucket for deployment artifacts (e.g. `gs://my-project-agent-staging`) |
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
│   ├── __init__.py       # Exports root_agent for ADK loader
│   ├── agent.py          # LlmAgent construction
│   ├── skill_loader.py   # SKILL.md parser
│   └── tools.py          # run_script and read_asset tools
├── skill/                # The bundled skill (replace to change agent behavior)
│   ├── SKILL.md
│   ├── scripts/          # Python scripts callable via run_script
│   └── assets/           # Files readable via read_asset
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
