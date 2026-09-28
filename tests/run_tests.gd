extends SceneTree
const Sim = preload("res://scripts/Simulation.gd")
const Game = preload("res://scripts/Game.gd")
const UI = preload("res://scripts/ui/InterfaceArt.gd")
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
 check(find_part(m, "processor").power > 0.0, "starting processor powered")
 check(m.compute > 0.0, "starting computation")
 var disconnected := Sim.new(false)
 disconnected.place("gland", 8, 8)
 disconnected.place("processor", 14, 14)
 disconnected.tick()
 check(find_part(disconnected, "processor").power == 0.0, "disconnected processor")
 var bottleneck := Sim.new(false)
 bottleneck.place("gland", 7, 12)
 bottleneck.place("vein", 8, 12)
 bottleneck.place("vein", 9, 12)
 bottleneck.place("vein", 10, 12)
 bottleneck.place("vein", 11, 12)
 bottleneck.place("vein", 12, 12)
 bottleneck.place("processor", 13, 12)
 bottleneck.place("processor", 12, 11)
 bottleneck.place("processor", 12, 13)
 bottleneck.tick()
 var total := 0.0
 for p in bottleneck.parts:
  if p.id == "processor": total += p.power
 check(total <= 25.001 and total > 20.0, "shared conductor throughput")
 var thin := total
 bottleneck.level = 3
 bottleneck.remove(8, 12)
 bottleneck.place("bundle", 8, 12)
 bottleneck.tick()
 # Other thin cells still limit the route; upgrade the complete shared trunk.
 for x in range(9, 13):
  bottleneck.remove(x, 12)
  bottleneck.place("bundle", x, 12)
 bottleneck.tick()
 total = 0.0
 for p in bottleneck.parts:
  if p.id == "processor": total += p.power
 check(total > thin, "bundle trunk improvement")
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
 check(cooled.heat[cooled.index(11, 12)] < hot, "passive radiator lowers equilibrium")
 var active_cooling := Sim.new(false)
 active_cooling.place("gland", 9, 12)
 active_cooling.place("vein", 10, 12)
 active_cooling.place("vein", 10, 13)
 active_cooling.place("processor", 11, 12)
 active_cooling.level = 2
 active_cooling.place("cooler", 11, 13)
 for i in 500: active_cooling.tick()
 check(find_part(active_cooling, "cooler").power > 0.0, "active cooler receives routed power")
 check(active_cooling.heat[active_cooling.index(11, 12)] < cooled.heat[cooled.index(11, 12)], "powered cooling beats passive cooling")
 var capacitor := Sim.new(false)
 capacitor.level = 1
 capacitor.place("gland", 7, 12)
 for x in range(8, 12): capacitor.place("vein", x, 12)
 capacitor.place("processor", 12, 12)
 capacitor.place("capacitor", 11, 11)
 for i in 30: capacitor.tick()
 check(find_part(capacitor, "capacitor").stored > 0.0, "connected capacitor charges under surplus")
 capacitor.place("processor", 11, 13)
 capacitor.place("processor", 10, 11)
 capacitor.place("processor", 10, 13)
 var empty := Sim.new(false)
 empty.restore(capacitor.snapshot())
 for p in empty.parts:
  if p.id == "capacitor": p.stored = 0.0
 capacitor.tick()
 empty.tick()
 check(capacitor.delivered > empty.delivered, "charged capacitor softens overload")
 check(find_part(capacitor, "capacitor").stored < 40.0, "capacitor discharges finite energy")
 var saved := cooled.snapshot()
 var loaded := Sim.new(false)
 check(loaded.restore(JSON.parse_string(JSON.stringify(saved))), "JSON save/load snapshot")
 check(loaded.parts.size() == cooled.parts.size() and loaded.heat.size() == 576, "saved layout and heat")
 var milestones := Sim.new(false)
 milestones.place("core", 9, 9)
 milestones.level = 0
 milestones.compute = 50.0
 # Milestone guard uses a powered core.
 milestones.parts[0].ratio = 1.0
 milestones._milestones()
 check(milestones.level == 1 and milestones.active_size == 14, "first milestone expands substrate")
 milestones.compute = 0.0
 milestones.sustain = 3.0
 milestones._milestones()
 check(milestones.sustain == 0.0, "sustain reset")
 var game := Game.new()
 game.size = Vector2(1280, 720)
 check(game.ui_button_at(UI.action_rect(3, game.size).get_center()) == "heat", "heat button hit target")
 check(game.ui_button_at(UI.category_rect(2, game.size).get_center()) == "category:Compute", "category tab hit target")
 game.category = "Compute"
 check(game.ui_button_at(UI.part_rect(1, game.size).get_center()) == "cluster", "part card hit target")
 game.free()
 print("Circuit Bloom tests: ", checks - failures, "/", checks)
 quit(1 if failures else 0)
