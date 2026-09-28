extends RefCounted
class_name BloomInterfaceArt

const Catalog = preload("res://scripts/Catalog.gd")
const BoardArt = preload("res://scripts/rendering/BoardArt.gd")
const TOP := 129.0
const BOTTOM := 35.0
const INSPECT_W := 250.0
const RAIL_W := 132.0
const FLYOUT_W := 214.0
const LEFT_W := RAIL_W + FLYOUT_W
const CATEGORIES := ["Connections", "Power", "Compute", "Cooling", "Support", "Tools"]
const ACTIONS := ["undo", "redo", "power", "heat", "speed", "pause"]
const DISPLAY := {"Connections":"Piping", "Power":"Boilers", "Compute":"Turbines", "Cooling":"Cooling", "Support":"Storage", "Tools":"Tools"}
const BG := Color("11161a")
const PANEL := Color("20272a")
const BORDER := Color("626b6c")
const MUTED := Color("a8afb0")
const TEXT := Color("f1eee5")
const AMBER := Color("d7aa4a")
const BLUE := Color("72c5dc")
const RED := Color("e2765e")
const GREEN := Color("82c695")

static func items_for(category: String) -> Array[String]:
 var result: Array[String] = []
 if category == "Tools": return ["select", "remove"]
 for id in Catalog.ORDER:
  if Catalog.PARTS[id].category == category: result.append(id)
 return result

static func action_rect(index: int, view: Vector2) -> Rect2:
 return Rect2(view.x - 390 + index * 64, 6, 60, 38)

static func metric_rect(index: int, view: Vector2) -> Rect2:
 var gap := 8.0
 var width := (view.x - 32.0 - gap * 3.0) / 4.0
 return Rect2(16 + index * (width + gap), 48, width, 55)

static func category_rect(index: int, _view: Vector2) -> Rect2:
 return Rect2(8, TOP + 11 + index * 57, RAIL_W - 16, 52)

static func part_rect(index: int, _view: Vector2) -> Rect2:
 return Rect2(RAIL_W + 8, TOP + 64 + index * 83, FLYOUT_W - 16, 77)

static func text(canvas: CanvasItem, value: String, pos: Vector2, px := 14, tint := TEXT, max_width := -1.0) -> void:
 canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, px, tint)

static func panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, edge := BORDER) -> void:
 canvas.draw_rect(rect, fill)
 canvas.draw_rect(rect, edge, false, 1.1)
 canvas.draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(14, 1), AMBER.darkened(0.25), 2)

static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, tint: Color) -> void:
 canvas.draw_rect(rect, Color("0b1012"))
 if fraction > 0.005: canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), tint)
 canvas.draw_rect(rect, Color("5e6867"), false, 1)

static func wrapped(canvas: CanvasItem, value: String, pos: Vector2, width: float, px := 13, tint := MUTED) -> void:
 var line := ""
 var y := pos.y
 for word in value.split(" "):
  var attempt := word if line.is_empty() else line + " " + word
  if ThemeDB.fallback_font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not line.is_empty():
   text(canvas, line, Vector2(pos.x, y), px, tint)
   y += px + 5
   line = word
  else: line = attempt
 if not line.is_empty(): text(canvas, line, Vector2(pos.x, y), px, tint)

static func status_of(p: Dictionary, temperature: float) -> String:
 if p.id in ["vein", "bundle"]: return "STEAM FLOWING" if p.load > 0.01 else "PIPE IDLE"
 if p.id in ["gland", "reactor"]: return "BOILER FIRING"
 if p.id == "radiator": return "REJECTING HEAT"
 if p.id == "capacitor": return "CHARGING" if p.flow > 0.1 else ("DISCHARGING" if p.flow < -0.1 else "STANDBY")
 if p.ratio <= 0.001: return "OFFLINE"
 if p.ratio < 0.4: return "STARVED"
 if p.ratio < 0.8: return "PART LOAD"
 if temperature >= 85.0: return "THERMAL DANGER"
 if temperature >= 70.0: return "HOT"
 return "ONLINE"

static func draw(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String, selection: int, overlay: String, paused: bool, speed: int, tutorial: int, message: String, message_time: float, help_index: int, zoom: float) -> void:
 draw_header(canvas, model, view, overlay, paused, speed)
 draw_build_rail(canvas, model, view, category, tool)
 draw_inspector(canvas, model, view, selection)
 draw_status(canvas, model, view, tool, zoom)
 if tutorial == 0: draw_tutorial(canvas, view)
 elif help_index >= 0: draw_help(canvas, model, view, help_index)
 if message_time > 0.0:
  var rect := Rect2(LEFT_W + 20, TOP + 10, minf(470, view.x - LEFT_W - INSPECT_W - 40), 45)
  panel(canvas, rect, Color("3a3525"), AMBER)
  text(canvas, message, rect.position + Vector2(12, 29), 14, TEXT, rect.size.x - 22)

static func draw_header(canvas: CanvasItem, model: BloomSimulation, view: Vector2, overlay: String, paused: bool, speed: int) -> void:
 canvas.draw_rect(Rect2(0, 0, view.x, TOP), BG)
 canvas.draw_line(Vector2(0, TOP - 1), Vector2(view.x, TOP - 1), AMBER.darkened(0.35), 1.5)
 text(canvas, "CIRCUIT BLOOM", Vector2(16, 28), 21, TEXT)
 text(canvas, "POWER PLANT PROTOTYPE  /  CENTRAL YARD", Vector2(17, 42), 10, MUTED)
 for i in ACTIONS.size():
  var id: String = ACTIONS[i]
  var rect := action_rect(i, view)
  var active := (id == overlay) or (id == "pause" and paused)
  panel(canvas, rect, Color("494128") if active else PANEL, AMBER if active else BORDER)
  draw_action_icon(canvas, id, rect.position + Vector2(17, 17), paused, AMBER if active else TEXT)
  var caption := "%dx" % speed if id == "speed" else ("Play" if id == "pause" and paused else id.capitalize())
  text(canvas, caption, rect.position + Vector2(32, 24), 10, TEXT)
 var metrics := [
  {"name":"ELECTRIC OUTPUT", "value":"%.1f MW" % model.compute, "sub":"Peak %.1f MW" % model.peak, "fill":clampf(model.compute / maxf(30.0, model.peak), 0.0, 1.0), "color":BLUE},
  {"name":"STEAM DELIVERED", "value":"%d / %d t/h" % [roundi(model.delivered), roundi(model.requested)], "sub":"%d t/h raised" % roundi(model.generation), "fill":clampf(model.delivered / maxf(1.0, model.requested), 0.0, 1.0), "color":AMBER},
  {"name":"STEAM HEADROOM", "value":"%+d t/h" % roundi(model.generation - model.delivered), "sub":"Available reserve", "fill":clampf((model.generation - model.delivered) / maxf(1.0, model.generation), 0.0, 1.0), "color":GREEN},
  {"name":"HOTTEST UNIT", "value":"%.0f°C" % model.hottest, "sub":"Output falls above 65°C", "fill":clampf((model.hottest - 25.0) / 70.0, 0.0, 1.0), "color":RED if model.hottest >= 70.0 else BLUE}
 ]
 for i in metrics.size():
  var item: Dictionary = metrics[i]
  var rect := metric_rect(i, view)
  panel(canvas, rect, Color("242c2e"))
  text(canvas, item.name + "  ⓘ", rect.position + Vector2(10, 13), 10, MUTED)
  text(canvas, item.value, rect.position + Vector2(10, 37), 18, item.color)
  text(canvas, item.sub, rect.position + Vector2(rect.size.x * 0.60, 34), 10, MUTED, rect.size.x * 0.37)
  bar(canvas, Rect2(rect.position + Vector2(9, 49), Vector2(rect.size.x - 18, 3)), item.fill, item.color)
 if model.level < Catalog.GOALS.size():
  var goal: Dictionary = Catalog.GOALS[model.level]
  text(canvas, "NEXT  " + goal.name, Vector2(16, 122), 11, AMBER)
  text(canvas, "%d MW  •  %.0f / %.0f s" % [roundi(goal.target), model.sustain, goal.seconds], Vector2(212, 122), 11, TEXT)
  bar(canvas, Rect2(Vector2(456, 114), Vector2(maxf(50, view.x - 472), 6)), minf(1, model.sustain / float(goal.seconds)), GREEN)
 else: text(canvas, "FULL LOAD ACHIEVED  /  FREE-BUILD MODE", Vector2(16, 122), 11, GREEN)

static func draw_action_icon(canvas: CanvasItem, id: String, c: Vector2, paused: bool, tint: Color) -> void:
 match id:
  "undo", "redo":
   var dir := -1.0 if id == "undo" else 1.0
   canvas.draw_arc(c, 8, -2.4 if dir < 0 else -0.7, 1.7 if dir < 0 else 3.8, 18, tint, 2)
   canvas.draw_line(c + Vector2(dir * -7, -5), c + Vector2(dir * -12, -5), tint, 2)
  "power":
   canvas.draw_line(c + Vector2(-10, 1), c + Vector2(10, 1), tint, 2.5)
   canvas.draw_circle(c, 3, tint)
  "heat":
   canvas.draw_arc(c, 8, 0.3, 2.7, 18, tint, 2)
   canvas.draw_line(c + Vector2(0, 7), c + Vector2(3, -7), tint, 2)
  "speed": canvas.draw_polyline(PackedVector2Array([c + Vector2(-8, -8), c + Vector2(1, 0), c + Vector2(-8, 8)]), tint, 2.5)
  "pause":
   if paused: canvas.draw_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(7, 0), c + Vector2(-5, 8)]), PackedColorArray([tint]))
   else:
    canvas.draw_rect(Rect2(c + Vector2(-7, -8), Vector2(4, 16)), tint)
    canvas.draw_rect(Rect2(c + Vector2(3, -8), Vector2(4, 16)), tint)

static func module_color(id: String) -> Color:
 if id in ["gland", "reactor"]: return AMBER if id == "gland" else RED
 if id in ["processor", "cluster"]: return BLUE
 if id in ["radiator", "cooler"]: return Color("81cfe1")
 if id == "capacitor": return Color("d7bd75")
 return GREEN

static func draw_build_rail(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String) -> void:
 var rail := Rect2(0, TOP, RAIL_W, view.y - TOP - BOTTOM)
 panel(canvas, rail, Color("171e21"), BORDER)
 text(canvas, "BUILD", Vector2(15, TOP + 31), 14, AMBER)
 for i in CATEGORIES.size():
  var name: String = CATEGORIES[i]
  var rect := category_rect(i, view)
  var active := name == category
  panel(canvas, rect, Color("4a402a") if active else Color("252d30"), AMBER if active else BORDER)
  BoardArt.symbol(canvas, name, rect.position + Vector2(18, 25), 0.66, AMBER if active else MUTED)
  text(canvas, DISPLAY.get(name, name), rect.position + Vector2(37, 31), 11, TEXT if active else MUTED, rect.size.x - 40)
 if category.is_empty(): return
 var fly := Rect2(RAIL_W, TOP + 8, FLYOUT_W, view.y - TOP - BOTTOM - 16)
 panel(canvas, fly, Color("20282a"), Color("77705a"))
 text(canvas, str(DISPLAY.get(category, category)).to_upper(), fly.position + Vector2(12, 25), 12, AMBER)
 text(canvas, "Choose equipment, then tap yard.", fly.position + Vector2(12, 45), 10, MUTED)
 var items := items_for(category)
 for i in items.size():
  var id: String = items[i]
  var rect := part_rect(i, view)
  var d: Dictionary = Catalog.PARTS.get(id, {})
  var locked: bool = d.get("unlock", 0) > model.level
  var active := tool == id or (id == "select" and tool == "")
  panel(canvas, rect, Color("4a432d") if active else (Color("202628") if locked else Color("30383a")), AMBER if active else BORDER)
  var tint := MUTED if locked else module_color(id)
  canvas.draw_rect(Rect2(rect.position + Vector2(8, 10), Vector2(39, 57)), Color("151b1d"))
  BoardArt.symbol(canvas, id, rect.position + Vector2(27, 38), 0.90, tint)
  var title: String = "Inspect / Pan" if id == "select" else ("Remove" if id == "remove" else d.name)
  text(canvas, title, rect.position + Vector2(53, 23), 13, TEXT if not locked else MUTED, rect.size.x - 58)
  var line := "Tap equipment" if id == "select" else ("Full refund" if id == "remove" else ("UNLOCK: " + Catalog.GOALS[int(d.unlock) - 1].name if locked else "%d build" % d.cost))
  text(canvas, line, rect.position + Vector2(53, 42), 10, AMBER if locked else tint, rect.size.x - 58)
  var stats := "Drag to pan" if id == "select" else ("Tap to clear" if id == "remove" else summary_of(d))
  text(canvas, stats, rect.position + Vector2(53, 61), 9, MUTED, rect.size.x - 58)
 text(canvas, "CONSTRUCTION", fly.position + Vector2(12, fly.size.y - 73), 10, MUTED)
 text(canvas, "%d / %d" % [model.biomass_used(), model.biomass_max], fly.position + Vector2(12, fly.size.y - 50), 17, TEXT)
 bar(canvas, Rect2(fly.position + Vector2(12, fly.size.y - 37), Vector2(fly.size.x - 24, 5)), float(model.biomass_used()) / maxf(1.0, model.biomass_max), AMBER)

static func summary_of(d: Dictionary) -> String:
 if d.has("generate"): return "+%d t/h steam" % roundi(d.generate)
 if d.has("compute"): return "%d MW  •  %d t/h" % [roundi(d.compute), roundi(d.request)]
 if d.has("capacity"): return "%d t/h throughput" % roundi(d.capacity)
 if d.has("cool"): return "Cooling %.1f" % d.cool
 if d.has("storage"): return "%d t storage" % roundi(d.storage)
 return "Plant support"

static func draw_inspector(canvas: CanvasItem, model: BloomSimulation, view: Vector2, selection: int) -> void:
 var x := view.x - INSPECT_W
 var rect := Rect2(x, TOP, INSPECT_W, view.y - TOP - BOTTOM)
 panel(canvas, rect, Color("171f22"), BORDER)
 text(canvas, "EQUIPMENT", Vector2(x + 15, TOP + 30), 13, AMBER)
 if selection < 0 or selection >= model.parts.size():
  text(canvas, "Nothing selected", Vector2(x + 15, TOP + 66), 17, TEXT)
  wrapped(canvas, "Use Inspect / Pan and tap a placed unit to see steam, output, load and thermal state.", Vector2(x + 15, TOP + 94), INSPECT_W - 30, 12, MUTED)
  return
 var p: Dictionary = model.parts[selection]
 var d: Dictionary = Catalog.PARTS[p.id]
 var sz: int = d.get("size", 1)
 var temp := 25.0
 for yy in range(p.y, p.y + sz):
  for xx in range(p.x, p.x + sz): temp = maxf(temp, model.heat[model.index(xx, yy)])
 var tint := module_color(p.id)
 text(canvas, d.name, Vector2(x + 15, TOP + 65), 19, TEXT, INSPECT_W - 30)
 text(canvas, status_of(p, temp), Vector2(x + 15, TOP + 88), 11, tint)
 BoardArt.symbol(canvas, p.id, Vector2(x + INSPECT_W - 38, TOP + 66), 1.0, tint)
 wrapped(canvas, d.description, Vector2(x + 15, TOP + 122), INSPECT_W - 30, 11, MUTED)
 var y := TOP + 206
 var rows: Array[String] = []
 if d.has("generate"): rows.append("Steam raised   %d t/h" % roundi(d.generate))
 if d.has("request"): rows.append("Steam demand   %d t/h" % roundi(d.request))
 if d.has("compute"): rows.append("Rated output   %d MW" % roundi(d.compute))
 if d.has("capacity"): rows.append("Throughput     %d t/h" % roundi(d.capacity))
 if d.has("storage"): rows.append("Stored         %.1f / %.0f t" % [p.stored, d.storage])
 if d.has("cool"): rows.append("Cooling        %.1f" % d.cool)
 rows.append("Temperature    %.0f°C" % temp)
 if p.load > 0.0: rows.append("Current flow   %.1f t/h" % p.load)
 if p.compute > 0.0: rows.append("Live output    %.1f MW" % p.compute)
 for row in rows:
  text(canvas, row, Vector2(x + 15, y), 12, TEXT)
  y += 25

static func draw_status(canvas: CanvasItem, model: BloomSimulation, view: Vector2, tool: String, zoom: float) -> void:
 canvas.draw_rect(Rect2(0, view.y - BOTTOM, view.x, BOTTOM), BG)
 canvas.draw_line(Vector2(0, view.y - BOTTOM), Vector2(view.x, view.y - BOTTOM), BORDER, 1)
 var tool_name := "Inspect / Pan" if tool == "" else ("Remove" if tool == "remove" else Catalog.PARTS.get(tool, {}).get("name", tool))
 text(canvas, "TOOL  " + tool_name, Vector2(14, view.y - 12), 10, AMBER)
 text(canvas, "YARD %d×%d   •   ZOOM %d%%" % [model.active_size, model.active_size, roundi(zoom * 100.0)], Vector2(222, view.y - 12), 10, MUTED)
 text(canvas, "Drag pipes/remove to paint  •  Other tools drag to pan  •  Pinch to zoom", Vector2(480, view.y - 12), 10, MUTED, view.x - 490)

static func draw_tutorial(canvas: CanvasItem, view: Vector2) -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.03, 0.03, 0.72))
 var r := Rect2(view * 0.5 - Vector2(255, 142), Vector2(510, 284))
 panel(canvas, r, Color("20282a"), AMBER)
 text(canvas, "POWER PLANT PROTOTYPE", r.position + Vector2(26, 42), 24, TEXT)
 text(canvas, "Build the plant, not just the courtyard.", r.position + Vector2(26, 70), 14, AMBER)
 wrapped(canvas, "Boilers raise steam. Pipes carry it. Turbine generators turn steam into MW. Cooling keeps equipment out of thermal throttle. Expand the yard by holding each output milestone.", r.position + Vector2(26, 105), r.size.x - 52, 13, MUTED)
 text(canvas, "Tap anywhere to begin", r.position + Vector2(26, r.size.y - 27), 14, GREEN)

static func help_data(index: int, model: BloomSimulation) -> Dictionary:
 match index:
  0: return {"title":"ELECTRIC OUTPUT", "body":"Live MW from turbine generators after steam supply and thermal throttling. This is the main progression target."}
  1: return {"title":"STEAM DELIVERED", "body":"Steam that successfully reaches plant consumers through connected pipes. A turbine with insufficient delivery runs at part load."}
  2: return {"title":"STEAM HEADROOM", "body":"Boiler production minus current delivery. Positive reserve helps with new turbines, but pipe throughput can still bottleneck a route even when total steam is available."}
  3: return {"title":"HOTTEST UNIT", "body":"The hottest grid cell in the plant. Turbines begin losing output above 65°C, so cooling placement matters as the yard becomes denser."}
 return {"title":"PLANT METRIC", "body":"Operational status."}

static func draw_help(canvas: CanvasItem, model: BloomSimulation, view: Vector2, index: int) -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.02, 0.02, 0.48))
 var data := help_data(index, model)
 var r := Rect2(view * 0.5 - Vector2(235, 105), Vector2(470, 210))
 panel(canvas, r, Color("222a2c"), AMBER)
 text(canvas, data.title, r.position + Vector2(22, 42), 20, TEXT)
 wrapped(canvas, data.body, r.position + Vector2(22, 76), r.size.x - 44, 13, MUTED)
 text(canvas, "Tap outside to close", r.position + Vector2(22, r.size.y - 22), 11, AMBER)
