# Testing

Run the same headless checks as CI from the project root. On Linux or macOS,
use Bash and `python3`.

```sh
./scripts/verify_project.sh
./scripts/verify_project.sh --rendered
```

On Windows, use PowerShell and `python`.

```powershell
.\scripts\verify_project.ps1
.\scripts\verify_project.ps1 -Rendered
.\scripts\verify_project.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

By default the wrappers look for `godot` on PATH. Set `GODOT` to select another
executable, or pass it explicitly to the shared runner.

```sh
python3 scripts/verify_project.py --godot godot --timeout 120
```

The runner imports resources headlessly, then runs both test scenes.

- [Smoke test](../../scripts/test_runner.gd) covers resource loading, fresh spawn,
  save compatibility and recovery, and shared physics and audio behavior.
- [Gameplay regression](../../scripts/gameplay_test.gd) exercises the real arena,
  including movement, growth, pickups, rock and body collisions, pause,
  save/resume, and game over.

Each check has a 120-second default timeout. Engine errors, nonzero exits,
timeouts, and missing success markers fail verification. Windows timeout
cleanup also stops the console executable's child engine process.

The runner creates a temporary directory and sets the debug-only
`SNAKE3D_TEST_DATA_DIR` for saves and best scores. Both test scenes require
this isolation. The override must be an existing absolute path, and release
builds ignore it. Keep player saves out of test fixtures.

Rendered mode uses native graphics for the two test scenes and requires a
working display. For visual, audio, or input changes, also play the affected
flow in a normal game window or in the relevant export.

## GitHub Actions

[CI](../../.github/workflows/ci.yml) runs the headless suite on GitHub-hosted Linux
and Windows runners for pull requests and pushes to `main`. The release
workflow calls the same CI workflow for the tagged commit. Both use the
[setup action](../../.github/actions/setup-godot/action.yml) to download and verify
the official editor. Release builds also install the Windows and single-threaded
Web templates.

## Web physics traces

Use the matching Web templates and run these commands from the repository root.

```sh
mkdir -p build/web-debug
godot --headless --path . --import
godot --headless --path . --export-debug Web build/web-debug/index.html
python3 -m http.server --bind 127.0.0.1 --directory build/web-debug
```

Open `http://127.0.0.1:8000/` and start a run. The debug build samples body
state every 0.1 seconds and aggregates contact impulses between samples.
Press Space to quick-pause and publish the capture, or wait for the 120-sample
limit. Read the JSON string from `window.__godotPhysicsTrace` in browser developer
tools. Pressing Space again to resume starts a new capture. Use the release
export when checking the build players will receive.
