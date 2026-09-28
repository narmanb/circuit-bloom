extends RefCounted
class_name BloomInterfaceArt

const Catalog = preload("res://scripts/Catalog.gd")
const BoardArt = preload("res://scripts/rendering/BoardArt.gd")
const TOP := 129.0
const BOTTOM := 35.0
const INSPECT_W := 274.0
const RAIL_W := 150.0
const FLYOUT_W := 246.0
const LEFT_W := RAIL_W + FLYOUT_W
const CATEGORIES := ["Connections", "Power", "Compute", "Cooling", "Support", "Tools"]
const ACTIONS := ["undo", "redo", "power", "heat", "speed", "pause"]
const BG := Color("111821")
const PANEL := Color("1c2630")
const BORDER := Color("5d6870")
const MUTED := Color("a5adb0")
const TEXT := Color("f0eee5")
const MINT := Color("95c99b")
const AMBER := Color("d5a85a")
const COOL := Color("74b8d0")
const RED := Color("e3836a")

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
 return Rect2(RAIL_W + 8, TOP + 65 + index * 83, FLYOUT_W - 16, 77)

static func text(canvas: CanvasItem, value: String, pos: Vector2, px := 14, tint := TEXT, max_width := -1.0) -> void:
 canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, px, tint)

static func panel(canvas: CanvasItem, rect: Rect2, fill := PANEL, edge := BORDER) -> void:
 canvas.draw_rect(rect, fill)
 canvas.draw_rect(rect, edge, false, 1.1)
 canvas.draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(16, 1), AMBER.darkened(0.25), 2)
 canvas.draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(1, 12), AMBER.darkened(0.25), 2)

static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, tint: Color) -> void:
 canvas.draw_rect(rect, Color("0b1218"))
 if fraction > 0.005:
  canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), tint)
 canvas.draw_rect(rect, Color("626b67"), false, 1)

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
 if p.id in ["gland", "reactor"]: return "GENERATING"
 if p.id == "radiator": return "DISSIPATING HEAT"
 if p.id == "capacitor": return "CHARGING" if p.flow > 0.1 else ("DISCHARGING" if p.flow < -0.1 else "STORED")
 if p.ratio <= 0.001: return "OFFLINE"
 if p.ratio < 0.4: return "UNSTABLE"
 if p.ratio < 0.7: return "BROWNOUT"
 if p.ratio < 0.9: return "UNDERPOWERED"
 if temperature >= 85.0: return "HEAT DANGER"
 if temperature >= 70.0: return "THERMAL THROTTLE"
 return "ONLINE"

static func draw(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String, selection: int, overlay: String, paused: bool, speed: int, tutorial: int, message: String, message_time: float, help_index: int, zoom: float) -> void:
 draw_header(canvas, model, view, overlay, paused, speed)
 draw_build_rail(canvas, model, view, category, tool)
 draw_inspector(canvas, model, view, selection)
 draw_status(canvas, model, view, tool, zoom)
 if tutorial == 0: draw_tutorial(canvas, view)
 elif help_index >= 0: draw_help(canvas, model, view, help_index)
 if message_time > 0.0:
  var rect := Rect2(LEFT_W + 25, TOP + 10, minf(460, view.x - LEFT_W - INSPECT_W - 50), 45)
  panel(canvas, rect, Color("39422f"), AMBER)
  text(canvas, message, rect.position + Vector2(12, 29), 15, TEXT, rect.size.x - 22)

static func draw_header(canvas: CanvasItem, model: BloomSimulation, view: Vector2, overlay: String, paused: bool, speed: int) -> void:
 canvas.draw_rect(Rect2(0, 0, view.x, TOP), BG)
 canvas.draw_line(Vector2(0, TOP - 1), Vector2(view.x, TOP - 1), AMBER.darkened(0.35), 1.5)
 text(canvas, "CIRCUIT BLOOM", Vector2(16, 30), 22, TEXT)
 text(canvas, "BOARD 01  /  LIVING HARDWARE", Vector2(17, 43), 10, MUTED)
 for i in ACTIONS.size():
  var id: String = ACTIONS[i]
  var rect := action_rect(i, view)
  var active := (id == overlay) or (id == "pause" and paused)
  panel(canvas, rect, Color("444531") if active else PANEL, AMBER if active else BORDER)
  draw_action_icon(canvas, id, rect.position + Vector2(17, 17), paused, AMBER if active else TEXT)
  var caption := "%dx" % speed if id == "speed" else ("Play" if id == "pause" and paused else id.capitalize())
  text(canvas, caption, rect.position + Vector2(32, 24), 10, TEXT)
 var metrics := [
  {"name":"COMPUTATION", "value":"%.1f CU/s" % model.compute, "sub":"Peak %.1f" % model.peak, "fill":clampf(model.compute / maxf(50.0, model.peak), 0.0, 1.0), "color":MINT},
  {"name":"POWER DELIVERED", "value":"%d / %d" % [roundi(model.delivered), roundi(model.requested)], "sub":"%d generated" % roundi(model.generation), "fill":clampf(model.delivered / maxf(1.0, model.requested), 0.0, 1.0), "color":AMBER},
  {"name":"HEADROOM", "value":"%+d" % roundi(model.generation - model.delivered), "sub":"Generation - delivery", "fill":clampf((model.generation - model.delivered) / maxf(1.0, model.generation), 0.0, 1.0), "color":AMBER},
  {"name":"HOTTEST CELL", "value":"%.0f°C" % model.hottest, "sub":"Throttles above 65°C", "fill":clampf((model.hottest - 25.0) / 70.0, 0.0, 1.0), "color":RED if model.hottest >= 70.0 else COOL}
 ]
 for i in metrics.size():
  var item: Dictionary = metrics[i]
  var rect := metric_rect(i, view)
  panel(canvas, rect, Color("222d33"))
  text(canvas, item.name + "  ⓘ", rect.position + Vector2(10, 13), 10, MUTED)
  text(canvas, item.value, rect.position + Vector2(10, 37), 20, item.color)
  text(canvas, item.sub, rect.position + Vector2(rect.size.x * 0.58, 34), 10, MUTED, rect.size.x * 0.39)
  bar(canvas, Rect2(rect.position + Vector2(9, 49), Vector2(rect.size.x - 18, 3)), item.fill, item.color)
 if model.level < Catalog.GOALS.size():
  var goal: Dictionary = Catalog.GOALS[model.level]
  text(canvas, "NEXT  " + goal.name, Vector2(16, 122), 11, AMBER)
  text(canvas, "%d CU/s  •  %.0f / %.0f s" % [roundi(goal.target), model.sustain, goal.seconds], Vector2(216, 122), 11, TEXT)
  bar(canvas, Rect2(Vector2(467, 114), Vector2(maxf(50, view.x - 483), 6)), minf(1, model.sustain / float(goal.seconds)), MINT)
 else:
  text(canvas, "AWAKENING COMPLETE  /  SANDBOX CONTINUES", Vector2(16, 122), 11, MINT)

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
  "speed":
   canvas.draw_polyline(PackedVector2Array([c + Vector2(-8, -8), c + Vector2(1, 0), c + Vector2(-8, 8)]), tint, 2.5)
  "pause":
   if paused: canvas.draw_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(7, 0), c + Vector2(-5, 8)]), PackedColorArray([tint]))
   else:
    canvas.draw_rect(Rect2(c + Vector2(-7, -8), Vector2(4, 16)), tint)
    canvas.draw_rect(Rect2(c + Vector2(3, -8), Vector2(4, 16)), tint)

static func module_color(id: String) -> Color:
 if id in ["gland", "reactor"]: return AMBER if id == "gland" else RED
 if id in ["processor", "cluster"]: return Color("b7a6df")
 if id in ["radiator", "cooler"]: return COOL
 if id == "capacitor": return Color("deb973")
 return MINT

static func draw_build_rail(canvas: CanvasItem, model: BloomSimulation, view: Vector2, category: String, tool: String) -> void:
 var rail := Rect2(0, TOP, RAIL_W, view.y - TOP - BOTTOM)
 panel(canvas, rail, Color("151f25"), BORDER)
 text(canvas, "BUILD", Vector2(16, TOP + 31), 14, AMBER)
 for i in CATEGORIES.size():
  var name: String = CATEGORIES[i]
  var rect := category_rect(i, view)
  var active := name == category
  panel(canvas, rect, Color("51452e") if active else Color("253036"), AMBER if active else BORDER)
  BoardArt.symbol(canvas, name, rect.position + Vector2(19, 25), 0.70, AMBER if active else MUTED)
  text(canvas, name, rect.position + Vector2(39, 31), 12, TEXT if active else MUTED, rect.size.x - 43)
  if active: canvas.draw_polygon(PackedVector2Array([rect.end + Vector2(0, -32), rect.end + Vector2(9, -26), rect.end + Vector2(0, -20)]), PackedColorArray([AMBER]))
 if category.is_empty(): return
 var fly := Rect2(RAIL_W, TOP + 8, FLYOUT_W, view.y - TOP - BOTTOM - 16)
 panel(canvas, fly, Color("202c2e"), Color("7c785b"))
 text(canvas, category.to_upper() + "  /  MODULES", fly.position + Vector2(13, 25), 12, AMBER)
 text(canvas, "Choose a part, then tap the board.", fly.position + Vector2(13, 45), 11, MUTED)
 for i in items_for(category).size():
  var id: String = items_for(category)[i]
  var rect := part_rect(i, view)
  var d: Dictionary = Catalog.PARTS.get(id, {})
  var locked: bool = d.get("unlock", 0) > model.level
  var active := tool == id or (id == "select" and tool == "")
  panel(canvas, rect, Color("4c4a30") if active else (Color("20282b") if locked else Color("30383a")), AMBER if active else BORDER)
  var tint := MUTED if locked else module_color(id)
  canvas.draw_rect(Rect2(rect.position + Vector2(8, 10), Vector2(43, 57)), Color("141e22"))
  BoardArt.symbol(canvas, id, rect.position + Vector2(29, 38), 1.0, tint)
  var title: String = "Inspect / Pan" if id == "select" else ("Remove" if id == "remove" else d.name)
  text(canvas, title, rect.position + Vector2(58, 23), 15, TEXT if not locked else MUTED, rect.size.x - 65)
  var line: String = "Tap a component" if id == "select" else ("Full refund" if id == "remove" else ("UNLOCK: " + Catalog.GOALS[int(d.unlock) - 1].name if locked else "%d capacity" % d.cost))
  text(canvas, line, rect.position + Vector2(58, 42), 11, AMBER if locked else tint, rect.size.x - 65)
  var stats: String = "Drag to pan" if id == "select" else ("Tap to clear" if id == "remove" else summary_of(d))
  text(canvas, stats, rect.position + Vector2(58, 61), 10, MUTED, rect.size.x - 65)
 text(canvas, "Build capacity", fly.position + Vector2(13, fly.size.y - 77), 11, MUTED)
 text(canvas, "%d / %d" % [model.biomass_used(), model.biomass_max], fly.position + Vector2(13, fly.size.y - 53), 18, TEXT)
 bar(canvas, Rect2(fly.position + Vector2(13, fly.size.y - 40), Vector2(fly.size.x - 26, 7)), float(model.biomass_used()) / model.biomass_max, AMBER)
 text(canvas, "Removing parts refunds all capacity.", fly.position + Vector2(13, fly.size.y - 17), 10, MUTED)

static func summary_of(d: Dictionary) -> String:
 if d.has("generate"): return "+%d power • %.0f heat" % [roundi(d.generate), d.heat]
 if d.has("compute"): return "%d CU/s • %d power" % [roundi(d.compute), roundi(d.request)]
 if d.has("capacity"): return "%d power throughput" % roundi(d.capacity)
 if d.has("cool"): return "%.1f local cooling" % float(d.cool)
 if d.has("storage"): return "%d energy storage" % roundi(d.storage)
 return ""

static func draw_status(canvas: CanvasItem, model: BloomSimulation, view: Vector2, tool: String, zoom: float) -> void:
 canvas.draw_rect(Rect2(0, view.y - BOTTOM, view.x, BOTTOM), Color("171d22"))
 canvas.draw_line(Vector2(0, view.y - BOTTOM), Vector2(view.x, view.y - BOTTOM), AMBER.darkened(0.42), 1)
 text(canvas, "MODE  " + ("SELECT / PAN" if tool == "" else tool.to_upper()), Vector2(16, view.y - 12), 12, AMBER)
 text(canvas, "CAPACITY  %d / %d" % [model.biomass_used(), model.biomass_max], Vector2(220, view.y - 12), 12, TEXT)
 text(canvas, "ZOOM  %.0f%%" % (zoom * 100), Vector2(407, view.y - 12), 12, MUTED)
 text(canvas, "Tap components to inspect • Drag to pan • Pinch to zoom", Vector2(minf(view.x - 454, 610), view.y - 12), 11, MUTED)

static func draw_inspector(canvas: CanvasItem, model: BloomSimulation, view: Vector2, selection: int) -> void:
 var rect := Rect2(view.x - INSPECT_W - 10, TOP + 9, INSPECT_W, view.y - TOP - BOTTOM - 18)
 panel(canvas, rect, Color("202a2f"), Color("768179"))
 var x := rect.position.x + 14
 var y := rect.position.y
 if selection < 0 or selection >= model.parts.size():
  text(canvas, "SYSTEM INSPECTOR", Vector2(x, y + 26), 16, AMBER)
  canvas.draw_line(Vector2(x, y + 38), Vector2(rect.end.x - 14, y + 38), BORDER, 1)
  text(canvas, "Select a component", Vector2(x, y + 80), 18, TEXT)
  wrapped(canvas, "Tap a part to inspect power delivery, output, heat, capacity and its role in the circuit.", Vector2(x, y + 111), rect.size.x - 29, 13)
  text(canvas, "BOARD STATUS", Vector2(x, y + 198), 11, AMBER)
  text(canvas, "%d installed modules" % model.parts.size(), Vector2(x, y + 222), 14, TEXT)
  text(canvas, "%d / 24 active substrate" % model.active_size, Vector2(x, y + 246), 14, TEXT)
  text(canvas, "Circuits become a living city as you grow.", Vector2(x, y + 294), 11, MUTED, rect.size.x - 25)
  return
 var p: Dictionary = model.parts[selection]
 var d: Dictionary = Catalog.PARTS[p.id]
 var temp: float = model.heat[model.index(p.x, p.y)]
 var state := status_of(p, temp)
 var state_color := RED if state in ["OFFLINE", "BROWNOUT", "HEAT DANGER", "UNSTABLE"] else (AMBER if state in ["UNDERPOWERED", "THERMAL THROTTLE"] else MINT)
 text(canvas, "COMPONENT / " + d.category.to_upper(), Vector2(x, y + 20), 10, MUTED)
 text(canvas, d.name, Vector2(x, y + 46), 18, TEXT, rect.size.x - 71)
 BoardArt.symbol(canvas, p.id, Vector2(rect.end.x - 34, y + 36), 0.8, module_color(p.id))
 canvas.draw_rect(Rect2(x, y + 57, rect.size.x - 28, 29), Color("30393a"))
 canvas.draw_circle(Vector2(x + 11, y + 72), 3.5, state_color)
 text(canvas, state, Vector2(x + 23, y + 77), 12, state_color)
 canvas.draw_line(Vector2(x, y + 96), Vector2(rect.end.x - 14, y + 96), BORDER, 1)
 var output: String = "%.1f CU/s" % float(p.compute) if d.has("compute") else ("%.0f power generated" % float(d.generate) if d.has("generate") else ("%.1f / %.0f flow" % [p.load, d.capacity] if d.has("capacity") else ("%.1f / %.0f stored" % [p.stored, d.storage] if d.has("storage") else ("%.1f cooling" % float(d.cool) if d.has("cool") else "CONTROL ORGAN"))))
 text(canvas, "CURRENT OUTPUT", Vector2(x, y + 117), 10, MUTED)
 text(canvas, output, Vector2(x, y + 144), 20, module_color(p.id))
 text(canvas, "POWER DELIVERY", Vector2(x, y + 172), 11, MUTED)
 var requested: float = d.get("request", 0.0)
 var supply := "%.1f / %.1f  (%.0f%%)" % [p.power, requested, p.ratio * 100.0] if requested > 0 else "No power required"
 text(canvas, supply, Vector2(x, y + 193), 14, TEXT)
 bar(canvas, Rect2(x, y + 202, rect.size.x - 28, 8), p.ratio if requested > 0 else 1.0, MINT if p.ratio >= 0.7 or requested == 0 else RED)
 text(canvas, "LOCAL TEMPERATURE", Vector2(x, y + 240), 11, MUTED)
 text(canvas, "%.1f°C" % temp, Vector2(x, y + 261), 17, RED if temp >= 70 else COOL)
 bar(canvas, Rect2(x, y + 271, rect.size.x - 28, 8), (temp - 25) / 70, RED if temp >= 70 else COOL)
 text(canvas, "Heat +%.1f/s     Cooling %.1f/s" % [d.get("heat", 0.0), d.get("cool", 0.0)], Vector2(x, y + 303), 12, MUTED)
 if d.has("capacity"): text(canvas, "Throughput %.1f / %.0f" % [p.load, d.capacity], Vector2(x, y + 326), 12, TEXT)
 elif d.has("storage"): text(canvas, "Charge rate %+.1f/s" % float(p.flow), Vector2(x, y + 326), 12, TEXT)
 else: text(canvas, "Build capacity %d" % d.cost, Vector2(x, y + 326), 12, TEXT)
 canvas.draw_line(Vector2(x, y + 344), Vector2(rect.end.x - 14, y + 344), BORDER, 1)
 wrapped(canvas, d.description, Vector2(x, y + 368), rect.size.x - 29, 12)

static func help_data(index: int, model: BloomSimulation) -> Dictionary:
 match index:
  0: return {"title":"COMPUTATION  /  CU/s", "value":"%.1f CU/s now • %.1f peak" % [model.compute, model.peak], "body":"Powered processor cells produce compute units per second. Heat throttles output even when power is sufficient. Milestones require the target rate to be sustained; the peak is only a record."}
  1: return {"title":"POWER DELIVERED", "value":"%.0f delivered / %.0f requested" % [model.delivered, model.requested], "body":"Generators supply power through connected conductive tissue. A disconnected processor or an overloaded narrow conductor can receive too little power even if total generation is high. Inspect a part to see its delivered percentage."}
  2: return {"title":"HEADROOM", "value":"%+d power" % roundi(model.generation - model.delivered), "body":"Generation minus currently delivered load. Positive headroom means some power is unused; it does not prove every route has enough throughput. Capacitors can briefly make delivery exceed generation, turning this value negative."}
  3: return {"title":"HOTTEST CELL", "value":"%.1f°C" % model.hottest, "body":"This is the hottest cell on the board. Heat spreads locally from processors and generators. Processors begin throttling above 65°C, and cooling works best near the source. Use the Heat overlay to find hot spots."}
 return {}

static func draw_help(canvas: CanvasItem, model: BloomSimulation, view: Vector2, index: int) -> void:
 var left := LEFT_W + 15.0
 var right := view.x - INSPECT_W - 22.0
 canvas.draw_rect(Rect2(left, TOP, right - left, view.y - TOP - BOTTOM), Color(0.03, 0.06, 0.07, 0.62))
 var width := minf(465.0, right - left - 30.0)
 var rect := Rect2(left + (right - left - width) * 0.5, TOP + 30, width, 218)
 panel(canvas, rect, Color("303936"), AMBER)
 var info := help_data(index, model)
 text(canvas, info.title, rect.position + Vector2(17, 29), 17, AMBER)
 text(canvas, info.value, rect.position + Vector2(17, 59), 19, TEXT)
 canvas.draw_line(rect.position + Vector2(17, 75), rect.position + Vector2(width - 17, 75), BORDER, 1)
 wrapped(canvas, info.body, rect.position + Vector2(17, 101), width - 34, 14, TEXT)
 text(canvas, "TAP ANYWHERE TO CLOSE", rect.position + Vector2(17, 201), 10, MUTED)

static func draw_tutorial(canvas: CanvasItem, view: Vector2) -> void:
 var rect := Rect2(LEFT_W + 18, TOP + 35, minf(510, view.x - LEFT_W - INSPECT_W - 35), 164)
 panel(canvas, rect, Color("313d35"), AMBER)
 text(canvas, "THE CIRCUIT IS ALIVE", rect.position + Vector2(18, 34), 21, AMBER)
 wrapped(canvas, "Power travels along routes. Processors compute and heat up; nearby cooling keeps them fast.", rect.position + Vector2(18, 66), rect.size.x - 36, 15, TEXT)
 text(canvas, "Build to reach 50 CU/s. Tap to begin.", rect.position + Vector2(18, 145), 14, MINT)
