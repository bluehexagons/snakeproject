# Snake 3D

A 3D survival game built with Godot 4.7.2.

## Getting started

Open `project.godot` in the [standard Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/)
and press **F5** to run the game. The project uses GDScript, the Compatibility
renderer, and Jolt physics.

## Controls and gameplay

Move with **WASD or arrow keys**, collect glowing food, and avoid red walls and
red rocks. Each pickup adds a body piece, awards 10 to 30 points based on your
speed, increases cruising speed slightly, and gives the snake a forward impulse.
The head bumps into blue body pieces, and rocks can deflect the body. A piece
that hits a wall turns red and is lethal to the head. The head coasts when you
release movement. Once you start moving, make steady progress to survive. If
you stop or get pinned, the head changes color and a countdown warns you
before the three-second timeout.

Ground rings mark incoming rocks and expand briefly on impact.
Impacts flash briefly. Gray rocks shatter only on a hard, direct hit during
the brief lunge from eating. Red rocks and falling out of the arena are lethal.
Food can be collected during small bounces, and solid obstacles block pickups.
Food that stays trapped inside a rock is moved to a clear spot.

**Space** pauses gameplay, **Escape** opens the pause menu, and **F** switches
between overhead and angled arena views. Retry starts a fresh run after death.
Switching away from the window pauses and saves the run; resume explicitly when you return.
Menus support keyboard navigation with arrow keys, Tab, and Enter.
The pause menu returns to the main menu with a resumable save. If an exit save
fails, the game stays paused so you can try again. Active games autosave every
five seconds, and best scores persist across runs. Focus loss also saves
when already paused. Holding a pause or camera key does not repeatedly toggle it.

## Gameplay systems

The head builds speed gradually and carries it through wider turns. Pressing the
opposite direction brakes before reversing. Body pieces retain some sideways
motion from hits as they return to the recorded path. Rocks and detached pieces
keep rolling after impact. A new piece becomes solid once it has grown and has
room for its collider. The body breaks apart on death.
Godot physics interpolation smooths transforms. Both camera views keep the arena
visible and control axes stable.

## Rendering

The arena uses procedural PBR materials, emissive rails, a moving backdrop,
screen-space ambient occlusion, and glow. Gold rings and local lighting mark
pickups. Red rails and rocks mark hazards, and the snake's visor shows its
heading. The angled view uses transparent hazard walls to keep the floor visible.

The default Compatibility renderer shares this presentation with the web build.
On desktop, launch Godot with `--rendering-method forward_plus` to render the
arena with volumetric fog.

## Sound

The game synthesizes glassy bells for pickups, impacts, shattering, warnings,
and menus. Pickups cycle through a pentatonic scale. Heavy knocks ring louder
and lower, with different tones for body and rock contacts. `SoundFx` caches
the generated clips and limits simultaneous voices during busy collisions.

## Runtime

`GameManager` owns the session, spawning, scoring, and save/resume lifecycle.
`Player` emits gameplay signals and owns the body path. `Segment` handles body
movement, collisions, and growth. `GameState` handles persistence. `DebugTelemetry`
is inert in release builds. Saved paths preserve turns on resume, and older
saves reconstruct the path from segment positions. Fallen segments return to
the playing surface. Saves preserve queued lunges, active pickup boosts, the
digestion pulse, and the current inactivity sample. Solid segments keep their
collision and velocity when resumed.
Rocks saved mid-drop resume with their position, velocity, and ground marker.
When resuming, the game refills food after restoring the rocks. If the center
is crowded, placement searches farther out while keeping clear of obstacles.
Active play retries any missing spawns on the five-second autosave interval.
New rocks and food leave room around the snake's body.

## Verification

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

Coverage includes rapid pickups, speed-based scoring, capped forward impulses,
momentum through turns and after releasing input, reversals, diagonal steering,
body deflection and free rolling, head and rock contact with the body, rock
impacts and breakage, wall-touched pieces turning lethal,
grounded body persistence, recovery of fallen saved paths, braking, pause,
focus-loss save/pause, keyboard focus, save/resume ordering, momentum, stuck warnings,
recovery, loss while stopped or blocked, arena falls, death and body breakup,
interrupted or corrupt save recovery, recovery-file cleanup, key-repeat
handling, malformed save validation, rock entrance recovery, and pickups and
spawns around obstacles. Headless tests do not establish GPU, sound,
or display scaling behavior; also check the native window on target hardware.

## Exporting

Install **4.7.2 export templates** from Godot's **Editor → Manage Export
Templates** before exporting. Create the output directory and export from the
project root, or select a preset in Godot's **Project → Export** dialog.

Export Windows from PowerShell with these commands.

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --export-release 'Windows Desktop'
```

The x86-64 Windows preset produces `snake3d.exe` and `snake3d.pck` in
`build/windows`. Keep both files together.

Export Web from a POSIX shell with these commands.

```sh
mkdir -p build/web
godot --headless --path . --export-release Web
python3 -m http.server --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8000/` to play the local Web export. Keep all generated
web files together when hosting the build. Both presets exclude the test
scenes and verification scripts. Git ignores the `build/` directory.

A Web export made with `--export-debug` exposes a local physics sample buffer
in `window.__godotPhysicsTrace` when Space pauses a capture.

## License

The game code and assets are licensed under the [Apache License 2.0](LICENSE).
See [NOTICE](NOTICE) for attribution.

When distributing builds, include the project license and notice, the
[Godot Engine license](https://godotengine.org/license/), and the
[third-party notices for Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt).
For a hosted Web build, make these files available alongside the game.
