extends RefCounted
class_name BloomBoardArt

const Catalog = preload("res://scripts/Catalog.gd")
const BACKGROUND: Texture2D = preload("res://assets/power_plant_background.jpg")
const GRID := 24
const CELL := 34.0
const INK := Color("15191b")
const STEEL := Color("aeb7b9")
const DARK_STEEL := Color("4d585c")
const STEAM := Color("f0c86c")
const POWER := Color("75d7f0")
const COOL := Color("69bbdc")
const HOT := Color("ef7657")
const SAFETY := Color("ddb646")

static func bevel(center: Vector2, radius: float, cut := 3.0) -> PackedVector2Array:
 return PackedVector2Array([
  center + Vector2(-radius + cut, -radius), center + Vector2(radius - cut, -radius),
  center + Vector2(radius, -radius + cut), center + Vector2(radius, radius - cut),
  center + Vector2(radius - cut, radius), center + Vector2(-radius + cut, radius),
  center + Vector2(-radius, radius - cut), center + Vector2(-radius, -radius + cut)
 ])

static func symbol(canvas: CanvasItem, id: String, center: Vector2, scale: float, color: Color) -> void:
 var r := 13.0 * scale
 match id:
  "vein", "bundle", "Connections":
   var w := (5.0 if id == "bundle" else 3.2) * scale
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, w, true)
   canvas.draw_circle(center, 3.1 * scale, Color("d9e0dc"))
   if id == "bundle":
    canvas.draw_line(center + Vector2(-r, 5 * scale), center + Vector2(r, 5 * scale), color.darkened(0.28), 2 * scale, true)
  "gland", "Power":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.75, r * 0.55), Vector2(r * 1.5, r * 1.1)), color, false, 2.2 * scale)
   canvas.draw_polyline(PackedVector2Array([center + Vector2(-4, 6) * scale, center + Vector2(0, -7) * scale, center + Vector2(4, 6) * scale]), color.lightened(0.32), 2.2 * scale, true)
  "reactor":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.82, r * 0.65), Vector2(r * 1.64, r * 1.3)), color, false, 2.3 * scale)
   canvas.draw_arc(center, r * 0.45, 0, TAU, 20, color.lightened(0.35), 2.0 * scale)
  "processor", "cluster", "Compute":
   canvas.draw_arc(center, r * 0.72, 0, TAU, 24, color, 2.5 * scale, true)
   for k in 5:
    var a := TAU * float(k) / 5.0
    canvas.draw_line(center, center + Vector2(cos(a), sin(a)) * r * 0.58, color.lightened(0.22), 2 * scale, true)
   canvas.draw_circle(center, 2.8 * scale, color.lightened(0.35))
  "radiator", "cooler", "Cooling":
   canvas.draw_arc(center, r * 0.75, 0, TAU, 28, color, 2.2 * scale, true)
   for k in 4:
    var a := TAU * float(k) / 4.0
    canvas.draw_line(center, center + Vector2(cos(a), sin(a)) * r * 0.65, color, 2.0 * scale, true)
  "capacitor", "Support":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.55, r * 0.78), Vector2(r * 1.1, r * 1.56)), color, false, 2.2 * scale)
   canvas.draw_arc(center + Vector2(0, -r * 0.78), r * 0.55, PI, TAU, 18, color, 2.2 * scale)
  "select", "Tools":
   canvas.draw_arc(center, r * 0.8, 0, TAU, 28, color, 2 * scale, true)
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, 1.4 * scale)
   canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, 1.4 * scale)
  "remove":
   canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), color, 3 * scale, true)
   canvas.draw_line(center + Vector2(r * 0.7, -r * 0.7), center + Vector2(-r * 0.7, r * 0.7), color, 3 * scale, true)

static func draw_board(canvas: CanvasItem, model: BloomSimulation, tick: float, overlay: String, tool: String, selection: int, preview_cell: Vector2i, preview_ok: bool) -> void:
 var total := GRID * CELL
 canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, total, total), false, Color(0.80, 0.80, 0.76, 1.0))
 canvas.draw_rect(Rect2(0, 0, total, total), Color(0.03, 0.05, 0.055, 0.12))
 var low := (GRID - model.active_size) / 2
 var build_rect := Rect2(Vector2(low, low) * CELL, Vector2.ONE * model.active_size * CELL)
 canvas.draw_rect(build_rect, Color(0.16, 0.18, 0.17, 0.10))
 canvas.draw_rect(build_rect.grow(3), SAFETY, false, 2.0)
 canvas.draw_rect(build_rect.grow(7), Color(0.08, 0.09, 0.09, 0.7), false, 1.0)
 if tool != "":
  for y in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(low, y) * CELL, Vector2(low + model.active_size, y) * CELL, Color(0.92, 0.82, 0.54, 0.16), 0.8)
  for x in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(x, low) * CELL, Vector2(x, low + model.active_size) * CELL, Color(0.92, 0.82, 0.54, 0.16), 0.8)
 if overlay == "heat":
  for y in GRID:
   for x in GRID:
    var temp: float = model.heat[model.index(x, y)]
    var amount := clampf((temp - 30.0) / 65.0, 0.0, 0.62)
    if amount > 0.01:
     canvas.draw_circle(Vector2(x + 0.5, y + 0.5) * CELL, CELL * 0.78, Color(1.0, 0.24 if temp > 75.0 else 0.62, 0.05, amount))
 for p in model.parts:
  if p.id in ["vein", "bundle"]:
   draw_pipe(canvas, model, p, overlay)
 for p in model.parts:
  if not p.id in ["vein", "bundle"]:
   draw_part(canvas, model, p, tick, overlay)
 if selection >= 0 and selection < model.parts.size():
  var p: Dictionary = model.parts[selection]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  draw_brackets(canvas, Rect2(Vector2(p.x, p.y) * CELL - Vector2.ONE * 2, Vector2.ONE * (CELL * sz + 4)), Color("fff0a8"))
 if preview_cell.x >= 0 and tool != "":
  var sz: int = Catalog.PARTS.get(tool, {}).get("size", 1)
  var rect := Rect2(Vector2(preview_cell) * CELL, Vector2.ONE * CELL * sz)
  canvas.draw_rect(rect, Color(0.28, 0.96, 0.69, 0.22) if preview_ok else Color(0.95, 0.35, 0.25, 0.22))
  draw_brackets(canvas, rect, STEAM if preview_ok else HOT)
 if model.bloom_time > 0.0:
  var wave := (2.0 - model.bloom_time) * 360.0
  canvas.draw_arc(Vector2(12, 12) * CELL, wave, 0, TAU, 80, Color(1.0, 0.76, 0.26, model.bloom_time / 2.0), 3.0)

static func draw_pipe(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, overlay: String) -> void:
 var c := Vector2(p.x + 0.5, p.y + 0.5) * CELL
 var thick := 8.0 if p.id == "bundle" else 5.5
 var energized := p.load > 0.01
 var base := Color("3e494d")
 var edge := Color("aeb6b3")
 var flow := STEAM if energized else Color("7e8c8e")
 var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
 var drew := false
 for dir in dirs:
  var q := Vector2i(p.x, p.y) + dir
  if q.x < 0 or q.y < 0 or q.x >= GRID or q.y >= GRID: continue
  var j := model.at(q.x, q.y)
  if j < 0: continue
  var other: Dictionary = model.parts[j]
  if other.id == "core" or Catalog.PARTS[other.id].has("ports"):
   var end := c + Vector2(dir) * CELL * 0.52
   canvas.draw_line(c, end, INK, thick + 3.0, true)
   canvas.draw_line(c, end, base, thick, true)
   canvas.draw_line(c, end, edge, maxf(1.2, thick * 0.23), true)
   if energized: canvas.draw_line(c, end, flow, maxf(1.0, thick * 0.16), true)
   drew = true
 if not drew:
  canvas.draw_line(c + Vector2(-CELL * 0.45, 0), c + Vector2(CELL * 0.45, 0), INK, thick + 3.0, true)
  canvas.draw_line(c + Vector2(-CELL * 0.45, 0), c + Vector2(CELL * 0.45, 0), base, thick, true)
  canvas.draw_line(c + Vector2(-CELL * 0.45, 0), c + Vector2(CELL * 0.45, 0), edge, maxf(1.2, thick * 0.23), true)
 canvas.draw_circle(c, thick * 0.72, DARK_STEEL)
 canvas.draw_circle(c, thick * 0.42, flow if energized else STEEL.darkened(0.25))
 if overlay == "power": canvas.draw_circle(c, 8.0, Color(1.0, 0.72, 0.18, 0.20 if energized else 0.05))

static func draw_part(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, tick: float, overlay: String) -> void:
 var d: Dictionary = Catalog.PARTS[p.id]
 var sz: int = d.get("size", 1)
 var rect := Rect2(Vector2(p.x, p.y) * CELL + Vector2(2, 2), Vector2.ONE * (CELL * sz - 4))
 var c := rect.get_center()
 var energized := p.ratio > 0.05 or p.id in ["gland", "reactor", "radiator"]
 canvas.draw_rect(rect.grow(2), Color(0.04, 0.05, 0.05, 0.78))
 canvas.draw_rect(rect, Color(0.23, 0.25, 0.24, 0.93))
 canvas.draw_rect(rect, Color(0.70, 0.67, 0.56, 0.36), false, 1.2)
 match p.id:
  "core":
   canvas.draw_rect(rect.grow(-4), Color("555b58"))
   canvas.draw_rect(Rect2(rect.position + Vector2(6, 7), Vector2(rect.size.x - 12, rect.size.y - 13)), Color("252b2b"))
   canvas.draw_rect(Rect2(rect.position + Vector2(8, 3), Vector2(rect.size.x - 16, 5)), Color("788286"))
   canvas.draw_circle(c + Vector2(0, 6), 2.5, Color("76e19a") if energized else Color("6a756d"))
  "gland", "reactor":
   var furnace := HOT if p.id == "reactor" else Color("d98a45")
   canvas.draw_rect(rect.grow(-5), Color("62686a"))
   canvas.draw_rect(Rect2(rect.position + Vector2(7, rect.size.y - 12), Vector2(rect.size.x - 14, 6)), furnace.darkened(0.25))
   var flicker := 0.65 + sin(tick * 6.0 + p.x) * 0.18
   canvas.draw_circle(c + Vector2(0, 5), 5.0, furnace.lightened(flicker * 0.15))
   canvas.draw_line(rect.position + Vector2(7, 7), rect.position + Vector2(rect.size.x - 7, 7), STEEL, 2)
  "processor":
   canvas.draw_circle(c + Vector2(-4, 0), 8.2, Color("6d7375"))
   canvas.draw_circle(c + Vector2(-4, 0), 5.2, Color("32383a"))
   canvas.draw_circle(c + Vector2(7, 0), 6.2, Color("315b72"))
   canvas.draw_line(c, c + Vector2(5, 0), STEEL, 3)
   if energized: canvas.draw_arc(c + Vector2(-4, 0), 6.2, tick * 2.5, tick * 2.5 + 4.9, 18, POWER, 1.6, true)
  "cluster":
   canvas.draw_rect(rect.grow(-5), Color("4d5558"))
   for row in 2:
    var tc := rect.position + Vector2(rect.size.x * (0.28 + row * 0.43), rect.size.y * 0.50)
    canvas.draw_circle(tc, 12, Color("727b7d"))
    canvas.draw_circle(tc, 7, Color("273238"))
    canvas.draw_arc(tc, 9, tick * 2.0 + row, tick * 2.0 + row + 5.0, 20, POWER if energized else STEEL, 1.8, true)
   canvas.draw_line(rect.position + Vector2(8, rect.size.y - 10), rect.position + Vector2(rect.size.x - 8, rect.size.y - 10), SAFETY, 2)
  "radiator":
   canvas.draw_circle(c, 12, Color("c0c5c2"))
   canvas.draw_circle(c, 9, Color("30383a"))
   for k in 6:
    var a := tick * 0.35 + TAU * float(k) / 6.0
    canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * 7.0, COOL, 2.0, true)
  "cooler":
   canvas.draw_rect(rect.grow(-4), Color("5d686b"))
   for k in 4:
    var x := rect.position.x + 8 + k * (rect.size.x - 16) / 3.0
    canvas.draw_line(Vector2(x, rect.position.y + 6), Vector2(x, rect.end.y - 6), COOL, 2)
   canvas.draw_line(rect.position + Vector2(5, rect.size.y - 7), rect.end - Vector2(5, 7), STEEL, 2)
  "capacitor":
   canvas.draw_rect(Rect2(c - Vector2(8, 11), Vector2(16, 22)), Color("687173"))
   canvas.draw_arc(c + Vector2(0, -11), 8, PI, TAU, 20, STEEL, 2)
   var fill := clampf(float(p.stored) / float(d.storage), 0.0, 1.0)
   canvas.draw_rect(Rect2(c + Vector2(-6, 8 - 16 * fill), Vector2(12, 16 * fill)), Color(0.88, 0.66, 0.23, 0.72))
 if overlay == "power":
  var halo := Color(0.25, 0.93, 0.98, 0.18) if energized else Color(0.90, 0.25, 0.18, 0.09)
  canvas.draw_rect(rect.grow(3), halo, false, 3.0)

static func draw_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
 var l := 8.0
 for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
  var sx := 1.0 if corner.x == rect.position.x else -1.0
  var sy := 1.0 if corner.y == rect.position.y else -1.0
  canvas.draw_line(corner, corner + Vector2(sx * l, 0), color, 2.0)
  canvas.draw_line(corner, corner + Vector2(0, sy * l), color, 2.0)
