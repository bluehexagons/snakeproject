# Snake 3D

A physics-driven 3D survival game built with Godot 4.7.

## Architecture

The main scene owns the game session. `GameManager` coordinates session state,
connects the UI to gameplay actions, and binds the current `Player` instance to
its gameplay signals. The player reports food collection, score, and loss
events instead of looking up the manager through the scene tree. Food receives
its consuming target explicitly, and the UI communicates through signals.

`GameState` and `CollisionHandler` are the only runtime autoload services.
`PhysicsConstants`, `SegmentConstants`, and `ChainPhysics` are pure script
classes, so constants and force calculations do not require hidden scene-node
lifecycle state.

## Running

Open the project in Godot 4.7 and run the main scene. The headless smoke test
can be run with:

```sh
godot --headless --path . --scene res://scenes/test_runner.tscn
```
