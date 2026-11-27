# Architecture

[project.godot](../../project.godot) defines the startup scene, input actions,
autoloads, physics settings, and renderer. The game starts in the
[main menu](../../scenes/main_menu.tscn). **New Game** and **Continue** both
open the [arena scene](../../scenes/main.tscn) through the
[loading overlay](../../scenes/arena_loading.tscn). Retry uses the same loader.
New Game and Retry clear the current run after the arena resource is ready.
Continue loads a valid save. Desktop loads the resource on a worker thread.
The single-threaded Web export draws the overlay before loading on the main
thread.

## Arena and session

- [GameManager](../../scripts/game_manager.gd) connects the arena to the HUD
  and coordinates scoring, spawning, autosave, and resume. Playing, quick
  pause, menu pause, and game over are distinct session modes. Both pause
  modes suspend arena simulation. Game over disables steering and lets the
  arena continue in slow motion so the body can break apart.
- [ArenaSpawner](../../scripts/arena_spawner.gd) chooses placements for food
  and rocks based on clearance from the snake and other objects. Food
  placement falls back to a wider search when the center is crowded. The
  manager requests a refill after pickups and on the autosave interval.
- [GameplaySteering](../../scripts/gameplay_steering.gd) handles keyboard,
  mouse, touch, and gamepad steering. [GameUI](../../scripts/ui.gd) lays out
  the HUD and reports the available play area to
  [GameCamera](../../scripts/game_camera.gd), which fits the arena to it.

## Physics and feedback

- [Player](../../scripts/player.gd) drives head movement, sweeps the head's
  path for pickups, and records the trail. Each physics tick it walks the
  trail from the head and assigns body targets at fixed distances.
- [Segment](../../scripts/segment.gd) follows its target and enables collisions
  once it has grown and there is room for the full collider.
  [Rock](../../scripts/rock.gd) handles falling, landing, and shattering.
  Both share collision feedback and rigid-body behavior with
  [PhysicsObject](../../scripts/physics_object.gd).
- [SoundFx](../../scripts/sound_fx.gd) synthesizes and caches clips and limits
  simultaneous voices. [DebugTelemetry](../../scripts/debug_telemetry.gd)
  samples body state and aggregates contacts in
  [Web debug builds](testing.md#web-physics-traces).

## Rendering and interface

The [glass surface shader](../../shaders/glass_surface.gdshader) uses alpha blending and
view-dependent reflections for the snake, rocks, and food. It uses procedural
highlights without a screen texture, so moving bodies share the same shader
under Compatibility rendering. Physics objects keep their tint and impact
flash in per-object materials while sharing their meshes. The floor and
hazard walls use separate shaders for their translucent panes.

The main menu and HUD share [the arena theme](../../resources/arena_theme.tres)
for panel and button styling. Menu panels layer a
[glass reflection](../../resources/menu_glass.tres) behind their controls.

## Saved runs

[GameState](../../scripts/game_state.gd) validates and stores the run and best
score separately under Godot's `user://` directory. A write stages a
`.tmp` file and backs up the previous primary as `.bak` before replacement.
Loading tries the backup if the primary is missing or invalid. The next write
preserves the backup when the primary is unreadable.

[SaveVector](../../scripts/save_vector.gd) validates and serializes vectors as
`{x, y, z}`. Saves use the body's live position and velocity. Older saves
can contain optional position aliases. Player restores its own body and trail,
reconstructing a missing trail from saved segment positions and placing fallen
body pieces and trail points back at body height. The manager restores saved
rocks before refilling food so placement accounts for hazards already present.

When changing persistence, check an older save with missing optional fields
and a current save with in-progress state such as a queued lunge or a falling
rock. See [Testing](testing.md) for the isolated save fixtures.
