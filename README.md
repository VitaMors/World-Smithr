# World Smithr

World Smithr is a Godot 4 Web-first, low-poly 3D world-map editor. The starting blueprint used the working name "WorldSmith"; this project uses **World Smithr** for the product name and `world_smithr` for new save-format identifiers.

This repository currently contains Phase 1 from the blueprint: a runnable Godot project shell, editor-style layout, orbit/pan/zoom camera rig, service placeholders, one generated editable terrain chunk, terrain collision/ray picking, Raise/Lower/Smooth/Flatten sculpting, and one-stroke undo/redo.

## Requirements

- Godot 4.x with the Compatibility renderer.
- Desktop Chrome, Edge, or Firefox for Web export testing.
- A static HTTPS host for production Web builds.

Godot C# and native extensions are intentionally avoided so the project can export to Web.

## Run Native

Open the folder in Godot, or run:

```powershell
godot --path .
```

The main scene is:

```text
res://main/main.tscn
```

## Smoke Test

```powershell
godot --headless --path . --script res://tests/smoke_test.gd
```

The smoke test currently covers chunk coordinate conversion, terrain height storage, terrain mesh generation, and the Phase 0 streaming-window bookkeeping.

## Phase 1 Controls

- Select `Sculpt` in the left rail.
- Left mouse drag on terrain: apply the selected sculpt brush.
- Sculpt modes: Raise, Lower, Smooth, Flatten.
- Shift while dragging Raise or Lower: temporarily invert the direction.
- Brush radius, strength, and falloff are in the right panel.
- Top bar `Undo` and `Redo`: replay whole sculpt strokes.
- Middle mouse drag: orbit.
- Shift + middle mouse drag: pan.
- Mouse wheel: zoom.
- F: frame the starter chunk.
- 1: angled perspective view.
- 2: top orthographic view.

## Export Web

Export with the preset named `Web`:

```powershell
godot --headless --path . --export-release Web build/web/index.html
```

Serve the generated `build/web` directory from a local or hosted web server. Browser storage is expected to use Godot's `user://` path backed by IndexedDB; later phases will add explicit persistence warnings, import, and export controls.

## Deploy With GitHub Pages

This repo includes `.github/workflows/pages.yml`, which deploys the checked-in Godot Web export in `build/web` to GitHub Pages using GitHub's official Pages artifact flow. If `build/web/index.html` is not present yet, the workflow exits successfully with a notice and skips deployment.

1. Export the Web build to `build/web/index.html`.
2. Commit `build/web` together with the project files.
3. Push to the `main` branch, or `master` if that is the repository default.
4. In GitHub, open repository Settings > Pages, then set Build and deployment > Source to `GitHub Actions`.
5. Run the `Deploy Godot Web to GitHub Pages` workflow, or let it run on push.

References:

- GitHub Pages publishing source: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- GitHub Pages custom workflows: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages

## Next Phase

Phase 2 should expand the single terrain chunk into a seam-safe 3x3 world with canonical shared border samples, cross-boundary brushes, chunk debug colours, and coordinate labels.


