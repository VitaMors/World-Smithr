# World Smithr

World Smithr is a Godot 4 Web-first, low-poly 3D world-map editor. The starting blueprint used the working name "WorldSmith"; this project uses **World Smithr** for the product name and `world_smithr` for new save-format identifiers.

This repository currently contains Phase 3 from the blueprint: a runnable Godot project shell, editor-style layout, orbit/pan/zoom camera rig, a seam-safe editable terrain system, a 5x5 streamed chunk window, Active/Warm/Unloaded chunk states, canonical global height samples shared across chunk borders, cross-boundary Raise/Lower/Smooth/Flatten sculpting, debug chunk colours/labels, and one-stroke undo/redo across affected chunks.

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

The smoke test currently covers chunk coordinate conversion, canonical shared border samples, four-chunk corner ownership, terrain height storage, terrain mesh generation, 5x5 streaming counts, cardinal/diagonal chunk-set diffs, negative chunk coordinates, and rebuild queue de-duping.

## Phase 3 Controls

- Select `Sculpt` in the left rail.
- Left mouse drag on active terrain: apply the selected sculpt brush.
- Sculpt across chunk edges or four-way corners: shared global samples update all affected chunk meshes.
- Sculpt modes: Raise, Lower, Smooth, Flatten.
- Shift while dragging Raise or Lower: temporarily invert the direction.
- Brush radius, strength, and falloff are in the right panel.
- Top bar `Undo` and `Redo`: replay whole sculpt strokes, including multi-chunk strokes.
- Middle mouse drag: orbit.
- Shift + middle mouse drag: pan. The editor camera pivot is the Build-mode streaming focus.
- Mouse wheel: zoom.
- F: frame the starter chunk.
- 1: angled perspective view.
- 2: top orthographic view.

## Streaming Model

- Active chunks: Chebyshev distance 0-1 from the focus, 9 chunks maximum, visible and collision-enabled.
- Warm chunks: Chebyshev distance 2 from the focus, 16 chunks maximum, visible and collision-disabled.
- Loaded chunks: the full 5x5 neighbourhood, 25 chunks maximum.
- Unloaded chunks: distance 3+, no scene nodes.
- Focus changes are diffed, so crossings create/promote/demote/unload only the changed coordinates.
- Terrain mesh rebuilds are queued and processed with a small per-frame budget.

## Local Web Export

Export with the preset named `Web`:

```powershell
godot --headless --path . --export-release Web dist/web/index.html
```

Serve the generated `dist/web` directory from a local or hosted web server. Browser storage is expected to use Godot's `user://` path backed by IndexedDB; later phases will add explicit persistence warnings, import, and export controls.

## Deploy With GitHub Pages

This repo includes `.github/workflows/pages.yml`, which builds the Godot Web export in GitHub Actions and deploys the generated `dist/web` output to GitHub Pages. Do not commit a placeholder `index.html`; the workflow downloads Godot 4.7.1 and the matching export templates, exports the project, then publishes the real app.

1. Commit and push the project source files.
2. In GitHub, open repository Settings > Pages, then set Build and deployment > Source to `GitHub Actions`.
3. Open the Actions tab and run `Build and Deploy Godot Web`, or let it run on push to `main` or `master`.
4. When the workflow is green, the Pages URL appears in the deployment summary and in Settings > Pages.

References:

- GitHub Pages publishing source: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- GitHub Pages custom workflows: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- Godot command line export: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Godot Web export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html

## Next Phase

Phase 4 should add save/open/import/export: versioned world manifests, independent chunk records, delayed autosave, recovery snapshots, portable ZIP import/export, and persistence warnings.
