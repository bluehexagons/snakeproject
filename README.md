# Snake 3D

A 3D survival game built with Godot 4.7.2.

Move with **WASD or arrow keys**, collect glowing food, and avoid red walls and
red rocks. Each pickup adds a body piece, awards 10 points, increases cruising
speed slightly, and gives the snake a forward impulse. Gray rocks can be pushed;
body pieces are safe to cross. Releasing movement brakes the head. You can stop
without losing the run.

**Space** pauses gameplay, **Escape** opens the pause menu, and **F** switches
between overhead and angled arena views. Retry starts a fresh run after death.
The pause menu returns to the main menu with a resumable save. Active games also
autosave every five seconds; best scores persist across runs.

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

## Verification

Open the project in Godot 4.7.2 with matching export templates and run the main scene. Run automated checks with:

```sh
./scripts/verify_project.sh
```

The script imports resources and runs smoke and gameplay regression scenes in a
temporary user-data directory, leaving real saves untouched. Gameplay coverage
includes rapid pickups, forward impulses and their speed cap, turning, grounded
body persistence, recovery of fallen saved paths, braking, pause, save/resume
ordering, inactivity, and wall death. Smoke checks also reject malformed save
fields consistently in both the Continue menu and gameplay loader.

Basaltwater on Debian is the reference development environment, following the
[shared project standards](https://github.com/bluehexagons/basaltwater/blob/main/docs/agents/project-standards.md).
The editor also supports native development on CachyOS and Windows 11 without
Basaltwater. Run the verification script with Bash and Linux `godot` on PATH
(including inside WSL); its temporary `XDG_DATA_HOME` isolates Linux saves.
Native Windows editor and export testing is a separate manual check. Use matching
export templates for the selected Godot version.

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
