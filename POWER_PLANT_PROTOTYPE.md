# Circuit Bloom — Power Plant Prototype

This branch re-themes the existing Circuit Bloom simulation as a power-plant construction prototype while deliberately preserving the proven routing/thermal simulation underneath.

## Prototype loop

- **Boilers** raise process steam.
- **Steam Pipes / Main Steam Headers** route it with real segment throughput limits.
- **Turbine Generators / Turbine Blocks** consume steam and produce MW.
- **Cooling Towers / Condenser Trains** control local heat and thermal throttling.
- **Steam Accumulators** store surplus and support short demand spikes.
- Sustained MW milestones expand the usable central yard and construction budget.

The generated power-station artwork is used as an actual image background (`assets/power_plant_background.jpg`). Equipment is currently rendered procedurally in GDScript so the gameplay can be tested before final asset production.

## Android prototype

The Android package is intentionally separate from the motherboard prototype:

`com.narmanb.circuitbloom.powerplant`

This lets both versions remain installed at the same time during theme comparison.
