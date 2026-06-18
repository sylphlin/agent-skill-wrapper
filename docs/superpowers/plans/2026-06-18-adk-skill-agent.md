# ADK Skill Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight Google ADK agent that loads a bundled Agent Skills–compliant skill at startup and deploys to Google Agent Engine.

**Architecture:** Single `LlmAgent` whose system prompt is the skill's `SKILL.md` body. Two tools (`run_script`, `read_asset`) give the LLM access to bundled Python scripts and asset files. The `skill/` directory is swapped to produce different agents.

**Tech Stack:** Python 3.11+, `google-adk`, `google-cloud-aiplatform`, `pyyaml`, `python-dotenv`, `pytest`

---

## File Map

| File | Responsibility |
|------|---------------|
| `pyproject.toml` | Project metadata and dependencies |
| `.env.example` | Template for required environment variables |
| `agent/__init__.py` | Empty — makes `agent` a package |
| `agent/skill_loader.py` | Parse `skill/SKILL.md`: frontmatter → metadata, body → system prompt |
| `agent/tools.py` | `run_script` and `read_asset` ADK tools |
| `agent/agent.py` | `LlmAgent` construction; `root_agent` module-level instance |
| `deploy.py` | One-shot deploy to Google Agent Engine |
| `skill/SKILL.md` | Example skill (used in dev/test) |
| `skill/scripts/demo.py` | Example Python script for the demo skill |
| `tests/conftest.py` | Shared pytest fixtures (temporary skill directory) |
| `tests/test_skill_loader.py` | Unit tests for `skill_loader` |
| `tests/test_tools.py` | Unit tests for `run_script` and `read_asset` |
| `tests/test_agent.py` | Smoke test: agent constructs correctly from example skill |

---

## Task 1: Project Scaffold

**Files:**
- Create: `pyproject.toml`
- Create: `.env.example`
- Create: `agent/__init__.py`
- Create: `tests/__init__.py`

- [ ] **Step 1: Create `pyproject.toml`**

```toml
[project]
name = "agent-skill-wrapper"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "google-adk>=1.0.0",
    "google-cloud-aiplatform>=1.87.0",
    "pyyaml>=6.0",
    "python-dotenv>=1.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-mock>=3.12",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

- [ ] **Step 2: Create `.env.example`**

```bash
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=global
MODEL=gemini-3.5-flash
THINKING_BUDGET=8192
SCRIPT_TIMEOUT_SECONDS=60
# SKILL_DIR=skill  # override only for testing
```

- [ ] **Step 3: Create empty `__init__.py` files**

```bash
touch agent/__init__.py tests/__init__.py
```

- [ ] **Step 4: Install dependencies**

```bash
pip install -e ".[dev]"
```

Expected: installs without errors.

- [ ] **Step 5: Commit**

```bash
git add pyproject.toml .env.example agent/__init__.py tests/__init__.py
git commit -m "chore: project scaffold"
```

---

## Task 2: `skill_loader.py`

**Files:**
- Create: `agent/skill_loader.py`
- Create: `tests/test_skill_loader.py`

- [ ] **Step 1: Write failing tests**

```python
# tests/test_skill_loader.py
import pytest
from pathlib import Path
from agent.skill_loader import load_skill, SkillLoadError


def _write_skill(tmp_path: Path, content: str) -> Path:
    skill_dir = tmp_path / "skill"
    skill_dir.mkdir()
    (skill_dir / "SKILL.md").write_text(content, encoding="utf-8")
    return skill_dir


def test_load_skill_returns_body_and_metadata(tmp_path):
    content = (
        "---\n"
        "name: my-skill\n"
        "description: Does things.\n"
        "---\n"
        "# Instructions\n\nDo the thing.\n"
    )
    skill_dir = _write_skill(tmp_path, content)
    body, metadata = load_skill(skill_dir)
    assert metadata["name"] == "my-skill"
    assert metadata["description"] == "Does things."
    assert body == "# Instructions\n\nDo the thing."


def test_load_skill_strips_body_whitespace(tmp_path):
    content = "---\nname: s\ndescription: d\n---\n\n  body  \n"
    skill_dir = _write_skill(tmp_path, content)
    body, _ = load_skill(skill_dir)
    assert body == "body"


def test_load_skill_raises_if_skill_md_missing(tmp_path):
    skill_dir = tmp_path / "skill"
    skill_dir.mkdir()
    with pytest.raises(SkillLoadError, match="SKILL.md not found"):
        load_skill(skill_dir)


def test_load_skill_raises_if_missing_frontmatter(tmp_path):
    skill_dir = _write_skill(tmp_path, "no frontmatter here")
    with pytest.raises(SkillLoadError, match="frontmatter"):
        load_skill(skill_dir)


def test_load_skill_raises_if_name_missing(tmp_path):
    content = "---\ndescription: d\n---\nbody"
    skill_dir = _write_skill(tmp_path, content)
    with pytest.raises(SkillLoadError, match="name"):
        load_skill(skill_dir)


def test_load_skill_raises_if_description_missing(tmp_path):
    content = "---\nname: my-skill\n---\nbody"
    skill_dir = _write_skill(tmp_path, content)
    with pytest.raises(SkillLoadError, match="description"):
        load_skill(skill_dir)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_skill_loader.py -v
```

Expected: `ModuleNotFoundError` or `ImportError` (file doesn't exist yet).

- [ ] **Step 3: Implement `skill_loader.py`**

```python
# agent/skill_loader.py
import re
import yaml
from pathlib import Path


class SkillLoadError(Exception):
    pass


def load_skill(skill_dir: Path) -> tuple[str, dict]:
    """Parse SKILL.md; return (body, metadata)."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        raise SkillLoadError(f"SKILL.md not found at {skill_md}")

    content = skill_md.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)", content, re.DOTALL)
    if not match:
        raise SkillLoadError("SKILL.md must begin with YAML frontmatter (--- ... ---)")

    metadata = yaml.safe_load(match.group(1)) or {}
    body = match.group(2).strip()

    if not metadata.get("name"):
        raise SkillLoadError("SKILL.md frontmatter must include 'name'")
    if not metadata.get("description"):
        raise SkillLoadError("SKILL.md frontmatter must include 'description'")

    return body, metadata
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_skill_loader.py -v
```

Expected: 6 tests PASSED.

- [ ] **Step 5: Commit**

```bash
git add agent/skill_loader.py tests/test_skill_loader.py
git commit -m "feat: skill_loader parses SKILL.md frontmatter and body"
```

---

## Task 3: `tools.py` — `run_script`

**Files:**
- Create: `agent/tools.py`
- Create: `tests/test_tools.py`
- Create: `tests/conftest.py`

- [ ] **Step 1: Create `conftest.py` with shared skill fixture**

```python
# tests/conftest.py
import pytest
from pathlib import Path


@pytest.fixture
def skill_dir(tmp_path: Path) -> Path:
    """Temporary skill directory with scripts/ and assets/ subdirs."""
    d = tmp_path / "skill"
    (d / "scripts").mkdir(parents=True)
    (d / "assets").mkdir()
    (d / "references").mkdir()
    return d
```

- [ ] **Step 2: Write failing tests for `run_script`**

```python
# tests/test_tools.py
import pytest
from pathlib import Path
from agent.tools import make_tools


def test_run_script_executes_python(skill_dir):
    (skill_dir / "scripts" / "hello.py").write_text('print("hi")')
    run_script, _ = make_tools(skill_dir)
    assert run_script("hello.py", []) == "hi\n"


def test_run_script_passes_args(skill_dir):
    (skill_dir / "scripts" / "echo.py").write_text(
        "import sys; print(sys.argv[1])"
    )
    run_script, _ = make_tools(skill_dir)
    assert run_script("echo.py", ["world"]) == "world\n"


def test_run_script_returns_error_on_failure(skill_dir):
    (skill_dir / "scripts" / "fail.py").write_text("raise ValueError('boom')")
    run_script, _ = make_tools(skill_dir)
    result = run_script("fail.py", [])
    assert result.startswith("[error]")


def test_run_script_rejects_path_traversal(skill_dir):
    run_script, _ = make_tools(skill_dir)
    result = run_script("../../etc/passwd", [])
    assert result == "[error] path traversal not allowed"


def test_run_script_returns_error_for_missing_script(skill_dir):
    run_script, _ = make_tools(skill_dir)
    result = run_script("nonexistent.py", [])
    assert result.startswith("[error] script not found")
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest tests/test_tools.py -v
```

Expected: `ImportError` or `ModuleNotFoundError`.

- [ ] **Step 4: Implement `tools.py` with `run_script`**

```python
# agent/tools.py
import subprocess
from pathlib import Path


def make_tools(skill_dir: Path, timeout: int = 60):
    """Return (run_script, read_asset) bound to skill_dir."""
    scripts_dir = skill_dir / "scripts"
    skill_dir_resolved = skill_dir.resolve()

    def run_script(script: str, args: list[str]) -> str:
        """Execute a Python script from the skill's scripts/ directory."""
        script_path = (scripts_dir / script).resolve()
        try:
            script_path.relative_to(scripts_dir.resolve())
        except ValueError:
            return "[error] path traversal not allowed"

        if not script_path.exists():
            return f"[error] script not found: {script}"

        try:
            result = subprocess.run(
                ["python3", str(script_path)] + list(args),
                cwd=str(skill_dir),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            if result.returncode != 0:
                return f"[error] {result.stderr}"
            return result.stdout
        except subprocess.TimeoutExpired:
            return f"[error] script timed out after {timeout}s"

    def read_asset(path: str) -> str:
        """Read a text file from the skill directory."""
        asset_path = (skill_dir / path).resolve()
        try:
            asset_path.relative_to(skill_dir_resolved)
        except ValueError:
            return "[error] path traversal not allowed"

        if not asset_path.exists():
            return f"[error] file not found: {path}"

        return asset_path.read_text(encoding="utf-8")

    return run_script, read_asset
```

- [ ] **Step 5: Run `run_script` tests**

```bash
pytest tests/test_tools.py::test_run_script_executes_python tests/test_tools.py::test_run_script_passes_args tests/test_tools.py::test_run_script_returns_error_on_failure tests/test_tools.py::test_run_script_rejects_path_traversal tests/test_tools.py::test_run_script_returns_error_for_missing_script -v
```

Expected: 5 tests PASSED.

- [ ] **Step 6: Commit**

```bash
git add agent/tools.py tests/conftest.py tests/test_tools.py
git commit -m "feat: run_script tool with path-traversal guard"
```

---

## Task 4: `tools.py` — `read_asset`

**Files:**
- Modify: `tests/test_tools.py`

- [ ] **Step 1: Add failing tests for `read_asset`**

Append to `tests/test_tools.py`:

```python
def test_read_asset_returns_file_contents(skill_dir):
    (skill_dir / "references" / "guide.md").write_text("# Guide")
    _, read_asset = make_tools(skill_dir)
    assert read_asset("references/guide.md") == "# Guide"


def test_read_asset_rejects_path_traversal(skill_dir):
    _, read_asset = make_tools(skill_dir)
    result = read_asset("../../etc/passwd")
    assert result == "[error] path traversal not allowed"


def test_read_asset_returns_error_for_missing_file(skill_dir):
    _, read_asset = make_tools(skill_dir)
    result = read_asset("assets/missing.txt")
    assert result.startswith("[error] file not found")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_tools.py::test_read_asset_returns_file_contents tests/test_tools.py::test_read_asset_rejects_path_traversal tests/test_tools.py::test_read_asset_returns_error_for_missing_file -v
```

Expected: FAIL — `read_asset` not yet implemented. (It's already implemented in `make_tools` from Task 3, so they should actually PASS. If they do, proceed.)

- [ ] **Step 3: Run all tool tests**

```bash
pytest tests/test_tools.py -v
```

Expected: 8 tests PASSED.

- [ ] **Step 4: Commit**

```bash
git add tests/test_tools.py
git commit -m "test: add read_asset tests"
```

---

## Task 5: `agent.py` — LlmAgent

**Files:**
- Create: `agent/agent.py`
- Create: `tests/test_agent.py`

- [ ] **Step 1: Write failing test**

```python
# tests/test_agent.py
import pytest
from pathlib import Path
from unittest.mock import patch
from agent.agent import build_agent


def _make_skill(tmp_path: Path) -> Path:
    skill_dir = tmp_path / "skill"
    (skill_dir / "scripts").mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\nname: test-skill\ndescription: A test skill.\n---\nDo the task.\n",
        encoding="utf-8",
    )
    return skill_dir


def test_build_agent_uses_skill_name(tmp_path):
    skill_dir = _make_skill(tmp_path)
    agent = build_agent(skill_dir=skill_dir)
    assert agent.name == "test-skill"


def test_build_agent_instruction_contains_skill_body(tmp_path):
    skill_dir = _make_skill(tmp_path)
    agent = build_agent(skill_dir=skill_dir)
    assert "Do the task." in agent.instruction
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_agent.py -v
```

Expected: `ImportError` — `agent.py` doesn't exist yet.

- [ ] **Step 3: Implement `agent.py`**

```python
# agent/agent.py
import os
from pathlib import Path
from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.genai.types import GenerateContentConfig, ThinkingConfig
from .skill_loader import load_skill
from .tools import make_tools

load_dotenv()

_TOOL_SUFFIX = """
---
You have access to the following tools when the skill instructions require them:
- run_script: execute a Python script bundled with this skill
- read_asset: read a reference or asset file bundled with this skill
"""

_DEFAULT_SKILL_DIR = Path(__file__).parent.parent / "skill"


def build_agent(skill_dir: Path = _DEFAULT_SKILL_DIR) -> LlmAgent:
    skill_body, metadata = load_skill(skill_dir)
    timeout = int(os.getenv("SCRIPT_TIMEOUT_SECONDS", "60"))
    run_script, read_asset = make_tools(skill_dir, timeout=timeout)

    return LlmAgent(
        name=metadata["name"],
        model=os.getenv("MODEL", "gemini-3.5-flash"),
        generate_content_config=GenerateContentConfig(
            thinking_config=ThinkingConfig(
                thinking_budget=int(os.getenv("THINKING_BUDGET", "8192")),
            ),
        ),
        instruction=skill_body + _TOOL_SUFFIX,
        tools=[run_script, read_asset],
    )


root_agent = build_agent()
```

- [ ] **Step 4: Run tests**

```bash
pytest tests/test_agent.py -v
```

Expected: 2 tests PASSED.

> Note: If `LlmAgent` is not importable (no ADK installed or mock needed), install `google-adk` first: `pip install google-adk`. If the live `root_agent = build_agent()` line fails at import time due to missing `skill/SKILL.md`, create the example skill (Task 6) first, then return to run these tests.

- [ ] **Step 5: Run full test suite**

```bash
pytest -v
```

Expected: all tests PASSED.

- [ ] **Step 6: Commit**

```bash
git add agent/agent.py tests/test_agent.py
git commit -m "feat: LlmAgent construction from SKILL.md"
```

---

## Task 6: Example Skill

**Files:**
- Create: `skill/SKILL.md`
- Create: `skill/scripts/demo.py`

- [ ] **Step 1: Create `skill/SKILL.md`**

```markdown
---
name: echo-assistant
description: A friendly assistant that echoes information and can run a bundled demo script. Use when the user wants to test the agent or run the demo.
---

You are a helpful assistant. Answer user questions clearly and concisely.

If the user asks to run a demo, use the `run_script` tool with script `demo.py` and no arguments, then share the output with the user.

If the user asks to read a file, use the `read_asset` tool with the relative path they provide.
```

- [ ] **Step 2: Create `skill/scripts/demo.py`**

```python
# skill/scripts/demo.py
print("Agent Skills demo: script executed successfully.")
print("Skill directory is the working directory.")
```

- [ ] **Step 3: Verify agent constructs from example skill**

```bash
python -c "from agent.agent import root_agent; print(root_agent.name)"
```

Expected output: `echo-assistant`

- [ ] **Step 4: Commit**

```bash
git add skill/
git commit -m "feat: add echo-assistant example skill"
```

---

## Task 7: Deployment Script

**Files:**
- Create: `deploy.py`

- [ ] **Step 1: Create `deploy.py`**

```python
# deploy.py
"""Deploy agent to Google Agent Engine."""
import os
import vertexai
from vertexai.preview.reasoning_engines import AdkApp, ReasoningEngine
from dotenv import load_dotenv
from agent.agent import root_agent

load_dotenv()

PROJECT = os.environ["GOOGLE_CLOUD_PROJECT"]
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "global")

vertexai.init(project=PROJECT, location=LOCATION)

app = AdkApp(agent=root_agent, enable_tracing=True)

remote = ReasoningEngine.create(
    app,
    requirements=[
        "google-adk>=1.0.0",
        "google-cloud-aiplatform>=1.87.0",
        "pyyaml>=6.0",
        "python-dotenv>=1.0",
    ],
    display_name=root_agent.name,
    description=f"Agent Skills agent: {root_agent.name}",
)

print(f"Deployed: {remote.resource_name}")
```

> **Note:** `AdkApp` and `ReasoningEngine` API names may differ slightly across ADK/aiplatform versions. Verify against the installed version's docs if import fails: `python -c "import vertexai.preview.reasoning_engines; help(vertexai.preview.reasoning_engines)"`.

- [ ] **Step 2: Verify the script is importable (without deploying)**

```bash
python -c "import deploy" 2>&1 | head -5
```

Expected: no `SyntaxError` or obvious `ImportError` (a missing env var error is fine at this stage).

- [ ] **Step 3: Commit**

```bash
git add deploy.py
git commit -m "feat: Agent Engine deploy script"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| SKILL.md frontmatter parsed (name, description) | Task 2 |
| SKILL.md body becomes system prompt | Task 5 |
| `run_script` — Python only, CWD = skill/, timeout | Task 3 |
| `run_script` — path traversal guard | Task 3 |
| `read_asset` — path traversal guard | Task 4 |
| Agent name from skill `name` field | Task 5 |
| Model: `gemini-3.5-flash` | Task 5 |
| Thinking: medium (`thinking_budget=8192`) | Task 5 |
| Location: `global` | Task 7 |
| All config overridable via `.env` | Task 1, 5 |
| Error on missing `SKILL.md` | Task 2 |
| Error on missing `name`/`description` | Task 2 |
| Script timeout | Task 3 |
| Example skill for dev/test | Task 6 |
| Deployment to Agent Engine | Task 7 |

**Placeholder scan:** No TBD/TODO in code steps. Deploy script includes a verification note for API version differences.

**Type consistency:** `make_tools(skill_dir, timeout)` defined in Task 3, called with same signature in Task 5. `load_skill(skill_dir)` returns `(str, dict)` defined in Task 2, consumed in Task 5. Consistent throughout.
