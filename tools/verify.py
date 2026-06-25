#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import py_compile
import runpy
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]


def check(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)
    print(f"ok: {message}")


def run(
    argv: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 120,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify the Niri computer-use flake")
    parser.add_argument("--nix", action="store_true", help="also run Nix flake evaluation checks")
    args = parser.parse_args()

    aiui = PACKAGE_ROOT / "overlay/spreadconfig/scripts/default/aiui/aiui"
    policy = PACKAGE_ROOT / "overlay/spreadconfig/scripts/default/aiui/policy.json"
    skill = PACKAGE_ROOT / "overlay/skills/local/niri-computer-use/SKILL.md"
    safety = PACKAGE_ROOT / "overlay/skills/local/niri-computer-use/references/SAFETY.md"

    required = [
        PACKAGE_ROOT / "flake.nix",
        PACKAGE_ROOT / "nix/aiui.nix",
        PACKAGE_ROOT / "nix/home-module.nix",
        PACKAGE_ROOT / "nix/nixos-module.nix",
        PACKAGE_ROOT / "nix/lib.nix",
        aiui,
        policy,
        skill,
        safety,
    ]
    for path in required:
        check(path.is_file(), f"required file exists: {path.relative_to(PACKAGE_ROOT)}")

    check(not (PACKAGE_ROOT / "apply.sh").exists(), "patch installer is absent")
    check(not (PACKAGE_ROOT / "tools/apply.py").exists(), "patch installer implementation is absent")

    flake_text = (PACKAGE_ROOT / "flake.nix").read_text(encoding="utf-8")
    check("nixosModules" in flake_text, "flake exposes NixOS modules")
    check("homeManagerModules" in flake_text, "flake exposes Home Manager modules")
    check("packages" in flake_text and "aiui" in flake_text, "flake exposes aiui package")

    with tempfile.TemporaryDirectory(prefix="aiui-pycompile-") as compile_raw:
        py_compile.compile(str(aiui), cfile=str(Path(compile_raw) / "aiui.pyc"), doraise=True)
    check(True, "aiui Python syntax")

    policy_data = json.loads(policy.read_text(encoding="utf-8"))
    check(policy_data.get("version") == 2, "policy JSON schema version")
    check("sudo" in policy_data.get("deny_commands", []), "policy denies privilege escalation")
    check("wechat" in policy_data.get("gui_launch_commands", []), "policy allows medium-risk WeChat GUI launch")
    check(
        "start_wechat.sh" in policy_data.get("gui_launch_commands", []),
        "policy allows medium-risk spreadconfig WeChat launcher",
    )

    skill_text = skill.read_text(encoding="utf-8")
    check(skill_text.startswith("---\nname: niri-computer-use\n"), "skill frontmatter")
    check("emergency stop" in skill_text.lower(), "skill documents emergency stop")

    with tempfile.TemporaryDirectory(prefix="aiui-verify-runtime-") as runtime_raw, tempfile.TemporaryDirectory(
        prefix="aiui-verify-state-"
    ) as state_raw:
        env = os.environ.copy()
        env["XDG_RUNTIME_DIR"] = runtime_raw
        env["XDG_STATE_HOME"] = state_raw
        env.pop("WAYLAND_DISPLAY", None)
        env.pop("NIRI_SOCKET", None)

        cp = run([sys.executable, str(aiui), "waybar"], env=env)
        check(cp.returncode == 0, "Waybar status command exits successfully")
        payload = json.loads(cp.stdout)
        check(payload.get("class") == "idle", "Waybar initial state is idle")

        cp = run([sys.executable, str(aiui), "session", "start", "--task", "static verification"], env=env)
        check(cp.returncode == 0, "session start without UI actuation")
        cp = run([sys.executable, str(aiui), "status"], env=env)
        state = json.loads(cp.stdout)["state"]
        check(state.get("mode") == "ready" and state.get("session_id"), "active session state")

        launcher_dir = Path(runtime_raw) / "bin"
        launcher_dir.mkdir()
        launcher = launcher_dir / "wechat"
        launcher.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        launcher.chmod(0o755)
        launch_env = env | {"PATH": f"{launcher_dir}{os.pathsep}{env.get('PATH', '')}"}
        cp = run(
            [
                sys.executable,
                str(aiui),
                "launch",
                "--reason",
                "Open WeChat for static verification",
                "--risk",
                "medium",
                "--",
                "wechat",
            ],
            env=launch_env,
        )
        if cp.returncode != 0:
            print(cp.stdout, file=sys.stderr)
            print(cp.stderr, file=sys.stderr)
        check(cp.returncode == 0, "GUI launch command exits without waiting for app lifetime")
        payload = json.loads(cp.stdout)
        check(payload.get("risk") == "medium", "GUI launch keeps allowlisted app at medium risk")
        cp = run([sys.executable, str(aiui), "status"], env=env)
        state = json.loads(cp.stdout)["state"]
        check(state.get("mode") == "ready", "GUI launch restores ready state")

        cp = run([sys.executable, str(aiui), "emergency-stop", "--source", "verify"], env=env)
        check(cp.returncode == 0, "emergency-stop command")
        cp = run([sys.executable, str(aiui), "status"], env=env)
        state = json.loads(cp.stdout)["state"]
        check(state.get("mode") == "stopped", "emergency-stop latch state")

    namespace = runpy.run_path(str(aiui), run_name="aiui_verify_import")
    modifiers, key = namespace["parse_hotkey"]("ctrl+shift+enter")
    check(modifiers == ["ctrl", "shift"] and key == "Return", "hotkey parser")
    risk, _ = namespace["classify_command"](["git", "push"], policy_data)
    check(risk == "high", "structured runner classifies git push as high risk")
    risk, _ = namespace["classify_command"](["sudo", "true"], policy_data)
    check(risk == "deny", "structured runner denies privilege escalation")
    risk, _ = namespace["classify_launch_command"](["wechat"], policy_data)
    check(risk == "medium", "GUI launch classifier allowlists WeChat without arguments")
    risk, _ = namespace["classify_launch_command"](["wechat", "--some-arg"], policy_data)
    check(risk == "high", "GUI launch classifier escalates allowlisted app with arguments")
    risk, _ = namespace["classify_launch_command"](["/home/spreadzhao/scripts/util/start_wechat.sh"], policy_data)
    check(risk == "medium", "GUI launch classifier allowlists spreadconfig WeChat launcher")

    if args.nix:
        check(shutil.which("nix") is not None, "nix executable is available")
        cp = run(
            ["nix", "flake", "show", f"path:{PACKAGE_ROOT}", "--no-write-lock-file"],
            cwd=PACKAGE_ROOT,
            timeout=300,
        )
        if cp.returncode != 0:
            print(cp.stdout, file=sys.stderr)
            print(cp.stderr, file=sys.stderr)
        check(cp.returncode == 0, "nix flake show")

    print("\nAll requested checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, json.JSONDecodeError, py_compile.PyCompileError, subprocess.TimeoutExpired) as exc:
        print(f"verification failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
