# Snake 3D

A 3D survival game built with Godot 4.7.

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

Open the project in Godot 4.7 and run the main scene. Run automated checks with:

```sh
./scripts/verify_project.sh
```

The script imports resources and runs smoke and gameplay regression scenes in a
temporary user-data directory, leaving real saves untouched. Gameplay coverage
includes rapid pickups, forward impulses and their speed cap, turning, grounded
body persistence, recovery of fallen saved paths, braking, pause, save/resume
ordering, inactivity, and wall death. Smoke checks also reject malformed save
fields consistently in both the Continue menu and gameplay loader.

On an infra-tools VM, export and publish for browser testing:

```sh
infra-tools agent doctor --capability development --json
infra-web publish godot --preset Web --json
infra-web doctor snake3d
```

Use the returned HTTPS URL with managed Playwright. A separate `--debug` export
exposes bounded physics samples in `window.__godotPhysicsTrace` when Space pauses
a capture. Release builds do not collect or expose telemetry. For exact physics
regressions, use the project test scenes; browser screenshots establish appearance
and input behavior, not a hardware-independent frame-rate guarantee.
