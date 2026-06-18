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
