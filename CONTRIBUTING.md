# Contributing to Snake 3D

Use the standard [Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/)
and Python 3.10 or newer. Open `project.godot` and press **F5** to start at the
main menu.

## Project structure

- [GameManager](scripts/game_manager.gd) connects the arena and HUD, handles
  scoring and pause, and coordinates spawning, autosave, and resume. On
  resume, it places saved rocks before refilling food so placement accounts
  for restored hazards.
- [Player](scripts/player.gd) handles head movement, pickups, and the recorded
  body path. Each physics tick it walks the path from the head and assigns
  slots at fixed distances. [Segment](scripts/segment.gd) follows those slots,
  controls when growing pieces become solid, and handles body collisions.
- [GameState](scripts/game_state.gd) validates and stores runs and best
  scores. [SaveVector](scripts/save_vector.gd) defines the shared
  `{x, y, z}` representation and validates vector components. The player
  restores its own body and trail. Older saves without a recorded trail
  reconstruct it from the saved segment positions. Fallen pieces and their
  trail points are placed back at body height.
- [GameplaySteering](scripts/gameplay_steering.gd) handles gameplay input
  from keyboard, gamepad, mouse, and touch. [GameUI](scripts/ui.gd) adapts
  the HUD to the viewport and signals the playable area to the camera.
- [DebugTelemetry](scripts/debug_telemetry.gd) samples physics and aggregates
  contacts in Web debug exports. [SoundFx](scripts/sound_fx.gd) synthesizes
  and caches clips and limits simultaneous voices.

Save files use Godot's `user://` directory. A write stages a temporary file
before replacing the primary. If a valid backup is the only readable copy,
the next write preserves it. Test resume changes with older saves that omit
optional fields and with current saves that contain in-progress state such
as queued lunges and falling rocks.

## Local tests

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

- [Smoke test](scripts/test_runner.gd) covers resource loading, fresh spawn,
  save compatibility and recovery, and shared physics and audio behavior.
- [Gameplay regression](scripts/gameplay_test.gd) exercises the real arena,
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

The project uses Compatibility rendering and Jolt physics. On desktop, add
`--rendering-method forward_plus` to a game launch to enable volumetric fog.

## GitHub Actions

[CI](.github/workflows/ci.yml) runs the headless suite on GitHub-hosted Linux
and Windows runners for pull requests and pushes to `main`. The release
workflow calls the same CI workflow for the tagged commit. Both use the
[setup action](.github/actions/setup-godot/action.yml) to download and verify
the official editor. Release builds also install the Windows and single-threaded
Web templates.

When updating Godot, update the editor and template checksums in the setup
action, the source revision for bundled notices in the
[packaging script](scripts/package_release.sh), and the current engine version
in this guide, the README, and NOTICE. Run both test scenes and build both
presets with the new templates.

## Local exports

Install the matching templates with **Editor → Manage Export Templates**.
Choose a preset in **Project → Export**, or export from the command line.
Import resources first on a fresh checkout.

Export Windows from PowerShell.

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --import
godot --headless --path . --export-release 'Windows Desktop'
```

The preset writes `snake3d.exe` and `snake3d.pck` to `build/windows`.
Keep them together.

Export and serve the Web build from a POSIX shell.

```sh
mkdir -p build/web
godot --headless --path . --import
godot --headless --path . --export-release Web
python3 -m http.server --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8000/`. Keep the Web export files together on the host.
A Web export made with `--export-debug` records physics samples every 0.1
seconds. Use Space for quick pause to publish the current capture, or wait
for the 120-sample limit. Read the JSON string from
`window.__godotPhysicsTrace` in browser developer tools. Resuming from
quick pause starts a new capture.

The release packager can also run locally on Linux with Bash, `curl`, `zip`,
and matching Godot templates. Pass a tag-shaped version that matches the current
checkout. This only creates local artifacts.

```sh
bash scripts/package_release.sh v0.5.0
```

The script prints the fresh `build/release.*` directory containing the Windows
ZIP and the `web/` site. Both include the project and Godot notices.

## Publishing a release

1. Update `config/version` in `project.godot` and
   `application/file_version` and `application/product_version` in
   `export_presets.cfg`. For game version `0.4.1`, use `0.4.1.0` for both
   Windows fields.
2. Land the version changes on `main` and verify CI on the exact commit to
   release.
3. Push an annotated `vMAJOR.MINOR.PATCH` tag from that commit.

```sh
git tag -a v0.4.1 -m 'Snake 3D v0.4.1'
git push origin refs/tags/v0.4.1
```

The [release workflow](.github/workflows/release.yml) reruns CI on the tagged
commit, then checks that the commit is on `main` and that the game and Windows
versions match the tag. It builds the Windows x86-64 ZIP and Web export,
publishes the ZIP to GitHub Releases, and deploys the Web export to Pages if
the tag is GitHub's latest release. Pages uses **GitHub Actions** as its source.
The `github-pages` environment allows tags matching
`v[0-9]*.[0-9]*.[0-9]*`.

Check the Actions run, the Windows ZIP in Releases, and the version shown in
the Web game's main menu. The site also publishes
[`version.txt`](https://bluehexagons.github.io/snakeproject/version.txt) for an
HTTP check.

If publishing succeeds and Pages fails, rerun the failed jobs within seven
days while the Web artifact is still available. If a fix requires changing the
tagged commit, publish a new version from the corrected commit.
