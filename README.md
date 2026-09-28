# Circuit Bloom

A 2D biological-computer construction prototype in Godot 4.4.1 (GDScript, Mobile renderer). Grow a living circuit by connecting energy glands to processors, routing power through finite-capacity tissue, managing local heat, and unlocking substrate as sustained compute goals are met.

## Play

Open `project.godot` in Godot 4.4.1 and run. The initial organism computes immediately. Tap a part in the bottom palette, then tap an empty active cell. Drag with Conductive Tissue or Neural Bundle to paint. Tap **Select** to inspect. **Remove** refunds full biomass; the Bio Core is protected. The board stays editable while paused. On touch, drag with no paint tool to pan and pinch to zoom. On Windows, drag to pan, mouse wheel to zoom, and use Ctrl+Z/Ctrl+Y, Space, and Escape.

Top controls: undo, redo, power overlay, heat overlay, speed (1×/2×/4×), pause. A short first-run instruction panel dismisses on tap. The current goal and sustain timer appear under the HUD. After Awakening, play continues in sandbox.

## Implementation

- `scripts/Catalog.gd`: part data and progression thresholds.
- `scripts/Simulation.gd`: headless 24×24 model; deterministic routed power allocation with per-conductor capacity, capacitor energy storage, diffusion/cooling, thermal compute, milestones, snapshots.
- `scripts/Game.gd`: responsive code-drawn substrate/organs and HUD; touch/mouse interaction, undo/redo, JSON autosave in `user://circuit_bloom_v1.json`.
- `tests/run_tests.gd`: headless simulation checks.

The central 10×10 substrate grows to 14, 18, 22, then 24 cells across. Power, cooling, computation, and heat update every 0.2 simulation seconds. Milestone sustain uses the same clock. Parts are rendered from simulation data, with animated pulses only on loaded conductors. No external art or audio is needed.

## Builds

Pushes and manual GitHub Actions runs import the project, run tests, validate the main scene, and export Android and Windows builds. The Android application ID is `com.narmanb.circuitbloom`, with sensor landscape orientation allowing both landscape directions. Download `CircuitBloom-Android-debug.apk` and `CircuitBloom-Windows.zip` from the matching GitHub prerelease. GitHub Actions artifact storage is currently at its account quota, so the workflow attaches builds as release assets instead. Release signing can be added with a private keystore and Actions secrets; this workflow only targets debug APKs.

## Limits

Procedural visuals and UI need device playtesting, especially narrow landscape screens. The route allocator uses deterministic shortest paths and fixed priorities, not a globally optimal electrical flow solver. Sound, oxygen, nutrients, disease, and replication are outside this prototype.
