# Snake 3D

A 3D survival game built with Godot 4.7.2.

[Play in your browser](https://bluehexagons.github.io/snakeproject/) or
[download the Windows build](https://github.com/bluehexagons/snakeproject/releases/latest).

## Getting started

Open `project.godot` in the [standard Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/)
and press **F5** to run the game. The project uses GDScript, the Compatibility
renderer, and Jolt physics.

## Controls and gameplay

Collect glowing food and avoid red walls and red rocks.

| Input | Steer | Pause | Camera |
| --- | --- | --- | --- |
| Keyboard | WASD or arrow keys | Esc for menu, Space for quick pause | F |
| Mouse | Hold the left button to steer toward the pointer | Pause button | Camera button |
| Touch | Touch the playfield and drag in the direction you want to move | Pause button | Camera button |
| Gamepad | Left stick or D-pad | Start/Menu | Y / Triangle |

Each pickup adds a body piece, awards 10 to 30 points based on your
speed, increases cruising speed slightly, and gives the snake a forward impulse.
The head bumps into blue body pieces, and rocks can deflect the body. A piece
that hits a wall turns red and is lethal to the head. Release movement to coast
and gradually stop, or hold the opposite direction to brake and reverse into
your own body. Once you start moving, make steady progress to survive. If
you stop or get pinned, the head changes color and a countdown warns you
before the three-second timeout.

Ground rings mark incoming rocks and expand briefly on impact.
Impacts flash briefly. Gray rocks shatter only on a hard, direct hit during
the brief lunge from eating. Red rocks and falling out of the arena are lethal.
Food can be collected during small bounces, and solid obstacles block pickups.
Food that stays trapped inside a rock is moved to a clear spot.

The Camera button switches between overhead and angled arena views.
Retry starts a fresh run after death.
Switching away from the window pauses and saves the run. Resume explicitly
when you return.
Navigate menus with the arrow keys, Tab, and Enter or the D-pad and A / Cross.
The pause menu returns to the main menu with a resumable save. If an exit save
fails, the game stays paused so you can try again. Active games autosave every
five seconds, and best scores persist across runs. Focus loss also saves
when already paused. Holding a pause or camera key does not repeatedly toggle it.

## Saved games

Use **Continue** on the main menu to pick up where you left off. **New Game**
replaces the saved run and keeps your best score. The browser build keeps
saves in site storage, so use the same site and browser profile to continue.
On Windows, saves live in `%APPDATA%\Godot\app_userdata\snake3d`. If a save
or best-score file is missing or damaged, the game tries its backup.

## Contributing

See the [contributor guide](CONTRIBUTING.md) for the project structure, local
tests, manual exports, and tagged releases.

## License

The game code and assets are licensed under the [Apache License 2.0](LICENSE).
See [NOTICE](NOTICE) for attribution.

When distributing builds, include the project license and notice, the
[Godot Engine license](https://godotengine.org/license/), and the
[third-party notices for Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt).
For a hosted Web build, make these files available alongside the game.
