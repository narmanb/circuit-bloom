extends SceneTree
const Sim = preload("res://scripts/Simulation.gd")
var failures := 0
var checks := 0

func check(ok: bool, context: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL: ", context)

func find_part(m: BloomSimulation, id: String) -> Dictionary:
 for p in m.parts:
  if p.id == id: return p
 return {}

func _initialize() -> void:
 var m := Sim.new()
 check(find_part(m, "processor").power > 0.0, "starting turbine powered")
 check(m.compute > 0.0, "starting electrical output")

 var disconnected := Sim.new(false)
 disconnected.place("gland", 8, 8)
 disconnected.place("processor", 14, 14)
 disconnected.tick()
 check(find_part(disconnected, "processor").power == 0.0, "disconnected turbine")

 var bottleneck := Sim.new(false)
 bottleneck.place("gland", 7, 12)
 for x in range(8, 13): bottleneck.place("vein", x, 12)
 bottleneck.place("processor", 13, 12)
 bottleneck.place("processor", 12, 11)
 bottleneck.place("processor", 12, 13)
 bottleneck.tick()
 var total := 0.0
 for p in bottleneck.parts:
  if p.id == "processor": total += p.power
 check(total <= 25.001 and total > 20.0, "shared steam-pipe throughput")
 var thin := total
 bottleneck.level = 3
 for x in range(8, 13):
  bottleneck.remove(x, 12)
  bottleneck.place("bundle", x, 12)
 bottleneck.tick()
 total = 0.0
 for p in bottleneck.parts:
  if p.id == "processor": total += p.power
 check(total > thin, "main steam header improves trunk")

 var thermal := Sim.new(false)
 thermal.place("gland", 9, 12)
 thermal.place("vein", 10, 12)
 thermal.place("processor", 11, 12)
 thermal.tick()
 var baseline := thermal.compute
 for i in 500: thermal.tick()
 var hot := thermal.heat[thermal.index(11, 12)]
 check(hot > 25.0 and thermal.heat[thermal.index(11, 11)] > 25.0, "local heat diffusion")
 thermal.heat[thermal.index(11, 12)] = 90.0
 thermal.tick()
 check(thermal.compute < baseline * 0.6, "thermal throttling")
 check(thermal.thermal_factor(100.0) < 0.1, "critical shutdown")

 var cooled := Sim.new(false)
 cooled.place("gland", 9, 12)
 cooled.place("vein", 10, 12)
 cooled.place("processor", 11, 12)
 cooled.place("radiator", 11, 13)
 for i in 500: cooled.tick()
 check(cooled.heat[cooled.index(11, 12)] < hot, "cooling tower lowers equilibrium")

 var active_cooling := Sim.new(false)
 active_cooling.place("gland", 9, 12)
 active_cooling.place("vein", 10, 12)
 active_cooling.place("vein", 10, 13)
 active_cooling.place("processor", 11, 12)
 active_cooling.level = 2
 active_cooling.place("cooler", 11, 13)
 for i in 500: active_cooling.tick()
 check(find_part(active_cooling, "cooler").power > 0.0, "condenser train receives routed service flow")
 check(active_cooling.heat[active_cooling.index(11, 12)] < cooled.heat[cooled.index(11, 12)], "active condenser beats passive cooling")

 var accumulator := Sim.new(false)
 accumulator.level = 1
 accumulator.place("gland", 7, 12)
 for x in range(8, 12): accumulator.place("vein", x, 12)
 accumulator.place("processor", 12, 12)
 accumulator.place("capacitor", 11, 11)
 for i in 30: accumulator.tick()
 check(find_part(accumulator, "capacitor").stored > 0.0, "connected steam accumulator charges under surplus")
 accumulator.place("processor", 11, 13)
 accumulator.place("processor", 10, 11)
 accumulator.place("processor", 10, 13)
 var empty := Sim.new(false)
 empty.restore(accumulator.snapshot())
 for p in empty.parts:
  if p.id == "capacitor": p.stored = 0.0
 accumulator.tick()
 empty.tick()
 check(accumulator.delivered > empty.delivered, "charged accumulator softens overload")
 check(find_part(accumulator, "capacitor").stored < 40.0, "accumulator discharges finite steam")

 var saved := cooled.snapshot()
 var loaded := Sim.new(false)
 check(loaded.restore(JSON.parse_string(JSON.stringify(saved))), "JSON save/load snapshot")
 check(loaded.parts.size() == cooled.parts.size() and loaded.heat.size() == 576, "saved layout and heat")

 var milestones := Sim.new(false)
 milestones.place("core", 9, 9)
 milestones.level = 0
 milestones.compute = 50.0
 milestones.parts[0].ratio = 1.0
 for i in 16: milestones._milestones()
 check(milestones.level == 1 and milestones.active_size == 14, "Grid Sync expands central yard")
 milestones.compute = 0.0
 milestones.sustain = 3.0
 milestones._milestones()
 check(milestones.sustain == 0.0, "sustain reset")

 var basic_power := Sim.new(false)
 basic_power.place("gland", 10, 10)
 var advanced_power := Sim.new(false)
 advanced_power.level = 1
 check(advanced_power.place("reactor", 10, 10), "high-pressure boiler unlocks after Grid Sync")
 for pos in [Vector2i(9, 10), Vector2i(11, 10), Vector2i(10, 9), Vector2i(10, 11)]:
  basic_power.place("processor", pos.x, pos.y)
  advanced_power.place("processor", pos.x, pos.y)
 basic_power.tick()
 advanced_power.tick()
 check(advanced_power.generation == 80.0 and advanced_power.compute > basic_power.compute, "high-pressure boiler output tradeoff")
 for i in 50:
  basic_power.tick()
  advanced_power.tick()
 check(advanced_power.heat[advanced_power.index(10, 10)] > basic_power.heat[basic_power.index(10, 10)], "high-pressure boiler generates extra heat")

 print("Circuit Bloom power-plant simulation tests: ", checks - failures, "/", checks)
 quit(1 if failures else 0)
