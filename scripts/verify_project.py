#!/usr/bin/env python3
"""Run native Godot checks without touching player saves (Python 3.10+)."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def run(engine, project, environment, arguments, timeout, marker=None, rendered=False):
    print(f"Checking: {' '.join(arguments)}", flush=True)
    process = subprocess.Popen(
        [engine, *([] if rendered else ["--headless"]), "--path", str(project), *arguments],
        env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace",
        start_new_session=os.name != "nt",
    )
    try:
        output, _ = process.communicate(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        # A Windows .cmd launcher owns a child engine process; killing only
        # the wrapper would leave Godot running and the test files locked.
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            import signal
            os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        print(output, end="", flush=True)
        raise
    if process.returncode or "ERROR:" in output:
        print(output, end="", flush=True)
        raise RuntimeError(f"Godot check failed (exit {process.returncode})")
    if marker and marker not in output:
        print(output, end="", flush=True)
        raise RuntimeError(f"Godot exited without completing: {marker}")
    print(marker or "Import passed", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"),
                        help="Godot executable path (or GODOT environment variable)")
    parser.add_argument("--timeout", type=int, default=120, help="seconds per check")
    parser.add_argument("--rendered", action="store_true",
                        help="run scene tests with native graphics instead of headless")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    engine = shutil.which(args.godot)
    if not engine:
        parser.error(f"Godot not found: {args.godot}")
    project = Path(__file__).resolve().parent.parent
    # Inherit neither a developer's test directory nor the player's save path.
    with tempfile.TemporaryDirectory(prefix="snake3d-check-") as directory:
        environment = dict(os.environ, SNAKE3D_TEST_DATA_DIR=directory)
        run(engine, project, environment, ["--import"], args.timeout)
        for scene, marker in [
            ("test_runner", "Smoke test passed"),
            ("gameplay_test", "Gameplay regression passed"),
        ]:
            run(engine, project, environment,
                ["--scene", f"res://scenes/{scene}.tscn"], args.timeout, marker, args.rendered)
    print("All project checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Verification failed: {error}", file=sys.stderr)
        sys.exit(1)
