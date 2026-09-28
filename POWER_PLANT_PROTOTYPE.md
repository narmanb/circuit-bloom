# Circuit Bloom — Power Plant Prototype

This branch is a playable Godot 4.4.1 prototype of the power-plant direction.

## Visual direction

The yard uses a generated industrial power-station image as the actual background (`assets/power_plant_background.jpg`). The central construction area remains open. Gameplay equipment is currently procedural GDScript art so the loop can be tested before final sprite production.

The layout follows the preferred reference: a wide top telemetry HUD, a right-side build panel, a large central yard, and compact bottom tools.

## Loop

1. Boilers raise process steam.
2. Steam Pipes / Main Steam Headers route it with per-segment throughput limits.
3. Turbine Generators consume delivered steam and produce gross MW.
4. Step-Up Transformers and Switchyard Bays set grid export capacity.
5. Cooling Towers / Condenser Trains fight local heat and turbine derating.
6. Steam Accumulators store real routed surplus. Feedwater Pumps boost adjacent boilers.
7. Sold MW earns construction funds while demand rises over time.
8. Sustained output milestones award cash, unlock equipment, and expand the usable yard.

## Android

Package: `com.narmanb.circuitbloom.powerplant`

It intentionally differs from the motherboard prototype package so both APKs can remain installed during comparison.
