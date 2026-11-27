# Snake 3D repository guidance

This is a GDScript project targeting the standard Godot 4.7.2 editor,
Compatibility rendering, and Jolt physics. The [documentation index](docs/README.md)
links to local setup, architecture, testing, and release verification.

## Testing

- Run `./scripts/verify_project.sh` on Linux or macOS, or
  `.\scripts\verify_project.ps1` on Windows. Both use
  `scripts/verify_project.py`, which imports resources and runs both test scenes
  with isolated saves and best scores.
- Use `scripts/test_runner.gd` for focused smoke checks and
  `scripts/gameplay_test.gd` for regressions that need the live arena. Use
  controlled fixtures and physics frames for time-dependent gameplay checks.
- Use the rendered option when native graphics are relevant, and verify
  presentation or input changes in the affected game or export.
- Keep generated `.godot/` data, `build/` outputs, export credentials, and
  player saves out of Git. Keep Godot's tracked `.uid` and `.import` sidecars
  with their resources, and keep `build/.gdignore` so Godot skips exports.

## CI and releases

- CI runs headlessly on Linux and Windows. Preserve the shared runner and save
  isolation when changing either platform's entry point.
- Use `bash scripts/package_release.sh vMAJOR.MINOR.PATCH` on Linux to verify
  release packaging locally with the version from `project.godot`. It builds
  both presets and stages their license notices.
- Treat pushing a version tag as publishing. Use the tested commit on `main`,
  match the tag to the game and Windows version fields, and verify both the
  release asset and the Pages version after publication.
