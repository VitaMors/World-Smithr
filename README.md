# World Smithr

World Smithr is a Godot 4 Web-first, low-poly 3D world-map editor. The starting blueprint used the working name "WorldSmith"; this project uses **World Smithr** for the product name and `world_smithr` for new save-format identifiers.

This repository currently contains Phase 0 from the blueprint: a runnable Godot project shell, editor-style layout, orbit/pan/zoom camera rig, service placeholders, a Web export preset, and a small smoke test. Terrain editing intentionally starts in Phase 1.

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

The smoke test currently covers chunk coordinate conversion and the Phase 0 streaming-window bookkeeping.

## Export Web

Export with the preset named `Web`:

```powershell
godot --headless --path . --export-release Web build/web/index.html
```

Serve the generated `build/web` directory from a local or hosted web server. Browser storage is expected to use Godot's `user://` path backed by IndexedDB; later phases will add explicit persistence warnings, import, and export controls.

## Phase 0 Controls

- Middle mouse drag: orbit.
- Shift + middle mouse drag: pan.
- Mouse wheel: zoom.
- F: frame the starter chunk.
- 1: angled perspective view.
- 2: top orthographic view.

## Next Phase

Phase 1 should add one editable terrain chunk: `ChunkData` height storage, a 33x33-vertex `ArrayMesh`, terrain collision/ray picking, Raise/Lower/Smooth/Flatten brushes, and one-stroke undo/redo.
