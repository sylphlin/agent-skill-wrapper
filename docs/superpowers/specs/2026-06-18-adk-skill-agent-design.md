# ADK Skill Agent — Design Spec

**Date:** 2026-06-18  
**Status:** Approved

## Overview

A lightweight Google ADK agent that runs on Google Agent Engine and implements the [Agent Skills open standard](https://agentskills.io/specification). Each deployed instance is a single-skill agent: the skill defines the agent's entire behavior (analogous to Google Gems or ChatGPT GPTs). Swapping the skill directory and redeploying produces a different agent.

## Goals

- Implement the Agent Skills specification (SKILL.md + scripts + assets) on Google ADK
- Single-skill-per-agent model: skill IS the agent's identity and workflow
- Lightweight wrapper: minimal code, skill does the heavy lifting
- Deploy to Google Agent Engine

## Non-Goals

- Multi-skill selection / progressive disclosure across many skills
- External skill registry or dynamic skill loading at runtime
- Bash script execution support
- Skill marketplace or versioning system

## Directory Structure

```
agent-skill-wrapper/
├── agent/
│   ├── agent.py          # ADK LlmAgent definition
│   ├── skill_loader.py   # Reads skill/, builds system prompt
│   └── tools.py          # run_script and read_asset tools
├── skill/                # The bundled skill (one per deployment)
│   ├── SKILL.md          # Required: frontmatter + instructions
│   ├── scripts/          # Optional: Python scripts
│   ├── references/       # Optional: reference documents
│   └── assets/           # Optional: templates, data files
├── pyproject.toml
└── .env
```

## Skill Loading

`skill_loader.py` runs at agent startup:

1. Reads `skill/SKILL.md`
2. Parses YAML frontmatter to extract `name`, `description`, and other metadata
3. Returns the Markdown body as the system prompt core
4. The agent's `name` field is set from the skill's `name` frontmatter field

The full SKILL.md body is loaded immediately (not progressively), because this agent has exactly one skill and it IS the agent's system prompt.

## System Prompt Structure

```
{SKILL.md body — verbatim}

---
You have access to the following tools when the skill instructions require them:
- run_script: execute a Python script bundled with this skill
- read_asset: read a reference or asset file bundled with this skill
```

The skill body is the primary instruction. The tool description is appended by the wrapper.

## Tools

### `run_script(script: str, args: list[str]) -> str`

Executes a Python script from the skill's `scripts/` directory.

- **Invocation:** `python3 skill/scripts/<script>` with `args` passed as CLI arguments
- **CWD:** `skill/` directory
- **Timeout:** 60 seconds (configurable via `SCRIPT_TIMEOUT_SECONDS` env var)
- **On success:** returns stdout
- **On failure:** returns stderr prefixed with `[error]`
- **Security:** path is restricted to `skill/scripts/`; no path traversal allowed

### `read_asset(path: str) -> str`

Reads a text file from the skill directory.

- **Allowed paths:** any file under `skill/` (e.g., `references/guide.md`, `assets/template.txt`)
- **Security:** path is restricted within `skill/`; no path traversal allowed
- **Returns:** file contents as a string
- **On missing file:** returns a clear error string

## ADK Agent Configuration

```python
LlmAgent(
    name=skill_metadata["name"],
    model="gemini-3.5-flash",
    generate_content_config=GenerateContentConfig(
        thinking_config=ThinkingConfig(thinking_budget=8192),  # medium
    ),
    instruction=skill_body,
    tools=[run_script, read_asset],
)
```

| Setting | Value |
|---------|-------|
| Model | `gemini-3.5-flash` |
| Thinking level | Medium (`thinking_budget=8192`) |
| Location | `global` |
| Tools | `run_script`, `read_asset` |

Model and thinking budget are overridable via `.env`.

## Deployment

Skills are bundled with the agent at deploy time. Changing a skill requires redeploying.

```
# Deploy to Agent Engine
vertexai.init(project=PROJECT_ID, location="global")
vertexai.agent_engines.create(agent, requirements=[...])
```

The `skill/` directory is included in the deployment package alongside `agent/`.

## Swapping Skills

To create a different agent (different purpose):

1. Replace the contents of `skill/` with a new skill package
2. Redeploy to Agent Engine

No code changes required — the wrapper is skill-agnostic.

## Configuration (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `GOOGLE_CLOUD_PROJECT` | required | GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | `global` | Agent Engine location |
| `MODEL` | `gemini-3.5-flash` | Gemini model ID |
| `THINKING_BUDGET` | `8192` | Thinking token budget |
| `SCRIPT_TIMEOUT_SECONDS` | `60` | Script execution timeout |

## Error Handling

- **Missing `skill/SKILL.md`:** raise at startup with a clear message
- **Invalid frontmatter:** raise at startup (name and description are required)
- **Script timeout:** return timeout error string to LLM
- **Path traversal attempt:** return security error string to LLM

## Out of Scope

- Bash or other language script execution (Python only)
- Dynamic skill loading without redeploy
- `allowed-tools` frontmatter field enforcement (ignored in this implementation)
- Multi-turn memory / session persistence (ADK default behavior applies)
