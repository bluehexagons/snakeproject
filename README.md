# Snake 3D

A 3D survival game. Eat glowing food, grow your snake, and stay moving as
rocks fall into the arena.

[Play in your browser](https://bluehexagons.github.io/snakeproject/) or
[download the Windows build](https://github.com/bluehexagons/snakeproject/releases/latest).
On Windows, extract the ZIP and run `snake3d.exe` from the extracted folder.

## Controls

| Input | Steer | Pause | Camera |
| --- | --- | --- | --- |
| Keyboard | WASD or arrow keys | Esc for menu, Space for quick pause | F |
| Mouse | Hold the left button to steer toward the pointer | Pause button | Camera button |
| Touch | Touch the playfield and drag in the direction you want to move | Pause button | Camera button |
| Gamepad | Left stick or D-pad | Start/Menu | Y / Triangle |

Switch between overhead and angled views with the camera control. Navigate
menus with the arrow keys, Tab, and Enter, or the D-pad and A / Cross.

## How to survive

- Eating food adds a body piece, bumps up your cruising speed, and sends you
  into a short lunge. Faster pickups earn more points, from 10 to 30.
- Ground rings mark incoming rocks. A hard, direct hit during a lunge can
  shatter gray rocks. Red rocks, arena walls, and falling off the arena end
  the run. Blue body pieces can block you, and pieces that hit a wall turn
  red and become lethal to the head.
- Release steering to coast or steer in the opposite direction to brake and
  reverse. Once you start moving, keep making progress. If you stop or get
  pinned, the head changes color and a countdown warns you before the
  three-second timeout.

## Saved games

The game autosaves every five seconds during play. Switching away pauses
and saves the run. You can also return to the main menu from the pause menu
and choose **Continue** later. If saving fails while you try to leave, the
game stays paused so you can try again.

**New Game** replaces the saved run, and **Retry** starts a fresh run after
a loss. Your best score carries over. In the browser, use the same site and
browser profile to continue. On Windows, saves live in
`%APPDATA%\Godot\app_userdata\snake3d`.

## Project documentation

See the [technical documentation](docs/README.md) for setup, architecture,
testing, builds, and releases. See [Contributing](CONTRIBUTING.md) to report
a bug or submit a change.

## License

The project software and documentation use the [Apache License 2.0](LICENSE).
Original artwork and sound assets are dedicated to the public domain under
[CC0 1.0 Universal](LICENSE-CC0.txt). See the [asset inventory](docs/distribution/assets.md)
for the scope of the dedication and [NOTICE](NOTICE) for third-party attribution.
The Windows and Web release packages include the project and Godot license files.
