extends RefCounted
class_name BloomBoardArt

const Catalog = preload("res://scripts/Catalog.gd")
const GRID := 24
const CELL := 34.0
const INK := Color("07131d")
const COPPER := Color("b98b52")
const SIGNAL := Color("78eacb")
const COOL := Color("75cce6")
const HOT := Color("f18a55")

static func bevel(center: Vector2, radius: float, cut := 3.0) -> PackedVector2Array:
 return PackedVector2Array([
  center + Vector2(-radius + cut, -radius), center + Vector2(radius - cut, -radius),
  center + Vector2(radius, -radius + cut), center + Vector2(radius, radius - cut),
  center + Vector2(radius - cut, radius), center + Vector2(-radius + cut, radius),
  center + Vector2(-radius, radius - cut), center + Vector2(-radius, -radius + cut)
 ])

static func outlined_chip(canvas: CanvasItem, center: Vector2, radius: float, accent: Color, active: float, pins := true) -> void:
 canvas.draw_polygon(bevel(center, radius + 3.5, 4), PackedColorArray([Color("030b12")]))
 canvas.draw_polygon(bevel(center, radius, 3), PackedColorArray([Color("17303a").lerp(Color("0a1824"), 1.0 - active * 0.4)]))
 var outline := bevel(center, radius, 3)
 outline.append(outline[0])
 canvas.draw_polyline(outline, accent.darkened(0.2) if active > 0.1 else Color("34464d"), 1.7, true)
 if pins:
  for side in [-1, 1]:
   for index in 3:
    var offset := (index - 1) * radius * 0.48
    canvas.draw_line(center + Vector2(side * (radius + 3), offset), center + Vector2(side * (radius + 6), offset), COPPER.darkened(0.25), 2, true)
    canvas.draw_line(center + Vector2(offset, side * (radius + 3)), center + Vector2(offset, side * (radius + 6)), COPPER.darkened(0.25), 2, true)

static func symbol(canvas: CanvasItem, id: String, center: Vector2, scale: float, color: Color) -> void:
 var r := 13.0 * scale
 match id:
  "vein", "bundle", "Connections":
   var width := 3.2 * scale if id != "bundle" else 5.0 * scale
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, width, true)
   canvas.draw_line(center, center + Vector2(0, -r * 0.75), color, width, true)
   canvas.draw_circle(center, 3.1 * scale, Color("d2f2e0"))
   if id == "bundle":
    canvas.draw_line(center + Vector2(-r, 5 * scale), center + Vector2(r, 5 * scale), color.darkened(0.3), 2 * scale, true)
  "gland", "Power":
   canvas.draw_arc(center, r * 0.81, -2.4, 2.4, 20, color, 2.8 * scale, true)
   canvas.draw_polyline(PackedVector2Array([center + Vector2(-3, -8) * scale, center + Vector2(2, -2) * scale, center + Vector2(-2, 2) * scale, center + Vector2(4, 8) * scale]), color.lightened(0.25), 2.5 * scale, true)
  "processor", "cluster", "Compute":
   canvas.draw_rect(Rect2(center - Vector2.ONE * r * 0.75, Vector2.ONE * r * 1.5), color, false, 2 * scale)
   for k in 4:
    var off := Vector2((k % 2) * 2 - 1, (k / 2) * 2 - 1) * r * 0.27
    canvas.draw_circle(center + off, 2.6 * scale, color.lightened(0.35))
  "radiator", "cooler", "Cooling":
   for k in 4:
    var x := (k - 1.5) * 5 * scale
    canvas.draw_line(center + Vector2(x, -r * 0.75), center + Vector2(x, r * 0.75), color, 2.3 * scale, true)
   canvas.draw_line(center + Vector2(-r, r), center + Vector2(r, r), color, 2.2 * scale, true)
  "capacitor", "Support":
   canvas.draw_line(center + Vector2(-r * 0.45, -r), center + Vector2(-r * 0.45, r), color, 3 * scale)
   canvas.draw_line(center + Vector2(r * 0.45, -r), center + Vector2(r * 0.45, r), color, 3 * scale)
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(-r * 0.45, 0), color, 2 * scale)
   canvas.draw_line(center + Vector2(r * 0.45, 0), center + Vector2(r, 0), color, 2 * scale)
  "select", "Tools":
   canvas.draw_arc(center, r * 0.8, 0, TAU, 28, color, 2 * scale, true)
   canvas.draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, 1.4 * scale)
   canvas.draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, 1.4 * scale)
  "remove":
   canvas.draw_line(center + Vector2(-r * 0.7, -r * 0.7), center + Vector2(r * 0.7, r * 0.7), color, 3 * scale, true)
   canvas.draw_line(center + Vector2(r * 0.7, -r * 0.7), center + Vector2(-r * 0.7, r * 0.7), color, 3 * scale, true)

static func draw_board(canvas: CanvasItem, model: BloomSimulation, tick: float, overlay: String, tool: String, selection: int, preview_cell: Vector2i, preview_ok: bool) -> void:
 var total := GRID * CELL
 canvas.draw_rect(Rect2(-8, -8, total + 16, total + 16), Color("03080e"))
 canvas.draw_rect(Rect2(0, 0, total, total), Color("081923"))
 var low := (GRID - model.active_size) / 2
 var awake_rect := Rect2(Vector2(low, low) * CELL, Vector2.ONE * model.active_size * CELL)
 canvas.draw_rect(awake_rect, Color("102b32"))
 canvas.draw_rect(awake_rect.grow(3.5), Color("4b766f"), false, 2)
 for y in GRID:
  for x in GRID:
   var c := Vector2(x + 0.5, y + 0.5) * CELL
   var active := model.active(x, y)
   var dim := 1.0 if active else 0.38
   var trace := Color(0.24, 0.54, 0.50, 0.38 * dim)
   var branch := Color(0.64, 0.46, 0.28, 0.24 * dim)
   # Copper traces, vias and tiny components make dormant tissue read as an unpowered PCB.
   if (x * 13 + y * 7) % 3 == 0 and x < GRID - 1:
    canvas.draw_line(c + Vector2(-8, 8), c + Vector2(6, 8), trace, 1.3, true)
    canvas.draw_line(c + Vector2(6, 8), c + Vector2(12, 2), trace, 1.3, true)
    canvas.draw_line(c + Vector2(12, 2), c + Vector2(CELL, 2), trace, 1.3, true)
   if (x * 5 + y * 17) % 4 == 0 and y < GRID - 1:
    canvas.draw_line(c + Vector2(-10, -7), c + Vector2(-10, 6), branch, 1.2, true)
    canvas.draw_line(c + Vector2(-10, 6), c + Vector2(-4, 12), branch, 1.2, true)
    canvas.draw_line(c + Vector2(-4, 12), c + Vector2(-4, CELL), branch, 1.2, true)
   if (x * 7 + y * 11) % 5 == 0:
    canvas.draw_circle(c + Vector2(10, -10), 2.5, Color("244751") if active else Color("182e38"))
    canvas.draw_circle(c + Vector2(10, -10), 1.1, COPPER.darkened(0.35) if active else Color("2c353b"))
   if (x + y * 3) % 8 == 0:
    canvas.draw_rect(Rect2(c + Vector2(-13, -14), Vector2(5, 2)), Color(0.42, 0.53, 0.49, 0.28 * dim))
    canvas.draw_rect(Rect2(c + Vector2(-13, -10), Vector2(5, 2)), Color(0.42, 0.53, 0.49, 0.28 * dim))
   if not active and (x + 3 * y) % 6 == 0:
    canvas.draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), Color(0.25, 0.37, 0.38, 0.17), 2, true)
   if overlay == "heat":
    var temp: float = model.heat[model.index(x, y)]
    var amount := clampf((temp - 30.0) / 60.0, 0.0, 0.65)
    if amount > 0.01:
     canvas.draw_circle(c, CELL * 0.78, Color(1.0, 0.31 if temp > 70.0 else 0.7, 0.07, amount))
   elif overlay == "power" and active:
    var i := model.at(x, y)
    if i >= 0:
     var part: Dictionary = model.parts[i]
     var energized: bool = part.load > 0.0 or part.power > 0.0 or part.id == "gland"
     canvas.draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), Color(0.19, 0.93, 0.68, 0.15) if energized else Color(0.85, 0.31, 0.23, 0.08))
   if tool != "" and active:
    canvas.draw_line(Vector2(x, y) * CELL, Vector2(x, y + 1) * CELL, Color(0.33, 0.64, 0.61, 0.12), 0.8)
    canvas.draw_line(Vector2(x, y) * CELL, Vector2(x + 1, y) * CELL, Color(0.33, 0.64, 0.61, 0.12), 0.8)
 for p in model.parts:
  draw_part(canvas, model, p, tick, overlay)
 if selection >= 0 and selection < model.parts.size():
  var p: Dictionary = model.parts[selection]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  var rect := Rect2(Vector2(p.x, p.y) * CELL - Vector2.ONE * 2, Vector2.ONE * (CELL * sz + 4))
  draw_brackets(canvas, rect, Color("d9f9dd"))
 if preview_cell.x >= 0 and tool != "":
  var sz: int = Catalog.PARTS.get(tool, {}).get("size", 1)
  var rect := Rect2(Vector2(preview_cell) * CELL, Vector2.ONE * CELL * sz)
  canvas.draw_rect(rect, Color(0.28, 0.96, 0.69, 0.22) if preview_ok else Color(0.95, 0.35, 0.25, 0.22))
  draw_brackets(canvas, rect, SIGNAL if preview_ok else HOT)
 if model.bloom_time > 0.0:
  var wave := (2.0 - model.bloom_time) * 420.0
  canvas.draw_arc(Vector2(12, 12) * CELL, wave, 0, TAU, 90, Color(0.34, 1.0, 0.76, model.bloom_time / 2.0), 3.0)

static func draw_brackets(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
 var a := rect.position
 var b := rect.end
 var length := 7.0
 for corner in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
  var dx := 1.0 if corner.x == a.x else -1.0
  var dy := 1.0 if corner.y == a.y else -1.0
  canvas.draw_line(corner, corner + Vector2(dx * length, 0), tint, 2)
  canvas.draw_line(corner, corner + Vector2(0, dy * length), tint, 2)

static func draw_part(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, tick: float, overlay: String) -> void:
 var id: String = p.id
 var d: Dictionary = Catalog.PARTS[id]
 var sz: int = d.get("size", 1)
 var c := Vector2(p.x + sz * 0.5, p.y + sz * 0.5) * CELL
 var r := CELL * (0.35 if sz == 1 else 0.82)
 var temperature: float = model.heat[model.index(p.x, p.y)]
 var ratio: float = p.ratio if d.has("request") else 1.0
 if id in ["vein", "bundle"]:
  draw_conductor(canvas, model, p, c, tick, overlay)
  return
 var accent := SIGNAL
 if id in ["processor", "cluster"]: accent = Color("a0a6f0")
 if id in ["radiator", "cooler"]: accent = COOL
 if id == "capacitor": accent = Color("e5bd81")
 var light := clampf(ratio, 0.13, 1.0)
 if temperature >= 70.0:
  canvas.draw_circle(c, r * 1.72, Color(1.0, 0.20, 0.06, clampf((temperature - 58.0) / 180.0, 0.08, 0.47)))
 if ratio > 0.02:
  canvas.draw_circle(c, r * 1.48, Color(accent.r, accent.g, accent.b, 0.06 + 0.05 * sin(tick * 3.0 + p.x)))
 outlined_chip(canvas, c, r, accent, light, id not in ["radiator", "cooler"])
 match id:
  "core":
   for tier in range(mini(2 + model.level, 6)):
    var radius := r * (0.49 + tier * 0.16)
    var phase := tick * (0.22 if tier % 2 == 0 else -0.18) + tier * 0.37
    canvas.draw_arc(c, radius, phase, phase + TAU * 0.72, 28, Color(0.48, 0.90, 0.72, 0.62 * light), 1.2, true)
   canvas.draw_circle(c, 5.5 + sin(tick * 2.1) * 0.7, Color(0.23, 0.64, 0.62, light))
   canvas.draw_circle(c, 2.7, Color("d9ffdd") * Color(1, 1, 1, light))
   for k in 4:
    var a := k * TAU / 4.0
    canvas.draw_line(c + Vector2.from_angle(a) * r * 0.82, c + Vector2.from_angle(a) * r * 1.42, COPPER, 1.3)
  "gland":
   canvas.draw_arc(c, r * 0.63, 0, TAU, 24, COPPER, 2.5, true)
   canvas.draw_arc(c, r * 0.4, 0, TAU, 24, SIGNAL.darkened(0.15), 1.7, true)
   canvas.draw_circle(c, 4.0 + sin(tick * 2.8) * 0.8, Color(0.61, 1.0, 0.7, light))
   for k in 4:
    var a := k * TAU / 4.0 + PI / 4.0
    canvas.draw_circle(c + Vector2.from_angle(a) * r * 0.72, 1.5, Color("f4d48d"))
  "processor", "cluster":
   var count := 4 if id == "cluster" else 1
   for k in count:
    var off := Vector2((k % 2) * 2 - 1, (k / 2) * 2 - 1) * r * 0.41 if count == 4 else Vector2.ZERO
    var center := c + off
    var cell_r := r * (0.29 if count == 4 else 0.48)
    canvas.draw_rect(Rect2(center - Vector2.ONE * cell_r, Vector2.ONE * cell_r * 2), Color("203442"))
    canvas.draw_rect(Rect2(center - Vector2.ONE * cell_r, Vector2.ONE * cell_r * 2), accent * Color(1, 1, 1, light), false, 1.5)
    canvas.draw_circle(center, cell_r * 0.45, Color(0.51, 0.87, 0.99, light))
    canvas.draw_circle(center, 1.7, Color(0.88, 0.98, 1.0, light))
   for side in [-1, 1]:
    canvas.draw_line(c + Vector2(-r * 0.67, side * r * 0.67), c + Vector2(r * 0.67, side * r * 0.67), accent.darkened(0.4), 1.1)
  "radiator", "cooler":
   for k in 5:
    var offset := (k - 2) * r * 0.27
    canvas.draw_line(c + Vector2(offset, -r * 0.65), c + Vector2(offset, r * 0.58), COOL.darkened(0.18), 2.3, true)
   if id == "cooler":
    canvas.draw_arc(c, r * 0.38, tick * 1.5, tick * 1.5 + TAU * 0.7, 18, Color("d6f7ed"), 2.5)
    canvas.draw_circle(c, 2.4, Color("e5ffff"))
  "capacitor":
   canvas.draw_rect(Rect2(c + Vector2(-r * 0.58, -r * 0.62), Vector2(r * 1.16, r * 1.24)), Color("273a42"))
   var fill: float = clampf(float(p.stored) / float(d.storage), 0.0, 1.0)
   canvas.draw_rect(Rect2(c + Vector2(-r * 0.46, r * 0.47 - fill * r * 0.92), Vector2(r * 0.92, fill * r * 0.92)), Color(0.78, 0.90, 0.63, 0.85))
   canvas.draw_line(c + Vector2(-r * 0.65, -r * 0.72), c + Vector2(r * 0.65, -r * 0.72), COPPER, 2)
 if overlay == "power" and d.has("request"):
  canvas.draw_arc(c, r * 1.2, -PI * 0.5, -PI * 0.5 + TAU * ratio, 25, SIGNAL if ratio >= 0.7 else HOT, 2.2, true)

static func draw_conductor(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, c: Vector2, tick: float, overlay: String) -> void:
 var d: Dictionary = Catalog.PARTS[p.id]
 var width := 4.2 if p.id == "vein" else 6.5
 var load_ratio: float = p.load / float(d.capacity)
 var lit: bool = p.load > 0.01
 var copper := COPPER.lightened(load_ratio * 0.18) if lit else COPPER.darkened(0.55)
 canvas.draw_circle(c, width + 3.0, Color("0a1920"))
 for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  var q: Vector2i = Vector2i(p.x, p.y) + dir
  var j := model.at(q.x, q.y) if q.x >= 0 and q.y >= 0 and q.x < GRID and q.y < GRID else -1
  if j < 0 or not Catalog.PARTS[model.parts[j].id].has("ports"): continue
  var end := c + Vector2(dir) * CELL * 0.53
  canvas.draw_line(c, end, Color("061118"), width + 6.0, true)
  canvas.draw_line(c, end, copper, width + 1.0, true)
  canvas.draw_line(c, end, Color(0.19, 0.62, 0.53, 0.42 if lit else 0.12), maxf(1.0, width - 3.0), true)
  if lit:
   var phase := fposmod(tick * (0.6 + load_ratio * 2.2) + p.x * 0.31 + p.y * 0.13, 1.0)
   canvas.draw_circle(c.lerp(end, phase), 2.4 + load_ratio, Color("c9ffe1"))
 canvas.draw_circle(c, width * 0.62, SIGNAL if lit else Color("536a67"))
 if p.id == "bundle":
  canvas.draw_arc(c, width + 2.0, 0, TAU, 16, COPPER.darkened(0.1), 1.2)
 if overlay == "power":
  canvas.draw_arc(c, width + 5.0, -PI * 0.5, -PI * 0.5 + TAU * load_ratio, 16, SIGNAL, 2.0)
