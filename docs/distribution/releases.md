# Building and releasing Snake 3D

## Local exports

Install the matching templates with **Editor → Manage Export Templates**.
Choose a preset in **Project → Export**, or export from the command line.
Import resources first on a fresh checkout.

Export Windows from PowerShell.

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot --headless --path . --import
godot --headless --path . --export-release 'Windows Desktop'
```

The preset writes `snake3d.exe` and `snake3d.pck` to `build/windows`.
Keep them together.

Export and serve the Web build from a POSIX shell.

```sh
mkdir -p build/web
godot --headless --path . --import
godot --headless --path . --export-release Web
python3 -m http.server --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8000/`. Keep the Web export files together on the host.

## Build release packages

The [release packager](../../scripts/package_release.sh) runs on Linux with Bash, `curl`, `zip`,
and matching Godot templates. Pass a tag-shaped version that matches the current
checkout. This only creates local artifacts.

```sh
bash scripts/package_release.sh v0.5.0
```

The script prints the fresh `build/release.*` directory containing the Windows
ZIP and the `web/` site. Each contains `LICENSE`, `LICENSE-CC0.txt`,
`docs/distribution/assets.md`, `NOTICE`, `GODOT_LICENSE.txt`, and
`GODOT_COPYRIGHT.txt`.
Use the packaged output when redistributing a build so the license files
stay with the game.

## Publishing a release

1. Update `config/version` in `project.godot` and
   `application/file_version` and `application/product_version` in
   `export_presets.cfg`. For game version `0.4.1`, use `0.4.1.0` for both
   Windows fields.
2. Land the version changes on `main` and verify CI on the exact commit to
   release.
3. Push an annotated `vMAJOR.MINOR.PATCH` tag from that commit.

```sh
git tag -a v0.4.1 -m 'Snake 3D v0.4.1'
git push origin refs/tags/v0.4.1
```

The [release workflow](../../.github/workflows/release.yml) reruns CI on the tagged
commit, then checks that the commit is on `main` and that the game and Windows
versions match the tag. It builds the Windows x86-64 ZIP and Web export,
publishes the ZIP to GitHub Releases, and deploys the Web export to Pages if
the tag is GitHub's latest release. Pages uses **GitHub Actions** as its source.
The `github-pages` environment allows tags matching
`v[0-9]*.[0-9]*.[0-9]*`.

Check the Actions run, the Windows ZIP in Releases, and the version shown in
the Web game's main menu. Confirm the license files are present in the ZIP
and accessible alongside the Web build. The site also publishes
[`version.txt`](https://bluehexagons.github.io/snakeproject/version.txt) for an
HTTP check.

If publishing succeeds and Pages fails, rerun the failed jobs within seven
days while the Web artifact is still available. If a fix requires changing the
tagged commit, publish a new version from the corrected commit.

## Updating Godot

Update the editor and template checksums in the
[setup action](../../.github/actions/setup-godot/action.yml), the pinned source
revision for bundled notices in the [packaging script](../../scripts/package_release.sh),
and the documented engine version in [Development setup](../development/setup.md),
[AGENTS.md](../../AGENTS.md), [Copilot instructions](../../.github/copilot-instructions.md),
and [NOTICE](../../NOTICE). Run the headless suite and build both presets with
the new templates.
