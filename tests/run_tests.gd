extends SceneTree

const Sim = preload("res://scripts/Simulation.gd")
const Catalog = preload("res://scripts/Catalog.gd")
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
 var starter := Sim.new()
 check(starter.gross_output > 0.0, "starter turbine produces gross MW")
 check(starter.compute > 0.0 and starter.sold_mw > 0.0, "starter train exports power")
 check(starter.grid_capacity >= 75.0, "starter switchyard provides export capacity")

 var disconnected := Sim.new(false)
 disconnected.place("gland", 8, 12, true)
 disconnected.place("processor", 12, 11, true)
 disconnected.place("switchyard", 15, 11, true)
 disconnected.tick()
 check(find_part(disconnected, "processor").power == 0.0, "disconnected turbine receives no steam")
 check(disconnected.compute == 0.0, "disconnected turbine exports no power")

 var bottleneck := Sim.new(false)
 bottleneck.place("reactor", 7, 11, true)
 for x in range(9, 12): bottleneck.place("vein", x, 12, true)
 bottleneck.place("processor", 12, 11, true)
 bottleneck.place("processor", 12, 14, true)
 bottleneck.place("vein", 11, 14, true)
 bottleneck.place("vein", 11, 13, true)
 bottleneck.place("transformer", 15, 11, true)
 bottleneck.tick()
 check(bottleneck.delivered <= 42.01, "shared standard pipe constrains steam flow")

 var boosted := Sim.new(false)
 boosted.place("gland", 10, 10, true)
 boosted.tick()
 var plain_generation := boosted.generation
 boosted.place("pump", 11, 10, true)
 boosted.tick()
 check(boosted.generation > plain_generation, "adjacent feedwater pump boosts boiler")

 var export_limited := Sim.new(false)
 export_limited.place("gland", 8, 12, true)
 export_limited.place("vein", 9, 12, true)
 export_limited.place("vein", 10, 12, true)
 export_limited.place("processor", 11, 11, true)
 export_limited.tick()
 check(export_limited.gross_output > 0.0 and export_limited.compute == 0.0, "generation requires grid export equipment")
 export_limited.place("switchyard", 14, 11, true)
 export_limited.tick()
 check(export_limited.compute > 0.0, "switchyard enables export")

 var thermal := Sim.new(false)
 thermal.place("reactor", 8, 11, true)
 thermal.place("vein", 10, 12, true)
 thermal.place("processor", 11, 11, true)
 thermal.place("transformer", 14, 11, true)
 for i in 80: thermal.tick()
 var hot := thermal.part_temperature(find_part(thermal, "processor"))
 check(hot > 25.0, "operating equipment heats locally")
 var cooled := Sim.new(false)
 cooled.restore(thermal.snapshot())
 cooled.place("radiator", 11, 14, true)
 # Give both copies the same deliberate heat pulse, then compare recovery.
 var uncooled := Sim.new(false)
 uncooled.restore(thermal.snapshot())
 var turbine := find_part(cooled, "processor")
 for yy in range(turbine.y, turbine.y + 2):
  for xx in range(turbine.x, turbine.x + 2):
   cooled.heat[cooled.index(xx, yy)] = 78.0
   uncooled.heat[uncooled.index(xx, yy)] = 78.0
 for i in 45:
  cooled.tick()
  uncooled.tick()
 check(cooled.part_temperature(find_part(cooled, "processor")) < uncooled.part_temperature(find_part(uncooled, "processor")), "cooling tower lowers plant temperature")
 check(cooled.thermal_factor(100.0) < 0.1, "extreme heat heavily derates turbines")

 var economy := Sim.new(false)
 var initial_funds := economy.funds
 check(economy.place("gland", 10, 10), "funded boiler placement succeeds")
 check(economy.funds < initial_funds, "construction spends funds")
 var after_build := economy.funds
 economy.remove(10, 10)
 check(economy.funds > after_build and economy.funds < initial_funds, "demolition refunds part of build cost")

 var saved := starter.snapshot()
 var loaded := Sim.new(false)
 check(loaded.restore(JSON.parse_string(JSON.stringify(saved))), "JSON save/load snapshot")
 check(loaded.parts.size() == starter.parts.size() and loaded.heat.size() == Sim.W * Sim.W, "saved layout and thermal grid")

 var milestone := Sim.new(false)
 milestone.sold_mw = Catalog.GOALS[0].target
 milestone.hottest = 30.0
 milestone.sustain = Catalog.GOALS[0].seconds - Sim.DT
 var prior_funds := milestone.funds
 milestone._milestones()
 check(milestone.level == 1 and milestone.active_size == 14, "first output milestone expands yard")
 check(milestone.funds > prior_funds, "milestone awards expansion funds")

 var game := Game.new()
 game.size = Vector2(1280, 720)
 check(game.ui_button_at(UI.metric_rect(0, game.size).get_center()) == "metric:0", "power output telemetry hit target")
 check(game.ui_button_at(UI.category_rect(2, game.size).get_center()) == "category:Pipes", "right-panel tab hit target")
 game.category = "Build"
 check(game.ui_button_at(UI.part_rect(0, game.size).get_center()) == "gland", "boiler card hit target")
 check(not game.on_board(UI.part_rect(0, game.size).get_center()), "right build panel shields yard interaction")
 game.choose_button("grid")
 check(game.grid_visible, "grid button toggles construction grid")
 game.free()

 print("Circuit Bloom Power Plant tests: ", checks - failures, "/", checks)
 quit(1 if failures else 0)
