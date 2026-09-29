extends RefCounted
class_name BloomBoardArt

const Catalog = preload("res://scripts/Catalog.gd")
const BACKGROUND: Texture2D = preload("res://assets/power_plant_background.jpg")
const EQUIPMENT_ATLAS: Texture2D = preload("res://assets/powerplant_equipment_atlas.webp")
const GRID := 24
const CELL := 34.0
const ATLAS_TILE := 80.0
const INK := Color("111719")
const STEEL := Color("b5bec0")
const DARK_STEEL := Color("465156")
const PIPE := Color("66777c")
const STEAM := Color("f0bd57")
const POWER := Color("56c6ed")
const COOL := Color("5bb9d7")
const HOT := Color("ee6649")
const SAFETY := Color("d5a934")

static func atlas_index(id: String) -> int:
 match id:
  "gland", "reactor": return 0
  "processor": return 1
  "cluster": return 2
  "radiator": return 3
  "cooler": return 4
  "pump": return 5
  "transformer": return 6
  "switchyard": return 7
  "capacitor", "tank": return 8
  "vein", "bundle": return -1
 return -1

static func atlas_region(id: String) -> Rect2:
 var i := atlas_index(id)
 if i < 0: return Rect2()
 var col := i % 5
 var row := i / 5
 return Rect2(Vector2(col, row) * ATLAS_TILE, Vector2.ONE * ATLAS_TILE)

static func equipment_visual_span(id: String, logical_size: int) -> float:
 # Logical footprints still control placement/collision. The art deliberately
 # overhangs those footprints so plant equipment reads as machinery instead of tiles.
 match id:
  "gland": return 1.55
  "reactor": return 2.62
  "processor": return 2.52
  "cluster": return 3.62
  "radiator": return 2.72
  "cooler": return 2.48
  "pump": return 1.24
  "transformer": return 2.22
  "switchyard": return 2.52
  "capacitor": return 2.18
  "tank": return 2.34
 return maxf(1.0, float(logical_size))

static func equipment_visual_offset(id: String) -> Vector2:
 # Small offsets keep tall/heavy equipment visually grounded while preserving
 # its logical cell anchor for simulation and selection.
 match id:
  "gland": return Vector2(0, -5)
  "reactor": return Vector2(0, -8)
  "processor": return Vector2(4, -1)
  "cluster": return Vector2(7, -2)
  "radiator": return Vector2(0, -10)
  "cooler": return Vector2(5, -2)
  "pump": return Vector2(0, -1)
  "transformer": return Vector2(2, -4)
  "switchyard": return Vector2(5, -2)
  "capacitor": return Vector2(0, -6)
  "tank": return Vector2(0, -7)
 return Vector2.ZERO

static func symbol(canvas: CanvasItem, id: String, center: Vector2, scale: float, color: Color) -> void:
 var idx := atlas_index(id)
 if idx >= 0:
  var size := Vector2.ONE * 49.0 * scale
  canvas.draw_texture_rect_region(EQUIPMENT_ATLAS, Rect2(center - size * 0.5, size), atlas_region(id))
  return
 var r := 13.0 * scale
 match id:
  "vein", "bundle", "Pipes":
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, 3.2 * scale, true)
   canvas.draw_circle(center, 3.0 * scale, STEEL)
  "Build":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.78, r * 0.55), Vector2(r * 1.56, r * 1.10)), color, false, 2.0 * scale)
   canvas.draw_polyline(PackedVector2Array([center + Vector2(-4, 6) * scale, center + Vector2(0, -7) * scale, center + Vector2(4, 6) * scale]), color.lightened(0.30), 2.0 * scale, true)
  "Logistics":
   canvas.draw_rect(Rect2(center - Vector2(r * 0.5, r * 0.72), Vector2(r, r * 1.44)), color, false, 2.0 * scale)
  "Power":
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
 canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, total, total), false, Color(0.96, 0.96, 0.94, 1.0))
 canvas.draw_rect(Rect2(0, 0, total, total), Color(0.02, 0.03, 0.035, 0.05))

 var low := (GRID - model.active_size) / 2
 var build_rect := Rect2(Vector2(low, low) * CELL, Vector2.ONE * model.active_size * CELL)
 canvas.draw_rect(build_rect, Color(0.12, 0.13, 0.13, 0.018))
 canvas.draw_rect(build_rect.grow(3), SAFETY, false, 2.0)
 canvas.draw_rect(build_rect.grow(7), Color(0.05, 0.06, 0.06, 0.45), false, 1.0)

 if grid_visible or tool != "":
  for y in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(low, y) * CELL, Vector2(low + model.active_size, y) * CELL, Color(0.96, 0.86, 0.58, 0.15), 0.8)
  for x in range(low, low + model.active_size + 1):
   canvas.draw_line(Vector2(x, low) * CELL, Vector2(x, low + model.active_size) * CELL, Color(0.96, 0.86, 0.58, 0.15), 0.8)

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
 var thick := 10.0 if p.id == "bundle" else 7.0
 var flowing := float(p.load) > 0.01
 var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
 var linked := false
 for dir in dirs:
  var q: Vector2i = Vector2i(p.x, p.y) + dir
  if q.x < 0 or q.y < 0 or q.x >= GRID or q.y >= GRID: continue
  var j := model.at(q.x, q.y)
  if j < 0: continue
  var other: Dictionary = model.parts[j]
  if other.id == "core" or Catalog.PARTS[other.id].has("ports") or other.id == "pump":
   var end := c + Vector2(dir) * CELL * 0.56
   canvas.draw_line(c, end, INK, thick + 5.0, true)
   canvas.draw_line(c, end, Color("d7d8d4") if p.id == "vein" else Color("b7b9b5"), thick, true)
   canvas.draw_line(c, end, Color("7a7c78"), maxf(1.5, thick * 0.23), true)
   if flowing: canvas.draw_line(c, end, STEAM, maxf(1.1, thick * 0.15), true)
   linked = true
 if not linked:
  var left := c + Vector2(-CELL * 0.46, 0)
  var right := c + Vector2(CELL * 0.46, 0)
  canvas.draw_line(left, right, INK, thick + 5.0, true)
  canvas.draw_line(left, right, Color("d7d8d4"), thick, true)
  canvas.draw_line(left, right, Color("7a7c78"), 1.6, true)
 canvas.draw_circle(c, thick * 0.82, DARK_STEEL)
 canvas.draw_circle(c, thick * 0.57, STEEL)
 canvas.draw_circle(c, thick * 0.32, STEAM if flowing else Color("71787a"))
 if overlay == "power": canvas.draw_circle(c, 10.0, Color(1.0, 0.72, 0.18, 0.24 if flowing else 0.05))

static func draw_part(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, tick: float, overlay: String) -> void:
 var d: Dictionary = Catalog.PARTS[p.id]
 var sz: int = d.get("size", 1)
 var logical_rect := Rect2(Vector2(p.x, p.y) * CELL + Vector2(2, 2), Vector2.ONE * (CELL * sz - 4))
 var online: bool = float(p.ratio) > 0.05 or p.id in ["gland", "reactor", "radiator", "cooler", "pump", "tank", "transformer", "switchyard", "core"]

 if p.id == "core":
  canvas.draw_rect(logical_rect.grow(3), Color(0.02, 0.025, 0.025, 0.8))
  canvas.draw_rect(logical_rect, Color("596164"))
  canvas.draw_rect(Rect2(logical_rect.position + Vector2(8, 10), logical_rect.size - Vector2(16, 19)), Color("22292b"))
  canvas.draw_rect(Rect2(logical_rect.position + Vector2(8, 5), Vector2(logical_rect.size.x - 16, 7)), Color("929b9c"))
  canvas.draw_circle(logical_rect.position + Vector2(13, logical_rect.size.y - 9), 3, Color("70e397"))
  canvas.draw_circle(logical_rect.position + Vector2(23, logical_rect.size.y - 9), 3, Color("e7b850"))
 else:
  var idx := atlas_index(p.id)
  if idx >= 0:
   var visual_px := CELL * equipment_visual_span(p.id, sz)
   var visual_center := logical_rect.get_center() + equipment_visual_offset(p.id)
   var dest := Rect2(visual_center - Vector2.ONE * visual_px * 0.5, Vector2.ONE * visual_px)
   var shadow_size := Vector2(visual_px * 0.62, maxf(5.0, visual_px * 0.14))
   var shadow_pos := visual_center + Vector2(-shadow_size.x * 0.5, visual_px * 0.31)
   canvas.draw_rect(Rect2(shadow_pos, shadow_size), Color(0.01, 0.012, 0.012, 0.28))
   canvas.draw_texture_rect_region(EQUIPMENT_ATLAS, dest, atlas_region(p.id))
   if p.id == "reactor": canvas.draw_rect(logical_rect.grow(1), Color(0.95, 0.35, 0.18, 0.48), false, 2.0)
   elif p.id in ["processor", "cluster"] and online:
    canvas.draw_rect(logical_rect.grow(1), Color(0.23, 0.78, 0.95, 0.34), false, 2.0)
   elif p.id in ["radiator", "cooler"]:
    canvas.draw_rect(logical_rect.grow(1), Color(0.32, 0.76, 0.88, 0.26), false, 1.5)
  else:
   canvas.draw_rect(logical_rect, Color("596164"))

 if p.id == "capacitor":
  var fill := clampf(float(p.stored) / maxf(1.0, float(d.storage)), 0.0, 1.0)
  canvas.draw_rect(Rect2(logical_rect.position + Vector2(5, logical_rect.size.y - 6), Vector2((logical_rect.size.x - 10) * fill, 3)), STEAM)

 if overlay == "power":
  var halo := Color(0.22, 0.86, 0.98, 0.30) if online else Color(0.90, 0.25, 0.18, 0.12)
  canvas.draw_rect(logical_rect.grow(4), halo, false, 3.0)

static func draw_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
 var l := 9.0
 for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
  var sx := 1.0 if corner.x == rect.position.x else -1.0
  var sy := 1.0 if corner.y == rect.position.y else -1.0
  canvas.draw_line(corner, corner + Vector2(sx * l, 0), color, 2.0)
  canvas.draw_line(corner, corner + Vector2(0, sy * l), color, 2.0)
