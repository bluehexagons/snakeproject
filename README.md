# Snake 3D

A 3D survival game built with Godot 4.7.2.

Move with **WASD or arrow keys**, collect glowing food, and avoid red walls and
red rocks. Each pickup adds a body piece, awards 10 points, increases cruising
speed slightly, and gives the snake a forward impulse. Gray rocks can be pushed;
body pieces are safe to cross. Releasing movement brakes the head. You can stop
without losing the run.

**Space** pauses gameplay, **Escape** opens the pause menu, and **F** switches
between overhead and angled arena views. Retry starts a fresh run after death.
Switching away from the window pauses and saves the run; resume explicitly when you return.
Menus support keyboard navigation with arrow keys, Tab, and Enter.
The pause menu returns to the main menu with a resumable save. Active games also
autosave every five seconds; best scores persist across runs. Focus loss also saves
when already paused. Holding a pause or camera key does not repeatedly toggle it.

## Gameplay systems

The head uses a rigid body with bounded acceleration and pickup impulses. Body
pieces follow its recorded path at fixed distance intervals, with visual growth
independent of gravity, collision shapes, and mass. Godot physics interpolation
smooths transforms. Both camera views keep the arena visible and control axes
stable. Rocks remain physics objects, and red hazards end the run on contact.

`GameManager` owns the session, spawning, scoring, and save/resume lifecycle.
`Player` emits gameplay signals and owns the body path; `Segment` displays each
piece. `GameState` handles persistence. `DebugTelemetry` is inert in release
builds. Saved paths preserve turns on resume; older saves reconstruct the path
from segment positions and restore fallen segments to the playing surface.
Rocks saved during their entrance animation resume at the same growth stage.
If a save has no food, replacements are placed after its rocks are restored.
When the arena is too crowded for safe placement, active play retries food
spawns on the five-second autosave interval.

## Verification

Use the standard (non-.NET) Godot **4.7.2** editor. The project uses the
Compatibility renderer and Jolt physics on Windows and Linux. No Basaltwater
installation is required. Open `project.godot` and run the main scene.

Automated verification requires **Python 3.10+** and Godot on PATH. On native
Windows, use PowerShell:

```powershell
.\scripts\verify_project.ps1
.\scripts\verify_project.ps1 -Rendered
# If Godot is not on PATH, select the console executable explicitly:
.\scripts\verify_project.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

On Linux or macOS:

```sh
./scripts/verify_project.sh
```

You can also invoke the shared runner directly from the project root:

```sh
python scripts/verify_project.py --godot godot --timeout 120
```

Use `python3` on systems where Python is installed under that name. `GODOT`
also selects the engine executable. The runner imports resources, then requires
successful completion of both smoke and gameplay regression scenes. Engine
errors, missing success markers, nonzero exits, and per-check timeouts fail
verification. On Windows, timeout cleanup includes the launcher's child engine.
Use `--rendered` (PowerShell: `-Rendered`) to run both scenes with native graphics.

Both saves and best scores go to a temporary directory through the debug-only
`SNAKE3D_TEST_DATA_DIR` override, which must be an existing absolute path. The
directory is removed after verification; no APPDATA or XDG overrides are needed.
Test scenes refuse to run against player saves. Release builds ignore this
override. Normal Windows saves remain in
`%APPDATA%\Godot\app_userdata\snake3d`; the project name stays stable to preserve
existing saves. Save replacement retains a `.bak` recovery copy before promoting
the new file. Continue, gameplay loading, and best-score loading use a valid
backup if the primary is missing or damaged. Subsequent writes preserve that
backup until a valid primary is available. Starting a new run or ending a run
clears the session's backup and temporary files as well, preventing an old
session from reappearing.

Coverage includes rapid pickups, forward impulses and their speed cap, turning,
grounded body persistence, recovery of fallen saved paths, braking, pause,
focus-loss save/pause, keyboard focus, save/resume ordering, inactivity, wall
death, interrupted or corrupt save recovery, recovery-file cleanup, key-repeat
handling, malformed save validation, rock entrance recovery, and food placement
around hazards and in crowded arenas. Headless tests do not establish GPU, sound,
or display scaling behavior; also check the native window on target hardware.

## Exporting

Install **4.7.2 export templates** from Godot's **Editor → Manage Export
Templates** before exporting. Create output folders first:

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --export-release 'Windows Desktop'
```

The x86-64 Windows preset writes `build/windows/snake3d.exe` and its companion
`.pck`; distribute them together. Test the release on Windows, including resizing,
Alt-Tab, keyboard menu navigation, pause/resume, and closing a live run. No signing
credentials are configured. The Web preset writes `build/web/index.html` (create
`build/web` first). Serve the generated web files through an HTTP server rather
than opening the HTML file directly. Build outputs are ignored by Git, and test
scenes and verification tools are excluded from both export presets.

On a Basaltwater host with the Godot web bundle, optionally export and publish
for browser testing:

```sh
basaltw agent doctor --capability development --json
basaltwater-web publish godot snake3d --preset Web --json
basaltwater-web doctor snake3d
```

Use the returned HTTPS URL with the session's configured browser tools, following
the shared `basaltwater-godot-web` skill. Native exports through Godot's Export
dialog remain available without the gateway. A separate `--debug` export
exposes bounded physics samples in `window.__godotPhysicsTrace` when Space pauses
a capture. Release builds do not collect or expose telemetry. For exact physics
regressions, use the project test scenes; browser screenshots establish appearance
and input behavior, not a hardware-independent frame-rate guarantee.
