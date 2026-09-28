extends RefCounted
class_name BloomInterfaceArt

const Catalog = preload("res://scripts/Catalog.gd")
const BoardArt = preload("res://scripts/rendering/BoardArt.gd")
const TOP := 132.0
const DOCK := 142.0
const INSPECT_W := 282.0
const CATEGORIES := ["Connections", "Power", "Compute", "Cooling", "Support", "Tools"]
const ACTIONS := ["undo", "redo", "power", "heat", "speed", "pause"]
const BG := Color("08151e")
const PANEL := Color("10232d")
const BORDER := Color("38565d")
const MUTED := Color("91aeb0")
const TEXT := Color("e3f2e9")
const MINT := Color("86e5bd")
const AMBER := Color("ecc186")
const COOL := Color("75cce6")
const RED := Color("f09b7c")

static func items_for(category: String) -> Array[String]:
 var result: Array[String] = []
 if category == "Tools": return ["select", "remove"]
 for id in Catalog.ORDER:
  if Catalog.PARTS[id].category == category: result.append(id)
 return result

static func action_rect(index: int, view: Vector2) -> Rect2:
 return Rect2(view.x - 390 + index * 64, 6, 60, 38)

static func category_rect(index: int, view: Vector2) -> Rect2:
 var width := minf(135.0, (view.x - 28.0) / CATEGORIES.size())
 return Rect2(14 + index * width, view.y - DOCK + 5, width - 4, 34)

static func part_rect(index: int, view: Vector2) -> Rect2:
 var width := minf(218.0, (view.x - 30.0) / 3.0)
 return Rect2(14 + index * (width + 6), view.y - 99, width, 88)

static func text(canvas: CanvasItem, value: String, pos: Vector2, px := 14, tint := TEXT, max_width := -1.0) -> void:
 canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, px, tint)

static func panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, edge := BORDER) -> void:
 canvas.draw_rect(rect, fill)
 canvas.draw_rect(rect, edge, false, 1.1)
 canvas.draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(18, 1), MINT.darkened(0.4), 2)
 canvas.draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(1, 13), MINT.darkened(0.4), 2)

static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, tint: Color) -> void:
 canvas.draw_rect(rect, Color("07131b"))
 if fraction > 0.005:
  canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), tint)
 canvas.draw_rect(rect, Color("395b5f"), false, 1.0)

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
 if p.id in ["vein", "bundle"]: return "CURRENT FLOWING" if p.load > 0.01 else "IDLE TRACE"
 if p.id == "gland": return "GENERATING"
 if p.id == "radiator": return "DISSIPATING HEAT"
 if p.id == "capacitor": return "CHARGING" if p.flow > 0.1 else ("DISCHARGING" if p.flow < -0.1 else "STORED")
 if p.ratio <= 0.001: return "OFFLINE"
 if p.ratio < 0.4: return "UNSTABLE"
 if p.ratio < 0.7: return "BROWNOUT"
 if p.ratio < 0.9: return "UNDERPOWERED"
 if temperature >= 85.0: return "HEAT DANGER"
 if temperature >= 70.0: return "THERMAL THROTTLE"
 return "ONLINE"

static func draw(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String, selection: int, overlay: String, paused: bool, speed: int, tutorial: int, message: String, message_time: float) -> void:
 draw_header(canvas, model, view, overlay, paused, speed)
 draw_dock(canvas, model, view, category, tool)
 draw_inspector(canvas, model, view, selection)
 if tutorial == 0: draw_tutorial(canvas, view)
 if message_time > 0.0:
  var rect := Rect2(view.x * 0.30, TOP + 9, view.x * 0.40, 43)
  panel(canvas, rect, Color("20423e"), MINT)
  text(canvas, message, rect.position + Vector2(13, 27), 15, TEXT, rect.size.x - 20)

static func draw_header(canvas: CanvasItem, model: BloomSimulation, view: Vector2, overlay: String, paused: bool, speed: int) -> void:
 canvas.draw_rect(Rect2(0, 0, view.x, TOP), BG)
 canvas.draw_line(Vector2(0, TOP - 1), Vector2(view.x, TOP - 1), Color("39605d"), 1)
 text(canvas, "CIRCUIT  BLOOM", Vector2(15, 29), 23, MINT)
 text(canvas, "LIVING SYSTEM / BOARD 01", Vector2(16, 43), 10, MUTED)
 for i in ACTIONS.size():
  var id: String = ACTIONS[i]
  var rect := action_rect(i, view)
  var active := (id == overlay) or (id == "pause" and paused)
  panel(canvas, rect, Color("28524e") if active else PANEL, MINT if active else BORDER)
  draw_action_icon(canvas, id, rect.position + Vector2(17, 17), speed, paused, MINT if active else TEXT)
  var caption := "1x" if id == "speed" and speed == 1 else ("%dx" % speed if id == "speed" else ("Play" if id == "pause" and paused else id.capitalize()))
  text(canvas, caption, rect.position + Vector2(32, 24), 10, TEXT)
 var gap := 7.0
 var width := (view.x - 30.0 - gap * 4.0) / 5.0
 var used: float = model.biomass_used()
 var metrics := [
  {"name":"COMPUTATION", "value":"%.1f CU/s" % model.compute, "sub":"Peak %.1f" % model.peak, "fill":clampf(model.compute / maxf(50.0, model.peak), 0.0, 1.0), "color":MINT},
  {"name":"POWER", "value":"%d / %d" % [roundi(model.delivered), roundi(model.requested)], "sub":"%d generated" % roundi(model.generation), "fill":clampf(model.delivered / maxf(1.0, model.requested), 0.0, 1.0), "color":MINT},
  {"name":"HEADROOM", "value":"%+d" % roundi(model.generation - model.delivered), "sub":"Generation - load", "fill":clampf((model.generation - model.delivered) / maxf(1.0, model.generation), 0.0, 1.0), "color":AMBER},
  {"name":"BIOMASS", "value":"%d / %d" % [int(used), model.biomass_max], "sub":"Capacity in use", "fill":used / maxf(1.0, model.biomass_max), "color":MINT},
  {"name":"HOTTEST CELL", "value":"%.0f°C" % model.hottest, "sub":"Safe below 70°C", "fill":clampf((model.hottest - 25.0) / 70.0, 0.0, 1.0), "color":RED if model.hottest >= 70.0 else COOL}
 ]
 for i in metrics.size():
  var item: Dictionary = metrics[i]
  var rect := Rect2(15 + i * (width + gap), 50, width, 57)
  panel(canvas, rect, Color("10242d"))
  text(canvas, item.name, rect.position + Vector2(10, 13), 10, MUTED)
  text(canvas, item.value, rect.position + Vector2(10, 35), 19, item.color)
  text(canvas, item.sub, rect.position + Vector2(width * 0.57, 33), 10, MUTED, width * 0.40)
  bar(canvas, Rect2(rect.position + Vector2(9, 47), Vector2(width - 18, 3)), item.fill, item.color)
 if model.level < Catalog.GOALS.size():
  var goal: Dictionary = Catalog.GOALS[model.level]
  var progress := minf(1.0, model.sustain / float(goal.seconds))
  text(canvas, "NEXT BLOOM  /  " + goal.name, Vector2(16, 125), 11, AMBER)
  text(canvas, "%d CU/s  •  %.0f / %.0f s" % [roundi(goal.target), model.sustain, goal.seconds], Vector2(225, 125), 11, TEXT)
  bar(canvas, Rect2(Vector2(475, 117), Vector2(maxf(50.0, view.x - 490), 6)), progress, MINT)
 else:
  text(canvas, "AWAKENING COMPLETE  /  SANDBOX CONTINUES", Vector2(16, 125), 11, MINT)

static func draw_action_icon(canvas: CanvasItem, id: String, center: Vector2, speed: int, paused: bool, tint: Color) -> void:
 match id:
  "undo", "redo":
   var direction := -1.0 if id == "undo" else 1.0
   canvas.draw_arc(center, 8, -2.4 if direction < 0 else -0.7, 1.7 if direction < 0 else 3.8, 18, tint, 2, true)
   canvas.draw_line(center + Vector2(direction * -7, -5), center + Vector2(direction * -12, -5), tint, 2)
  "power":
   canvas.draw_line(center + Vector2(-10, 1), center + Vector2(10, 1), tint, 2.5)
   canvas.draw_circle(center, 3, tint)
  "heat":
   canvas.draw_arc(center, 8, 0.3, 2.7, 18, tint, 2)
   canvas.draw_line(center + Vector2(0, 7), center + Vector2(3, -7), tint, 2)
  "speed":
   canvas.draw_polyline(PackedVector2Array([center + Vector2(-8, -8), center + Vector2(1, 0), center + Vector2(-8, 8)]), tint, 2.5)
  "pause":
   if paused:
    canvas.draw_polygon(PackedVector2Array([center + Vector2(-5, -8), center + Vector2(7, 0), center + Vector2(-5, 8)]), PackedColorArray([tint]))
   else:
    canvas.draw_rect(Rect2(center + Vector2(-7, -8), Vector2(4, 16)), tint)
    canvas.draw_rect(Rect2(center + Vector2(3, -8), Vector2(4, 16)), tint)

static func draw_dock(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String) -> void:
 canvas.draw_rect(Rect2(0, view.y - DOCK, view.x, DOCK), BG)
 canvas.draw_line(Vector2(0, view.y - DOCK), Vector2(view.x, view.y - DOCK), Color("47736d"), 1.3)
 for i in CATEGORIES.size():
  var name: String = CATEGORIES[i]
  var rect := category_rect(i, view)
  var active := name == category
  panel(canvas, rect, Color("254c48") if active else Color("10242c"), MINT if active else BORDER)
  BoardArt.symbol(canvas, name, rect.position + Vector2(16, 17), 0.53, MINT if active else MUTED)
  text(canvas, name, rect.position + Vector2(32, 22), 11, TEXT if active else MUTED)
 var tip := "TOOL: " + ("SELECT / PAN" if tool == "" else tool.to_upper())
 text(canvas, tip, Vector2(view.x - 260, view.y - DOCK + 28), 12, MINT)
 var items := items_for(category)
 for i in items.size():
  var id := items[i]
  var rect := part_rect(i, view)
  var definition: Dictionary = Catalog.PARTS.get(id, {})
  var locked: bool = definition.get("unlock", 0) > model.level
  var active := (tool == id) or (id == "select" and tool == "")
  var fill := Color("244b48") if active else (Color("101b25") if locked else Color("172f38"))
  panel(canvas, rect, fill, MINT if active else BORDER)
  var color: Color = MUTED if locked else (COOL if id in ["radiator", "cooler"] else (AMBER if id == "capacitor" else MINT))
  canvas.draw_rect(Rect2(rect.position + Vector2(9, 15), Vector2(50, 58)), Color("092028"))
  BoardArt.symbol(canvas, id, rect.position + Vector2(34, 43), 1.12, color)
  var title: String = "Inspect / Pan" if id == "select" else ("Remove" if id == "remove" else definition.name)
  text(canvas, title, rect.position + Vector2(68, 27), 15, TEXT if not locked else MUTED, rect.size.x - 74)
  var detail: String = "Tap a piece" if id == "select" else ("Refund biomass" if id == "remove" else ("UNLOCK: " + Catalog.GOALS[int(definition.unlock) - 1].name if locked else "%d BIOMASS" % definition.cost))
  text(canvas, detail, rect.position + Vector2(68, 47), 11, AMBER if locked else MINT, rect.size.x - 74)
  var desc: String = "Drag to pan" if id == "select" else ("Tap to clear" if id == "remove" else definition.description)
  text(canvas, desc, rect.position + Vector2(68, 67), 10, MUTED, rect.size.x - 74)
 text(canvas, "Tap a part to inspect  •  Drag board to pan  •  Pinch to zoom", Vector2(minf(view.x - 470, 715), view.y - 28), 12, MUTED)

static func draw_inspector(canvas: CanvasItem, model: BloomSimulation, view: Vector2, selection: int) -> void:
 var rect := Rect2(view.x - INSPECT_W - 12, TOP + 10, INSPECT_W, view.y - DOCK - TOP - 20)
 panel(canvas, rect, Color("0d2029"), Color("3a6662"))
 var x := rect.position.x + 14
 var y := rect.position.y
 if selection < 0 or selection >= model.parts.size():
  text(canvas, "SYSTEM INSPECTOR", Vector2(x, y + 26), 16, MINT)
  canvas.draw_line(Vector2(x, y + 38), Vector2(rect.end.x - 14, y + 38), BORDER, 1)
  text(canvas, "Select a component", Vector2(x, y + 80), 19, TEXT)
  wrapped(canvas, "Tap a cell to inspect power delivery, output, heat and capacity. Build tools are in the dock below.", Vector2(x, y + 112), rect.size.x - 29, 13)
  text(canvas, "ORGANISM STATUS", Vector2(x, y + 200), 11, AMBER)
  text(canvas, "%d placed modules" % model.parts.size(), Vector2(x, y + 224), 14, TEXT)
  text(canvas, "%d / 24 active substrate" % model.active_size, Vector2(x, y + 247), 14, TEXT)
  return
 var p: Dictionary = model.parts[selection]
 var d: Dictionary = Catalog.PARTS[p.id]
 var temp: float = model.heat[model.index(p.x, p.y)]
 var status := status_of(p, temp)
 var status_color := RED if status in ["OFFLINE", "BROWNOUT", "HEAT DANGER", "UNSTABLE"] else (AMBER if status in ["UNDERPOWERED", "THERMAL THROTTLE"] else MINT)
 text(canvas, "COMPONENT / " + d.category.to_upper(), Vector2(x, y + 20), 10, MUTED)
 text(canvas, d.name, Vector2(x, y + 45), 18, TEXT, rect.size.x - 72)
 BoardArt.symbol(canvas, p.id, Vector2(rect.end.x - 35, y + 36), 0.8, status_color)
 canvas.draw_rect(Rect2(x, y + 56, rect.size.x - 28, 28), Color("18313a"))
 canvas.draw_circle(Vector2(x + 11, y + 70), 3.4, status_color)
 text(canvas, status, Vector2(x + 24, y + 75), 12, status_color)
 canvas.draw_line(Vector2(x, y + 95), Vector2(rect.end.x - 14, y + 95), BORDER, 1)
 var primary: String = "%.1f CU/s" % float(p.compute) if d.has("compute") else ("%.0f produced" % float(d.generate) if d.has("generate") else ("%.1f / %.0f flow" % [p.load, d.capacity] if d.has("capacity") else ("%.1f / %.0f stored" % [p.stored, d.storage] if d.has("storage") else ("%.1f cooling" % float(d.cool) if d.has("cool") else "CONTROL ORGAN"))))
 text(canvas, "CURRENT OUTPUT", Vector2(x, y + 115), 10, MUTED)
 text(canvas, primary, Vector2(x, y + 140), 21, MINT)
 text(canvas, "POWER DELIVERY", Vector2(x, y + 168), 11, MUTED)
 var requested: float = d.get("request", 0.0)
 var supply := "%.1f / %.1f  (%.0f%%)" % [p.power, requested, p.ratio * 100.0] if requested > 0.0 else "No power required"
 text(canvas, supply, Vector2(x, y + 188), 14, TEXT)
 bar(canvas, Rect2(x, y + 198, rect.size.x - 28, 8), p.ratio if requested > 0.0 else 1.0, MINT if p.ratio >= 0.7 or requested == 0.0 else RED)
 text(canvas, "LOCAL TEMPERATURE", Vector2(x, y + 232), 11, MUTED)
 text(canvas, "%.1f°C" % temp, Vector2(x, y + 252), 17, RED if temp >= 70.0 else COOL)
 bar(canvas, Rect2(x, y + 262, rect.size.x - 28, 8), (temp - 25.0) / 70.0, RED if temp >= 70.0 else COOL)
 var details := "Heat +%.1f/s    Cooling %.1f/s" % [d.get("heat", 0.0), d.get("cool", 0.0)]
 text(canvas, details, Vector2(x, y + 292), 12, MUTED)
 if d.has("capacity"): text(canvas, "Throughput %.1f / %.0f" % [p.load, d.capacity], Vector2(x, y + 314), 12, TEXT)
 elif d.has("storage"): text(canvas, "Charge rate %+.1f/s" % float(p.flow), Vector2(x, y + 314), 12, TEXT)
 else: text(canvas, "Biomass cost %d" % d.cost, Vector2(x, y + 314), 12, TEXT)
 canvas.draw_line(Vector2(x, y + 326), Vector2(rect.end.x - 14, y + 326), BORDER, 1)
 wrapped(canvas, d.description, Vector2(x, y + 348), rect.size.x - 29, 12)

static func draw_tutorial(canvas: CanvasItem, view: Vector2) -> void:
 var rect := Rect2(view.x * 0.22, view.y * 0.35, view.x * 0.56, 150)
 panel(canvas, rect, Color("102c34"), MINT)
 text(canvas, "THE CIRCUIT IS ALIVE", rect.position + Vector2(20, 34), 22, MINT)
 wrapped(canvas, "Pulses carry power through copper tissue. Processors compute and heat up. Cooling preserves their output.", rect.position + Vector2(20, 64), rect.size.x - 40, 16, TEXT)
 text(canvas, "Build outward to reach 50 CU/s. Tap anywhere to begin.", rect.position + Vector2(20, 131), 15, AMBER)
