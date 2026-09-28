extends RefCounted
class_name BloomInterfaceArt

const Catalog = preload("res://scripts/Catalog.gd")
const BoardArt = preload("res://scripts/rendering/BoardArt.gd")

const TOP := 76.0
const BOTTOM := 64.0
const SIDE_W := 286.0
const LEFT_W := 0.0
const INSPECT_W := SIDE_W
const CATEGORIES := ["Build", "Power", "Pipes", "Logistics"]
const ACTIONS := ["undo", "redo", "power", "heat", "speed", "pause"]
const BG := Color("0d1318")
const PANEL := Color("19232b")
const PANEL_2 := Color("222d35")
const BORDER := Color("344451")
const MUTED := Color("a8b2b9")
const TEXT := Color("eff3f4")
const AMBER := Color("f0b332")
const BLUE := Color("42bce8")
const RED := Color("ee6b5a")
const GREEN := Color("68d792")

static func items_for(category: String) -> Array[String]:
 var raw: Array = Catalog.TAB_ITEMS.get(category, [])
 var result: Array[String] = []
 for id in raw: result.append(str(id))
 return result

static func side_x(view: Vector2) -> float:
 return view.x - SIDE_W

static func action_rect(index: int, view: Vector2) -> Rect2:
 return Rect2(view.x - SIDE_W - 258 + index * 42, 17, 38, 38)

static func metric_rect(index: int, view: Vector2) -> Rect2:
 var available := maxf(480.0, view.x - SIDE_W - 364.0)
 var width := available / 5.0
 return Rect2(index * width, 0, width, TOP)

static func category_rect(index: int, view: Vector2) -> Rect2:
 var w := SIDE_W / 4.0
 return Rect2(side_x(view) + index * w, TOP, w, 48)

static func part_rect(index: int, view: Vector2) -> Rect2:
 var cols := 2
 var col := index % cols
 var row := index / cols
 var pad := 10.0
 var w := (SIDE_W - pad * 3.0) / 2.0
 return Rect2(side_x(view) + pad + col * (w + pad), TOP + 62 + row * 104, w, 94)

static func bottom_tool_rect(index: int, _view: Vector2) -> Rect2:
 return Rect2(10 + index * 92, 0, 82, 54)

static func text(canvas: CanvasItem, value: String, pos: Vector2, px := 14, tint := TEXT, max_width := -1.0) -> void:
 canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, px, tint)

static func panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, edge := BORDER) -> void:
 canvas.draw_rect(rect, fill)
 canvas.draw_rect(rect, edge, false, 1.0)

static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, tint: Color) -> void:
 canvas.draw_rect(rect, Color("0a1014"))
 if fraction > 0.004:
  canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), tint)
 canvas.draw_rect(rect, BORDER, false, 1.0)

static func money(v: float) -> String:
 if v >= 1000000.0: return "$%.2fM" % (v / 1000000.0)
 if v >= 1000.0: return "$%.0fk" % (v / 1000.0)
 return "$%.0f" % v

static func wrapped(canvas: CanvasItem, value: String, pos: Vector2, width: float, px := 12, tint := MUTED) -> void:
 var line := ""
 var y := pos.y
 for word in value.split(" "):
  var attempt := str(word) if line.is_empty() else line + " " + str(word)
  if ThemeDB.fallback_font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width and not line.is_empty():
   text(canvas, line, Vector2(pos.x, y), px, tint)
   y += px + 4
   line = str(word)
  else:
   line = attempt
 if not line.is_empty(): text(canvas, line, Vector2(pos.x, y), px, tint)

static func module_color(id: String) -> Color:
 if id in ["gland", "reactor"]: return AMBER if id == "gland" else RED
 if id in ["processor", "cluster", "transformer", "switchyard"]: return BLUE
 if id in ["radiator", "cooler", "pump", "tank"]: return Color("69c7df")
 if id == "capacitor": return Color("d9ba64")
 return GREEN

static func status_of(p: Dictionary, temperature: float) -> String:
 if p.id in ["vein", "bundle"]: return "STEAM FLOWING" if float(p.load) > 0.01 else "PIPE IDLE"
 if p.id in ["gland", "reactor"]: return "BOILER FIRING"
 if p.id in ["transformer", "switchyard"]: return "GRID CONNECTED"
 if p.id in ["radiator", "cooler", "tank"]: return "COOLING SERVICE"
 if p.id == "pump": return "FEEDWATER SERVICE"
 if p.id == "capacitor": return "CHARGING" if float(p.flow) > 0.1 else ("DISCHARGING" if float(p.flow) < -0.1 else "STANDBY")
 if float(p.ratio) <= 0.001: return "OFFLINE"
 if float(p.ratio) < 0.45: return "STEAM STARVED"
 if temperature >= 85.0: return "THERMAL DANGER"
 if temperature >= 70.0: return "HOT / DERATED"
 return "ONLINE"

static func draw(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String, selection: int, overlay: String, paused: bool, speed: int, tutorial: int, message: String, message_time: float, help_index: int, zoom: float, grid_visible := false) -> void:
 draw_header(canvas, model, view, overlay, paused, speed)
 draw_side_panel(canvas, model, view, category, tool, selection)
 draw_bottom(canvas, model, view, tool, zoom, grid_visible)
 if tutorial == 0: draw_tutorial(canvas, view)
 elif help_index >= 0: draw_help(canvas, model, view, help_index)
 if message_time > 0.0:
  var rect := Rect2(18, TOP + 12, minf(520.0, view.x - SIDE_W - 36.0), 44)
  panel(canvas, rect, Color("3a3120"), AMBER)
  text(canvas, message, rect.position + Vector2(12, 28), 13, TEXT, rect.size.x - 24)

static func draw_header(canvas: CanvasItem, model: BloomSimulation, view: Vector2, overlay: String, paused: bool, speed: int) -> void:
 canvas.draw_rect(Rect2(0, 0, view.x, TOP), BG)
 canvas.draw_line(Vector2(0, TOP - 1), Vector2(view.x, TOP - 1), BORDER, 1)
 var metrics := [
  {"label":"POWER OUTPUT", "value":"%.0f MW" % model.compute, "sub":"gross %.0f" % model.gross_output, "color":GREEN, "fill":model.compute / maxf(1.0, model.grid_demand)},
  {"label":"GRID DEMAND", "value":"%.0f MW" % model.grid_demand, "sub":"sold %.0f" % model.sold_mw, "color":BLUE, "fill":model.sold_mw / maxf(1.0, model.grid_demand)},
  {"label":"HEADROOM", "value":"%+.0f MW" % (model.grid_capacity - model.compute), "sub":"export capacity", "color":BLUE, "fill":maxf(0.0, model.grid_capacity - model.compute) / maxf(1.0, model.grid_capacity)},
  {"label":"STEAM", "value":"%.0f t/h" % model.delivered, "sub":"%.0f raised" % model.generation, "color":AMBER, "fill":model.delivered / maxf(1.0, model.requested)},
  {"label":"TEMPERATURE", "value":"%.0f°C" % model.hottest, "sub":"derates >65°C", "color":RED if model.hottest >= 70.0 else GREEN, "fill":clampf((model.hottest - 25.0) / 70.0, 0.0, 1.0)}
 ]
 var metric_area := maxf(500.0, view.x - SIDE_W - 364.0)
 var width := metric_area / 5.0
 for i in metrics.size():
  var item: Dictionary = metrics[i]
  var rect := Rect2(i * width, 0, width, TOP)
  canvas.draw_line(Vector2(rect.end.x, 0), Vector2(rect.end.x, TOP), Color("25323b"), 1)
  text(canvas, item.label + "  ⓘ", rect.position + Vector2(12, 19), 10, MUTED, width - 20)
  text(canvas, item.value, rect.position + Vector2(12, 46), 19, item.color, width - 18)
  text(canvas, item.sub, rect.position + Vector2(12, 63), 9, MUTED, width - 18)
  bar(canvas, Rect2(rect.position + Vector2(12, 69), Vector2(width - 24, 4)), float(item.fill), item.color)

 var funds_x := metric_area + 12
 text(canvas, "FUNDS", Vector2(funds_x, 20), 10, MUTED)
 text(canvas, money(model.funds), Vector2(funds_x, 47), 18, AMBER)
 text(canvas, "Day %d  %02d:%02d" % [1 + int(model.elapsed / 180.0), int(fmod(model.elapsed, 180.0) / 7.5), int(fmod(model.elapsed * 8.0, 60.0))], Vector2(funds_x, 64), 9, MUTED)

 for i in ACTIONS.size():
  var id: String = ACTIONS[i]
  var rect := action_rect(i, view)
  var active := (id == overlay) or (id == "pause" and paused)
  panel(canvas, rect, Color("3d3420") if active else PANEL, AMBER if active else BORDER)
  draw_action_icon(canvas, id, rect.get_center(), paused, AMBER if active else TEXT)

static func draw_action_icon(canvas: CanvasItem, id: String, c: Vector2, paused: bool, tint: Color) -> void:
 match id:
  "undo", "redo":
   var flip := -1.0 if id == "undo" else 1.0
   canvas.draw_arc(c, 9, -2.5 if flip < 0 else -0.65, 1.7 if flip < 0 else 3.8, 18, tint, 2)
   canvas.draw_line(c + Vector2(flip * -7, -6), c + Vector2(flip * -12, -6), tint, 2)
  "power":
   canvas.draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), tint, 2.4)
   canvas.draw_circle(c, 3.2, tint)
  "heat":
   canvas.draw_arc(c, 8, 0.3, 2.8, 18, tint, 2)
   canvas.draw_line(c + Vector2(0, 8), c + Vector2(2, -8), tint, 2)
  "speed":
   canvas.draw_polygon(PackedVector2Array([c + Vector2(-7, -8), c + Vector2(7, 0), c + Vector2(-7, 8)]), PackedColorArray([tint]))
  "pause":
   if paused:
    canvas.draw_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(8, 0), c + Vector2(-5, 8)]), PackedColorArray([tint]))
   else:
    canvas.draw_rect(Rect2(c + Vector2(-7, -8), Vector2(4, 16)), tint)
    canvas.draw_rect(Rect2(c + Vector2(3, -8), Vector2(4, 16)), tint)

static func draw_side_panel(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String, selection: int) -> void:
 var x := side_x(view)
 canvas.draw_rect(Rect2(x, TOP, SIDE_W, view.y - TOP), Color("101820"))
 canvas.draw_line(Vector2(x, TOP), Vector2(x, view.y), BORDER, 1)

 for i in CATEGORIES.size():
  var tab := category_rect(i, view)
  var active := CATEGORIES[i] == category
  panel(canvas, tab, Color("1b526f") if active else Color("202b34"), Color("2b779a") if active else BORDER)
  text(canvas, CATEGORIES[i], tab.position + Vector2(11, 29), 12, TEXT if active else MUTED, tab.size.x - 16)

 var items := items_for(category)
 var visible_rows := mini(3, ceili(items.size() / 2.0))
 for i in mini(items.size(), 6):
  var id: String = items[i]
  var d: Dictionary = Catalog.PARTS[id]
  var rect := part_rect(i, view)
  var locked: bool = int(d.get("unlock", 0)) > model.level
  var active := tool == id
  panel(canvas, rect, Color("253745") if active else (Color("182027") if locked else Color("1c2831")), AMBER if active else BORDER)
  var tint := MUTED if locked else module_color(id)
  BoardArt.symbol(canvas, id, rect.position + Vector2(rect.size.x * 0.5, 28), 0.82, tint)
  text(canvas, str(d.name), rect.position + Vector2(7, 56), 11, TEXT if not locked else MUTED, rect.size.x - 14)
  var sub := "LOCKED" if locked else money(float(d.cost))
  text(canvas, sub, rect.position + Vector2(7, 76), 10, AMBER if locked else tint, rect.size.x - 14)
  text(canvas, summary_of(d), rect.position + Vector2(7, 89), 8, MUTED, rect.size.x - 14)

 var y := TOP + 70 + visible_rows * 104
 y = maxf(y, TOP + 280)
 canvas.draw_line(Vector2(x + 10, y), Vector2(view.x - 10, y), BORDER, 1)
 text(canvas, "NEXT MILESTONE", Vector2(x + 12, y + 25), 10, MUTED)
 if model.level < Catalog.GOALS.size():
  var goal: Dictionary = Catalog.GOALS[model.level]
  text(canvas, goal.name, Vector2(x + 12, y + 48), 15, AMBER, SIDE_W - 24)
  text(canvas, "Hold %.0f MW for %.0f sec" % [goal.target, goal.seconds], Vector2(x + 12, y + 68), 10, TEXT)
  bar(canvas, Rect2(x + 12, y + 80, SIDE_W - 24, 5), model.sustain / maxf(0.1, float(goal.seconds)), GREEN)
  wrapped(canvas, "Reward: " + str(goal.reward), Vector2(x + 12, y + 104), SIDE_W - 24, 10, MUTED)
 else:
  text(canvas, "FULL LOAD / FREE BUILD", Vector2(x + 12, y + 50), 14, GREEN)

 if selection >= 0 and selection < model.parts.size():
  var p: Dictionary = model.parts[selection]
  var d: Dictionary = Catalog.PARTS[p.id]
  var iy := view.y - 132
  canvas.draw_line(Vector2(x + 10, iy - 15), Vector2(view.x - 10, iy - 15), BORDER, 1)
  text(canvas, d.name, Vector2(x + 12, iy + 5), 14, TEXT, SIDE_W - 24)
  text(canvas, status_of(p, model.part_temperature(p)), Vector2(x + 12, iy + 23), 10, module_color(p.id))
  var detail := detail_of(p, d, model)
  wrapped(canvas, detail, Vector2(x + 12, iy + 43), SIDE_W - 24, 10, MUTED)

static func summary_of(d: Dictionary) -> String:
 if d.has("generate"): return "+%.0f t/h steam" % d.generate
 if d.has("compute"): return "%.0f MW rated" % d.compute
 if d.has("capacity"): return "%.0f t/h line" % d.capacity
 if d.has("grid_capacity"): return "+%.0f MW export" % d.grid_capacity
 if d.has("cool"): return "cooling %.1f" % d.cool
 if d.has("storage"): return "%.0f t storage" % d.storage
 return "plant support"

static func detail_of(p: Dictionary, d: Dictionary, model: BloomSimulation) -> String:
 var bits: Array[String] = []
 if d.has("generate"): bits.append("Steam %.0f t/h" % float(p.steam_out))
 if d.has("request"): bits.append("Steam %.0f/%.0f" % [float(p.power), float(d.request)])
 if d.has("compute"): bits.append("Output %.0f MW" % float(p.compute))
 if d.has("capacity"): bits.append("Flow %.0f/%.0f" % [float(p.load), float(d.capacity)])
 if d.has("storage"): bits.append("Stored %.0f/%.0f" % [float(p.stored), float(d.storage)])
 bits.append("%.0f°C" % model.part_temperature(p))
 return "  •  ".join(bits)

static func draw_bottom(canvas: CanvasItem, model: BloomSimulation, view: Vector2, tool: String, zoom: float, grid_visible: bool) -> void:
 var y := view.y - BOTTOM
 canvas.draw_rect(Rect2(0, y, view.x - SIDE_W, BOTTOM), BG)
 canvas.draw_line(Vector2(0, y), Vector2(view.x - SIDE_W, y), BORDER, 1)
 var labels := ["Inspect", "Grid", "Demolish"]
 var ids := ["select", "grid", "remove"]
 for i in 3:
  var rect := Rect2(10 + i * 94, y + 6, 84, 52)
  var active := (ids[i] == "select" and tool == "") or (ids[i] == "remove" and tool == "remove") or (ids[i] == "grid" and grid_visible)
  panel(canvas, rect, Color("253745") if active else PANEL, AMBER if active else BORDER)
  BoardArt.symbol(canvas, "select" if ids[i] == "grid" else ids[i], rect.position + Vector2(17, 20), 0.55, AMBER if active else MUTED)
  text(canvas, labels[i], rect.position + Vector2(34, 30), 10, TEXT)
 text(canvas, "YARD %d×%d  •  ZOOM %d%%" % [model.active_size, model.active_size, roundi(zoom * 100.0)], Vector2(307, y + 23), 10, MUTED)
 text(canvas, "Drag pipes to paint  •  Inspect drag to pan  •  Pinch / wheel to zoom", Vector2(307, y + 43), 10, MUTED, view.x - SIDE_W - 320)

static func draw_tutorial(canvas: CanvasItem, view: Vector2) -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.02, 0.025, 0.74))
 var r := Rect2(view * 0.5 - Vector2(270, 150), Vector2(540, 300))
 panel(canvas, r, Color("17222a"), AMBER)
 text(canvas, "POWER PLANT PROTOTYPE", r.position + Vector2(28, 44), 24, TEXT)
 text(canvas, "Build the plant, not just the courtyard.", r.position + Vector2(28, 73), 14, AMBER)
 wrapped(canvas, "Boilers raise steam. Pipes physically route it. Turbines turn delivered steam into MW. Transformers and switchyard bays limit how much power can leave the site. Cooling prevents thermal derating. Sell electricity, earn funds, and hold output targets to unlock a larger yard and heavier equipment.", r.position + Vector2(28, 111), r.size.x - 56, 13, MUTED)
 text(canvas, "Tap anywhere to begin", r.position + Vector2(28, r.size.y - 27), 14, GREEN)

static func help_data(index: int, model: BloomSimulation) -> Dictionary:
 match index:
  0: return {"title":"POWER OUTPUT", "body":"MW that can actually leave the plant after turbine output, temperature derating, and grid export capacity are applied."}
  1: return {"title":"GRID DEMAND", "body":"Current customer demand. Only power up to this amount earns revenue, so overbuilding generation too early ties up funds."}
  2: return {"title":"HEADROOM", "body":"Unused transformer and switchyard export capacity. A plant can have plenty of steam and turbine output but still bottleneck here."}
  3: return {"title":"STEAM", "body":"Steam successfully delivered through connected pipes. Pipe capacity is local: one narrow segment can starve several turbines."}
  4: return {"title":"TEMPERATURE", "body":"Hottest equipment temperature. Turbine output begins derating above 65°C and collapses if the plant is allowed to overheat."}
 return {"title":"PLANT METRIC", "body":"Operational status."}

static func draw_help(canvas: CanvasItem, model: BloomSimulation, view: Vector2, index: int) -> void:
 canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.02, 0.02, 0.50))
 var data := help_data(index, model)
 var r := Rect2(view * 0.5 - Vector2(240, 110), Vector2(480, 220))
 panel(canvas, r, Color("1b262e"), AMBER)
 text(canvas, data.title, r.position + Vector2(24, 43), 20, TEXT)
 wrapped(canvas, data.body, r.position + Vector2(24, 82), r.size.x - 48, 13, MUTED)
 text(canvas, "Tap outside to close", r.position + Vector2(24, r.size.y - 24), 11, AMBER)
