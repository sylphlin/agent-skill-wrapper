import pytest
from pathlib import Path
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
    assert agent.name == "test_skill"


def test_build_agent_instruction_contains_skill_body(tmp_path):
    skill_dir = _make_skill(tmp_path)
    agent = build_agent(skill_dir=skill_dir)
    assert "Do the task." in agent.instruction
