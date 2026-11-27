# Development setup

Install the standard [Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/)
and Python 3.10 or newer. Python runs the verification scripts. Snake 3D uses
GDScript, Compatibility rendering, and Jolt physics.

1. Open [project.godot](../../project.godot) in Godot and wait for the initial
   import to finish.
2. Press **F5** to start at the main menu. Start a new game or continue a saved
   run from the menu.
3. Run the [local checks](testing.md) before submitting changes.

To run from a shell at the repository root, put the editor executable on
`PATH` as `godot` or substitute its full path. Import resources first on a
fresh checkout.

```sh
godot --headless --path . --import
godot --path .
```

On desktop, add `--rendering-method forward_plus` to enable volumetric fog.
Use the default renderer when checking Compatibility or Web behavior.

Install matching export templates if you need a Windows or Web build. See
the [local export instructions](../distribution/releases.md#local-exports).
