# Circuit Bloom

A 2D motherboard-and-living-circuit construction prototype in Godot 4.4.1 (GDScript, Mobile renderer). Grow a living circuit by connecting energy glands to processors, routing power through finite-capacity tissue, managing local heat, and unlocking substrate as sustained compute goals are met.

## Play

Open `project.godot` in Godot 4.4.1 and run. The initial organism computes immediately. Choose a category in the bottom dock, tap a labeled part card, then tap an empty active cell. Drag with Conductive Tissue or Neural Bundle to paint. Tap **Select** to inspect. **Remove** refunds full biomass; the Bio Core is protected. The board stays editable while paused. On touch, drag with no paint tool to pan and pinch to zoom. On Windows, drag to pan, mouse wheel to zoom, and use Ctrl+Z/Ctrl+Y, Space, and Escape.

Top controls: undo, redo, power overlay, heat overlay, speed (1×/2×/4×), pause. The top telemetry cards show computation, power delivery, headroom, biomass, and hottest cell. The right inspector shows selected component state, output, power, local temperature, and part-specific details. A short first-run instruction panel dismisses on tap. The current goal and sustain timer appear under the HUD. After Awakening, play continues in sandbox.

## Implementation

- `scripts/Catalog.gd`: part data and progression thresholds.
- `scripts/Simulation.gd`: headless 24×24 model; deterministic routed power allocation with per-conductor capacity, capacitor energy storage, diffusion/cooling, thermal compute, milestones, snapshots.
- `scripts/Game.gd`: input, camera, undo/redo and JSON autosave in `user://circuit_bloom_v1.json`.
- `scripts/rendering/BoardArt.gd`: code-drawn PCB traces, vias, chip packages, organic signals, heat and power overlays.
- `scripts/ui/InterfaceArt.gd`: metric cards, category dock, part previews and inspector.
- `tests/run_tests.gd`: headless simulation checks.

The central 10×10 substrate grows to 14, 18, 22, then 24 cells across. Power, cooling, computation, and heat update every 0.2 simulation seconds. Milestone sustain uses the same clock. Parts are rendered from simulation data, with animated pulses only on loaded conductors. No external art or audio is needed.

## Builds

Pushes and manual GitHub Actions runs import the project, run tests, validate the main scene, and export an Android debug APK. Windows has an export preset and can be built on request; it is not part of routine CI. The Android application ID is `com.narmanb.circuitbloom`, with sensor landscape orientation allowing both landscape directions. Download `CircuitBloom-Android-debug.apk` from the matching GitHub prerelease. GitHub Actions artifact storage is currently at its account quota, so the workflow attaches builds as release assets instead. The checked-in `ci/debug.keystore.b64` is a fixed test-only signing key, so subsequent debug builds can install as updates. Builds before this key was introduced used a fresh ephemeral key and cannot be updated in place; those earlier installs must be uninstalled once. Release signing requires a separate private key held outside the repository.

## Limits

Procedural visuals and UI need device playtesting, especially narrow landscape screens. The route allocator uses deterministic shortest paths and fixed priorities, not a globally optimal electrical flow solver. Sound, oxygen, nutrients, disease, and replication are outside this prototype.
