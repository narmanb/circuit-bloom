extends RefCounted
class_name BloomBoardArt

const Catalog = preload("res://scripts/Catalog.gd")
const BACKGROUND: Texture2D = preload("res://assets/power_plant_background.jpg")
const GRID := 24
const CELL := 34.0
const INK := Color("111719")
const STEEL := Color("b5bec0")
const DARK_STEEL := Color("465156")
const PIPE := Color("66777c")
const STEAM := Color("f0bd57")
const POWER := Color("56c6ed")
const COOL := Color("5bb9d7")
const HOT := Color("ee6649")
const SAFETY := Color("d5a934")
const CONCRETE := Color("a59d8c")

static func symbol(canvas: CanvasItem, id: String, center: Vector2, scale: float, color: Color) -> void:
 var r := 13.0 * scale
 match id:
  "vein", "bundle", "Pipes":
   var w := (5.0 if id == "bundle" else 3.0) * scale
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, w, true)
   canvas.draw_circle(center, 3.2 * scale, STEEL)
   if id == "bundle": canvas.draw_line(center + Vector2(-r, 5 * scale), center + Vector2(r, 5 * scale), color.darkened(0.28), 2.0 * scale, true)
  "gland", "reactor", "Build":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.78, r * 0.55), Vector2(r * 1.56, r * 1.10)), color, false, 2.1 * scale)
   canvas.draw_polyline(PackedVector2Array([center + Vector2(-4, 6) * scale, center + Vector2(0, -7) * scale, center + Vector2(4, 6) * scale]), color.lightened(0.30), 2.0 * scale, true)
  "processor", "cluster":
   canvas.draw_circle(center, r * 0.72, color, false, 2.3 * scale)
   for k in 5:
    var a := TAU * float(k) / 5.0
    canvas.draw_line(center, center + Vector2(cos(a), sin(a)) * r * 0.58, color.lightened(0.25), 1.8 * scale, true)
  "radiator", "cooler":
   canvas.draw_circle(center, r * 0.75, color, false, 2.2 * scale)
   for k in 6:
    var a := TAU * float(k) / 6.0
    canvas.draw_line(center, center + Vector2(cos(a), sin(a)) * r * 0.62, color, 1.7 * scale, true)
  "capacitor", "tank", "Logistics":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.50, r * 0.72), Vector2(r, r * 1.44)), color, false, 2.1 * scale)
   canvas.draw_arc(center + Vector2(0, -r * 0.72), r * 0.50, PI, TAU, 16, color, 2.1 * scale)
  "pump":
   canvas.draw_circle(center, r * 0.65, color, false, 2.2 * scale)
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, 2.2 * scale, true)
  "transformer", "switchyard", "Power":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.7, r * 0.55), Vector2(r * 1.4, r * 1.1)), color, false, 2.0 * scale)
   for x in [-0.45, 0.0, 0.45]:
    canvas.draw_line(center + Vector2(x * r, -r * 0.85), center + Vector2(x * r, -r * 0.45), color, 1.7 * scale)
  "select":
   canvas.draw_circle(center, r * 0.75, color, false, 2.0 * scale)
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, 1.4 * scale)
   canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, 1.4 * scale)
  "remove":
   canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), color, 3.0 * scale, true)
   canvas.draw_line(center + Vector2(r * 0.7, -r * 0.7), center + Vector2(-r * 0.7, r * 0.7), color, 3.0 * scale, true)

static func draw_board(canvas: CanvasItem, model: BloomSimulation, tick: float, overlay: String, tool: String, selection: int, preview_cell: Vector2i, preview_ok: bool, grid_visible := false) -> void:
 var total := GRID * CELL
 # Generated art is the real yard/background. Code only draws gameplay equipment and overlays.
 canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, total, total), false, Color(0.94, 0.94, 0.91, 1.0))
 canvas.draw_rect(Rect2(0, 0, total, total), Color(0.02, 0.03, 0.035, 0.08))

 var low := (GRID - model.active_size) / 2
 var build_rect := Rect2(Vector2(low, low) * CELL, Vector2.ONE * model.active_size * CELL)
 canvas.draw_rect(build_rect, Color(0.12, 0.13, 0.13, 0.045))
 canvas.draw_rect(build_rect.grow(3), SAFETY, false, 2.0)
 canvas.draw_rect(build_rect.grow(7), Color(0.05, 0.06, 0.06, 0.56), false, 1.0)

 if grid_visible or tool != "":
  for y in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(low, y) * CELL, Vector2(low + model.active_size, y) * CELL, Color(0.96, 0.86, 0.58, 0.13), 0.75)
  for x in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(x, low) * CELL, Vector2(x, low + model.active_size) * CELL, Color(0.96, 0.86, 0.58, 0.13), 0.75)

 if overlay == "heat":
  for y in GRID:
   for x in GRID:
    var temp: float = model.heat[model.index(x, y)]
    var amount := clampf((temp - 30.0) / 65.0, 0.0, 0.62)
    if amount > 0.01:
     canvas.draw_circle(Vector2(x + 0.5, y + 0.5) * CELL, CELL * 0.82, Color(1.0, 0.24 if temp > 78.0 else 0.62, 0.04, amount))

 for p in model.parts:
  if p.id in ["vein", "bundle"]: draw_pipe(canvas, model, p, overlay)
 for p in model.parts:
  if not p.id in ["vein", "bundle"]: draw_part(canvas, model, p, tick, overlay)

 if selection >= 0 and selection < model.parts.size():
  var p: Dictionary = model.parts[selection]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  draw_brackets(canvas, Rect2(Vector2(p.x, p.y) * CELL - Vector2.ONE * 2, Vector2.ONE * (CELL * sz + 4)), Color("fff0a8"))

 if preview_cell.x >= 0 and tool != "":
  var sz: int = Catalog.PARTS.get(tool, {}).get("size", 1)
  var rect := Rect2(Vector2(preview_cell) * CELL, Vector2.ONE * CELL * sz)
  canvas.draw_rect(rect, Color(0.24, 0.95, 0.65, 0.24) if preview_ok else Color(0.95, 0.28, 0.20, 0.24))
  draw_brackets(canvas, rect, STEAM if preview_ok else HOT)

 if model.bloom_time > 0.0:
  var wave := (2.0 - model.bloom_time) * 340.0
  canvas.draw_arc(Vector2(12, 12) * CELL, wave, 0, TAU, 72, Color(1.0, 0.76, 0.26, model.bloom_time / 2.0), 3.0)

static func draw_pipe(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, overlay: String) -> void:
 var c := Vector2(p.x + 0.5, p.y + 0.5) * CELL
 var thick := 9.0 if p.id == "bundle" else 6.0
 var flowing := float(p.load) > 0.01
 var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
 var linked := false
 for dir in dirs:
  var q := Vector2i(p.x, p.y) + dir
  if q.x < 0 or q.y < 0 or q.x >= GRID or q.y >= GRID: continue
  var j := model.at(q.x, q.y)
  if j < 0: continue
  var other: Dictionary = model.parts[j]
  if other.id == "core" or Catalog.PARTS[other.id].has("ports") or other.id == "pump":
   var end := c + Vector2(dir) * CELL * 0.54
   canvas.draw_line(c, end, INK, thick + 4.0, true)
   canvas.draw_line(c, end, PIPE, thick, true)
   canvas.draw_line(c, end, STEEL, maxf(1.2, thick * 0.24), true)
   if flowing: canvas.draw_line(c, end, STEAM, maxf(1.0, thick * 0.16), true)
   linked = true
 if not linked:
  canvas.draw_line(c + Vector2(-CELL * 0.44, 0), c + Vector2(CELL * 0.44, 0), INK, thick + 4, true)
  canvas.draw_line(c + Vector2(-CELL * 0.44, 0), c + Vector2(CELL * 0.44, 0), PIPE, thick, true)
  canvas.draw_line(c + Vector2(-CELL * 0.44, 0), c + Vector2(CELL * 0.44, 0), STEEL, 1.5, true)
 canvas.draw_circle(c, thick * 0.72, DARK_STEEL)
 canvas.draw_circle(c, thick * 0.40, STEAM if flowing else STEEL.darkened(0.18))
 if overlay == "power": canvas.draw_circle(c, 9.0, Color(1.0, 0.72, 0.18, 0.22 if flowing else 0.05))

static func equipment_base(canvas: CanvasItem, rect: Rect2) -> void:
 canvas.draw_rect(rect.grow(3), Color(0.025, 0.03, 0.03, 0.83))
 canvas.draw_rect(rect, Color(0.28, 0.30, 0.30, 0.97))
 canvas.draw_rect(rect, Color(0.82, 0.76, 0.61, 0.44), false, 1.2)
 canvas.draw_line(rect.position + Vector2(2, rect.size.y - 2), rect.end - Vector2(2, 2), SAFETY.darkened(0.1), 1.3)

static func draw_part(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, tick: float, overlay: String) -> void:
 var d: Dictionary = Catalog.PARTS[p.id]
 var sz: int = d.get("size", 1)
 var rect := Rect2(Vector2(p.x, p.y) * CELL + Vector2(3, 3), Vector2.ONE * (CELL * sz - 6))
 var c := rect.get_center()
 var online := float(p.ratio) > 0.05 or p.id in ["gland", "reactor", "radiator", "cooler", "pump", "tank", "transformer", "switchyard", "core"]
 equipment_base(canvas, rect)

 match p.id:
  "core":
   canvas.draw_rect(rect.grow(-5), Color("555d5d"))
   canvas.draw_rect(Rect2(rect.position + Vector2(8, 11), Vector2(rect.size.x - 16, rect.size.y - 20)), Color("22292b"))
   canvas.draw_rect(Rect2(rect.position + Vector2(9, 5), Vector2(rect.size.x - 18, 7)), Color("849093"))
   canvas.draw_circle(rect.position + Vector2(13, rect.size.y - 10), 3, Color("70e397"))
   canvas.draw_circle(rect.position + Vector2(23, rect.size.y - 10), 3, Color("e7b850"))
  "gland", "reactor":
   var fire := HOT if p.id == "reactor" else Color("e49a45")
   canvas.draw_rect(rect.grow(-6), Color("60696b"))
   canvas.draw_rect(Rect2(rect.position + Vector2(7, rect.size.y - 15), Vector2(rect.size.x - 14, 8)), Color("252a2b"))
   canvas.draw_circle(c + Vector2(0, rect.size.y * 0.18), 5.5 + (1.5 if p.id == "reactor" else 0.0), fire.lightened(0.08 + 0.05 * sin(tick * 5.0)))
   for x in range(3 if p.id == "reactor" else 2):
    var xx := rect.position.x + 12 + x * (rect.size.x - 24) / maxf(1.0, (2 if p.id == "reactor" else 1))
    canvas.draw_line(Vector2(xx, rect.position.y + 8), Vector2(xx, rect.position.y + rect.size.y * 0.45), STEEL, 2)
  "processor":
   canvas.draw_circle(c + Vector2(-11, 0), 18, Color("6c7476"))
   canvas.draw_circle(c + Vector2(-11, 0), 12, Color("252d30"))
   canvas.draw_circle(c + Vector2(16, 0), 14, Color("315d78"))
   canvas.draw_line(c + Vector2(1, 0), c + Vector2(9, 0), STEEL, 5)
   if online: canvas.draw_arc(c + Vector2(-11, 0), 14, tick * 2.8, tick * 2.8 + 5.0, 28, POWER, 2.2, true)
  "cluster":
   canvas.draw_rect(rect.grow(-7), Color("4d575a"))
   for row in 2:
    var tc := rect.position + Vector2(rect.size.x * (0.30 + row * 0.42), rect.size.y * 0.48)
    canvas.draw_circle(tc, 21, Color("737d7f"))
    canvas.draw_circle(tc, 13, Color("243136"))
    canvas.draw_arc(tc, 16, tick * 2.1 + row, tick * 2.1 + row + 5.1, 28, POWER if online else STEEL, 2.2, true)
   canvas.draw_line(rect.position + Vector2(10, rect.size.y - 12), rect.end - Vector2(10, 12), SAFETY, 2)
  "radiator":
   canvas.draw_circle(c, minf(rect.size.x, rect.size.y) * 0.34, Color("bfc5c3"))
   canvas.draw_circle(c, minf(rect.size.x, rect.size.y) * 0.26, Color("30383a"))
   for k in 8:
    var a := tick * 0.22 + TAU * float(k) / 8.0
    canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * minf(rect.size.x, rect.size.y) * 0.23, COOL, 2.4, true)
  "cooler":
   canvas.draw_rect(rect.grow(-6), Color("606b6e"))
   for row in 2:
    for col in 2:
     var fc := rect.position + Vector2(rect.size.x * (0.30 + col * 0.40), rect.size.y * (0.30 + row * 0.40))
     canvas.draw_circle(fc, 10, Color("263135"))
     canvas.draw_arc(fc, 7, 0, TAU, 20, COOL, 1.8)
  "capacitor":
   canvas.draw_rect(Rect2(c - Vector2(14, 23), Vector2(28, 46)), Color("657073"))
   canvas.draw_arc(c + Vector2(0, -23), 14, PI, TAU, 24, STEEL, 2)
   var fill := clampf(float(p.stored) / maxf(1.0, float(d.storage)), 0.0, 1.0)
   canvas.draw_rect(Rect2(c + Vector2(-11, 19 - 35 * fill), Vector2(22, 35 * fill)), Color(0.90, 0.68, 0.25, 0.75))
  "pump":
   canvas.draw_circle(c, 11, Color("6a7477"))
   canvas.draw_circle(c, 6, Color("27404b"))
   canvas.draw_line(c + Vector2(-15, 0), c + Vector2(15, 0), STEEL, 4, true)
   canvas.draw_arc(c, 8, tick * 3.0, tick * 3.0 + 4.6, 18, COOL, 2, true)
  "transformer":
   canvas.draw_rect(rect.grow(-6), Color("586164"))
   canvas.draw_rect(Rect2(rect.position + Vector2(10, 15), Vector2(rect.size.x - 20, rect.size.y - 30)), Color("747e80"))
   for x in 3:
    var xx := rect.position.x + 14 + x * (rect.size.x - 28) / 2.0
    canvas.draw_line(Vector2(xx, rect.position.y + 7), Vector2(xx, rect.position.y + 16), Color("784b36"), 4)
   canvas.draw_line(rect.position + Vector2(7, rect.size.y - 11), rect.end - Vector2(7, 11), POWER, 2)
  "switchyard":
   canvas.draw_rect(rect.grow(-7), Color("414a4d"))
   for x in 3:
    var xx := rect.position.x + 13 + x * (rect.size.x - 26) / 2.0
    canvas.draw_line(Vector2(xx, rect.position.y + 9), Vector2(xx, rect.end.y - 10), Color("815844"), 3)
    canvas.draw_circle(Vector2(xx, rect.position.y + 14), 3, STEEL)
   canvas.draw_line(rect.position + Vector2(8, rect.size.y * 0.52), Vector2(rect.end.x - 8, rect.position.y + rect.size.y * 0.52), POWER, 2)
  "tank":
   var radius := minf(rect.size.x, rect.size.y) * 0.27
   canvas.draw_circle(c, radius, Color("c2c5bf"))
   canvas.draw_circle(c, radius - 5, Color("aab6b8"))
   canvas.draw_line(c + Vector2(-radius + 4, 0), c + Vector2(radius - 4, 0), COOL, 2)

 if overlay == "power":
  var halo := Color(0.22, 0.86, 0.98, 0.22) if online else Color(0.90, 0.25, 0.18, 0.10)
  canvas.draw_rect(rect.grow(4), halo, false, 3.0)

static func draw_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
 var l := 9.0
 for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
  var sx := 1.0 if corner.x == rect.position.x else -1.0
  var sy := 1.0 if corner.y == rect.position.y else -1.0
  canvas.draw_line(corner, corner + Vector2(sx * l, 0), color, 2.0)
  canvas.draw_line(corner, corner + Vector2(0, sy * l), color, 2.0)
