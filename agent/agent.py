import os
import re
from pathlib import Path
from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.genai import types
from .skill_loader import load_skill
from .tools import make_tools

load_dotenv()

_TOOL_SUFFIX = """
---
You have access to the following tools when the skill instructions require them:
- run_script: execute a Python script bundled with this skill
- read_asset: read a reference or asset file bundled with this skill
"""

_DEFAULT_SKILL_DIR = Path(os.getenv("SKILL_DIR", str(Path(__file__).parent.parent / "skill")))


def build_agent(skill_dir: Path = _DEFAULT_SKILL_DIR) -> LlmAgent:
    skill_body, metadata = load_skill(skill_dir)
    timeout = int(os.getenv("SCRIPT_TIMEOUT_SECONDS", "60"))
    run_script, read_asset = make_tools(skill_dir, timeout=timeout)

    # LlmAgent requires a valid Python identifier as name; sanitize all non-identifier chars
    raw_name = metadata["name"]
    sanitized = re.sub(r"[^a-zA-Z0-9]", "_", raw_name)
    if sanitized and sanitized[0].isdigit():
        sanitized = "_" + sanitized
    agent_name = sanitized

    return LlmAgent(
        name=agent_name,
        model=os.getenv("MODEL", "gemini-3.5-flash"),
        generate_content_config=types.GenerateContentConfig(
            thinking_config=types.ThinkingConfig(
                thinking_level=getattr(
                    types.ThinkingLevel,
                    os.getenv("THINKING_LEVEL", "MEDIUM").upper(),
                    types.ThinkingLevel.MEDIUM,
                ),
            ),
        ),
        instruction=skill_body + _TOOL_SUFFIX,
        tools=[run_script, read_asset],
    )


# Only instantiate if skill/ exists (Task 6 will create it)
if _DEFAULT_SKILL_DIR.exists():
    root_agent = build_agent()
