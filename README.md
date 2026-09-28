# Circuit Bloom

A 2D motherboard and living city construction prototype in Godot 4.4.1 (GDScript, Mobile renderer). Grow a circuit district by connecting power nodes to processor chips, routing power through finite capacity copper traces, managing local heat, and expanding the board as sustained compute goals are met.

## Play

Open `project.godot` in Godot 4.4.1 and run. The initial board computes immediately. Choose a category in the left rail; its larger part cards open to the right. Tap a part, then tap an empty active cell. Drag with Copper Trace or Bus Lane to paint. **Select** inspects and pans. **Remove** refunds the full build capacity; the Core Socket is protected. The board stays editable while paused. On touch, drag with no paint tool to pan and pinch to zoom. On Windows, drag to pan, mouse wheel to zoom, and use Ctrl+Z/Ctrl+Y, Space, and Escape.

Top controls: undo, redo, power overlay, heat overlay, speed (1×/2×/4×), pause. Tap each top telemetry card for its meaning and practical advice. The four cards show computation, power delivery, headroom, and hottest cell; build capacity is in the rail and status strip. The right inspector shows selected component state, output, power, local temperature, and part-specific details. Power offers a compact 40 power node and an 80 power reactor unlocked after First Pulse; the reactor adds substantially more heat. A short first-run instruction panel dismisses on tap. The current goal and sustain timer appear under the HUD. After Awakening, play continues in sandbox.

## Implementation

- `scripts/Catalog.gd`: part data and progression thresholds.
- `scripts/Simulation.gd`: headless 24×24 model; deterministic routed power allocation with per-conductor capacity, capacitor energy storage, diffusion/cooling, thermal compute, milestones, snapshots.
- `scripts/Game.gd`: input, camera, undo/redo and JSON autosave in `user://circuit_bloom_v1.json`.
- `scripts/rendering/BoardArt.gd`: code-drawn green solder mask, gold and copper routing, silver sockets and fins, colored chip packages, silkscreen, vias, slots, animated current, heat and power overlays.
- `scripts/ui/InterfaceArt.gd`: tappable metric explanations, cascading category rail, part cards and inspector.
- `tests/run_tests.gd`: headless simulation checks.

The central 10×10 substrate grows to 14, 18, 22, then 24 cells across. Power, cooling, computation, and heat update every 0.2 simulation seconds. Milestone sustain uses the same clock. Parts are rendered from simulation data, with animated pulses only on loaded conductors. No external art or audio is needed.

## Builds

Pushes and manual GitHub Actions runs import the project, run tests, validate the main scene, and export an Android debug APK. Windows has an export preset and can be built on request; it is not part of routine CI. The Android application ID is `com.narmanb.circuitbloom`, with sensor landscape orientation allowing both landscape directions. Download `CircuitBloom-Android-debug.apk` from the matching GitHub prerelease. GitHub Actions artifact storage is currently at its account quota, so the workflow attaches builds as release assets instead. The checked-in `ci/debug.keystore.b64` is a fixed test-only signing key, so subsequent debug builds can install as updates. Builds before this key was introduced used a fresh ephemeral key and cannot be updated in place; those earlier installs must be uninstalled once. Release signing requires a separate private key held outside the repository.

## Limits

Procedural visuals and UI need device playtesting, especially narrow landscape screens. The route allocator uses deterministic shortest paths and fixed priorities, not a globally optimal electrical flow solver. Sound, oxygen, nutrients, disease, and replication are outside this prototype.
