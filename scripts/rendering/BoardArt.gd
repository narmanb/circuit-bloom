extends RefCounted
class_name BloomBoardArt

const Catalog = preload("res://scripts/Catalog.gd")
const GRID := 24
const CELL := 34.0
const INK := Color("101a16")
const COPPER := Color("cf9550")
const SIGNAL := Color("e6bb64")
const COOL := Color("75bfe2")
const HOT := Color("ef7559")
const SILVER := Color("b9c2bd")
const BOARD := Color("174035")
const MASK := Color("21513d")

static func bevel(center: Vector2, radius: float, cut := 3.0) -> PackedVector2Array:
 return PackedVector2Array([
  center + Vector2(-radius + cut, -radius), center + Vector2(radius - cut, -radius),
  center + Vector2(radius, -radius + cut), center + Vector2(radius, radius - cut),
  center + Vector2(radius - cut, radius), center + Vector2(-radius + cut, radius),
  center + Vector2(-radius, radius - cut), center + Vector2(-radius, -radius + cut)
 ])

static func outlined_chip(canvas: CanvasItem, center: Vector2, radius: float, accent: Color, active: float, pins := true) -> void:
 canvas.draw_polygon(bevel(center, radius + 3.5, 4), PackedColorArray([Color("65736d")]))
 canvas.draw_polygon(bevel(center, radius + 1.5, 4), PackedColorArray([Color("111714")]))
 canvas.draw_polygon(bevel(center, radius, 3), PackedColorArray([Color("29322f").lerp(Color("171c1d"), 1.0 - active * 0.4)]))
 var outline := bevel(center, radius, 3)
 outline.append(outline[0])
 canvas.draw_polyline(outline, accent if active > 0.1 else Color("718078"), 1.7, true)
 if pins:
  for side in [-1, 1]:
   for index in 3:
    var offset := (index - 1) * radius * 0.48
    canvas.draw_line(center + Vector2(side * (radius + 3), offset), center + Vector2(side * (radius + 7), offset), SILVER, 2.1, true)
    canvas.draw_line(center + Vector2(offset, side * (radius + 3)), center + Vector2(offset, side * (radius + 7)), SILVER, 2.1, true)

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
  "reactor":
   canvas.draw_arc(center, r * 0.78, 0, TAU, 24, color, 2.6 * scale, true)
   canvas.draw_arc(center, r * 0.47, 0, TAU, 24, color.lightened(0.25), 2.1 * scale, true)
   canvas.draw_circle(center, 3.3 * scale, color.lightened(0.35))
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
 canvas.draw_rect(Rect2(-11, -11, total + 22, total + 22), Color("778c7c"))
 canvas.draw_rect(Rect2(-7, -7, total + 14, total + 14), Color("0b1713"))
 canvas.draw_rect(Rect2(0, 0, total, total), BOARD)
 var low := (GRID - model.active_size) / 2
 var awake_rect := Rect2(Vector2(low, low) * CELL, Vector2.ONE * model.active_size * CELL)
 canvas.draw_rect(awake_rect, MASK)
 canvas.draw_rect(awake_rect.grow(4.0), Color("d8c895"), false, 2)
 canvas.draw_rect(awake_rect.grow(8.0), Color("68816d"), false, 1)
 # Two copper layers and silkscreened pads evoke a populated PCB even before construction.
 for y in GRID:
  for x in GRID:
   var c := Vector2(x + 0.5, y + 0.5) * CELL
   var active := model.active(x, y)
   var dim := 1.0 if active else 0.7
   var routing := Color(0.76, 0.53, 0.27, 0.35 * dim)
   if (x * 13 + y * 7) % 3 == 0 and x < GRID - 1:
    canvas.draw_polyline(PackedVector2Array([c + Vector2(-12, 8), c + Vector2(4, 8), c + Vector2(11, 1), c + Vector2(18, 1)]), routing, 1.5, true)
    canvas.draw_polyline(PackedVector2Array([c + Vector2(-12, 12), c + Vector2(4, 12), c + Vector2(11, 5), c + Vector2(18, 5)]), routing.darkened(0.15), 1.1, true)
   if (x * 5 + y * 17) % 4 == 0 and y < GRID - 1:
    canvas.draw_polyline(PackedVector2Array([c + Vector2(-9, -16), c + Vector2(-9, 4), c + Vector2(-3, 10), c + Vector2(-3, 17)]), routing, 1.3, true)
   if (x * 7 + y * 11) % 5 == 0:
    canvas.draw_circle(c + Vector2(10, -10), 3.1, Color("8b784c"))
    canvas.draw_circle(c + Vector2(10, -10), 1.6, Color("23392d"))
   if (x + y * 3) % 8 == 0:
    canvas.draw_rect(Rect2(c + Vector2(-14, -15), Vector2(6, 3)), SILVER.darkened(0.38))
    canvas.draw_rect(Rect2(c + Vector2(-14, -10), Vector2(6, 3)), Color("a77745"))
   if active:
    canvas.draw_rect(Rect2(Vector2(x, y) * CELL + Vector2(3, 3), Vector2.ONE * (CELL - 6)), Color("73918041"), false, 0.8)
    if (x + 2 * y) % 5 == 0:
     canvas.draw_rect(Rect2(c + Vector2(-9, -5), Vector2(17, 9)), Color("799088"), false, 0.7)
     canvas.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(8, 3)), Color("ac9a62"))
   elif (x + 3 * y) % 7 == 0:
    canvas.draw_rect(Rect2(c + Vector2(-11, -4), Vector2(13, 9)), Color("17231e"))
    canvas.draw_rect(Rect2(c + Vector2(-9, -2), Vector2(9, 2)), Color("697d71"))
   if overlay == "heat":
    var temp: float = model.heat[model.index(x, y)]
    var amount := clampf((temp - 30.0) / 60.0, 0.0, 0.65)
    if amount > 0.01:
     canvas.draw_circle(c, CELL * 0.78, Color(1.0, 0.31 if temp > 70.0 else 0.7, 0.07, amount))
   elif overlay == "power" and active:
    var i := model.at(x, y)
    if i >= 0:
     var part: Dictionary = model.parts[i]
     var energized: bool = part.load > 0.0 or part.power > 0.0 or part.id in ["gland", "reactor"]
     canvas.draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), Color(0.19, 0.93, 0.68, 0.15) if energized else Color(0.85, 0.31, 0.23, 0.08))
   if tool != "" and active:
    canvas.draw_line(Vector2(x, y) * CELL, Vector2(x, y + 1) * CELL, Color("839b79"), 0.8)
    canvas.draw_line(Vector2(x, y) * CELL, Vector2(x + 1, y) * CELL, Color("839b79"), 0.8)
 draw_fixtures(canvas, model, low, total)
 for p in model.parts:
  draw_part(canvas, model, p, tick, overlay)
 if selection >= 0 and selection < model.parts.size():
  var p: Dictionary = model.parts[selection]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  var rect := Rect2(Vector2(p.x, p.y) * CELL - Vector2.ONE * 2, Vector2.ONE * (CELL * sz + 4))
  draw_brackets(canvas, rect, Color("ffe5a0"))
 if preview_cell.x >= 0 and tool != "":
  var sz: int = Catalog.PARTS.get(tool, {}).get("size", 1)
  var rect := Rect2(Vector2(preview_cell) * CELL, Vector2.ONE * CELL * sz)
  canvas.draw_rect(rect, Color(0.28, 0.96, 0.69, 0.22) if preview_ok else Color(0.95, 0.35, 0.25, 0.22))
  draw_brackets(canvas, rect, SIGNAL if preview_ok else HOT)
 if model.bloom_time > 0.0:
  var wave := (2.0 - model.bloom_time) * 420.0
  canvas.draw_arc(Vector2(12, 12) * CELL, wave, 0, TAU, 90, Color(1.0, 0.77, 0.34, model.bloom_time / 2.0), 3.0)

static func draw_fixtures(canvas: CanvasItem, model: BloomSimulation, low: int, total: float) -> void:
 # Silkscreen and fixed board furniture sit behind the player's larger modules.
 var board_font := ThemeDB.fallback_font
 canvas.draw_string(board_font, Vector2(18, 33), "CB-01  /  REV 2.4", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c0c9af"))
 canvas.draw_string(board_font, Vector2(total - 149, total - 19), "LIVE PCB  /  24 x 24", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("abbf9e"))
 for corner in [Vector2(23, 66), Vector2(total - 24, 64), Vector2(25, total - 56), Vector2(total - 24, total - 54)]:
  canvas.draw_circle(corner, 12, Color("9da89a"))
  canvas.draw_circle(corner, 8, Color("16241d"))
  canvas.draw_circle(corner, 5, Color("07120f"))
  canvas.draw_arc(corner, 16, 0.3, TAU - 0.3, 36, COPPER.darkened(0.2), 1.2)
 for side in [-1, 1]:
  var x := 55.0 if side < 0 else total - 78.0
  for slot in 2:
   var y := 196.0 + slot * 68.0
   canvas.draw_rect(Rect2(x, y, 23, 54), Color("0d1916"))
   canvas.draw_rect(Rect2(x + 2, y + 3, 19, 48), Color("636c63"), false, 1.1)
   for pin in 9:
    canvas.draw_line(Vector2(x + 5, y + 6 + pin * 5), Vector2(x + 18, y + 6 + pin * 5), COPPER.darkened(0.2), 1.1)
   canvas.draw_rect(Rect2(x - 3, y - 2, 29, 5), Color("bdc3b4"))
 var rim := Vector2(low, low) * CELL
 var extent := model.active_size * CELL
 for k in 6:
  var px := rim.x + (k + 0.5) * extent / 6.0
  for edge in [-1, 1]:
   var py := rim.y - 28.0 if edge < 0 else rim.y + extent + 10.0
   canvas.draw_rect(Rect2(px - 8, py, 16, 18), Color("141f1c"))
   canvas.draw_rect(Rect2(px - 5, py + 2, 10, 14), Color("889793"))
   canvas.draw_line(Vector2(px, py + 3), Vector2(px, py + 14), Color("cbd1c0"), 1)
 for lane in 3:
  var off := 16.0 + lane * 5.0
  canvas.draw_line(Vector2(rim.x - 92, rim.y - off), Vector2(rim.x + extent + 92, rim.y - off), COPPER.darkened(0.1), 1.3)
  canvas.draw_line(Vector2(rim.x - 92, rim.y + extent + off), Vector2(rim.x + extent + 92, rim.y + extent + off), COPPER.darkened(0.1), 1.3)
 canvas.draw_string(board_font, rim + Vector2(8, -10), "PROCESSOR DISTRICT  /  SOCKET A", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ddd9b0"))
 canvas.draw_string(board_font, rim + Vector2(8, extent + 23), "POWER BUS   >   COMPUTE   >   THERMAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d1c6a0"))

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
 var r := CELL * (0.42 if sz == 1 else 0.87)
 var temperature: float = model.heat[model.index(p.x, p.y)]
 var ratio: float = p.ratio if d.has("request") else 1.0
 if id in ["vein", "bundle"]:
  draw_conductor(canvas, model, p, c, tick, overlay)
  return
 var accent := Color("ddd5a6")
 if id == "gland": accent = Color("efb65d")
 if id == "reactor": accent = Color("f0835b")
 if id in ["processor", "cluster"]: accent = Color("bca4e7")
 if id in ["radiator", "cooler"]: accent = COOL
 if id == "capacitor": accent = Color("e9d082")
 var light := clampf(ratio, 0.13, 1.0)
 if temperature >= 70.0:
  canvas.draw_circle(c, r * 1.72, Color(1.0, 0.20, 0.06, clampf((temperature - 58.0) / 180.0, 0.08, 0.47)))
 if ratio > 0.02:
  canvas.draw_circle(c, r * 1.48, Color(accent.r, accent.g, accent.b, 0.06 + 0.05 * sin(tick * 3.0 + p.x)))
 outlined_chip(canvas, c, r, accent, light, id not in ["radiator", "cooler"])
 match id:
  "core":
   canvas.draw_rect(Rect2(c - Vector2.ONE * r * 0.75, Vector2.ONE * r * 1.5), Color("909b91"), false, 1.5)
   for tier in range(mini(2 + model.level, 6)):
    var radius := r * (0.49 + tier * 0.16)
    var phase := tick * (0.22 if tier % 2 == 0 else -0.18) + tier * 0.37
    canvas.draw_arc(c, radius, phase, phase + TAU * 0.72, 28, Color(0.97, 0.71, 0.38, 0.76 * light), 1.5, true)
   canvas.draw_circle(c, 5.5 + sin(tick * 2.1) * 0.7, Color(0.72, 0.39, 0.80, light))
   canvas.draw_circle(c, 2.7, Color("f9e7aa") * Color(1, 1, 1, light))
   for k in 4:
    var a := k * TAU / 4.0
    canvas.draw_line(c + Vector2.from_angle(a) * r * 0.82, c + Vector2.from_angle(a) * r * 1.42, COPPER, 1.3)
  "gland":
   canvas.draw_arc(c, r * 0.65, 0, TAU, 24, COPPER, 3.2, true)
   canvas.draw_arc(c, r * 0.43, 0, TAU, 24, Color("f8d389"), 2.0, true)
   canvas.draw_circle(c, 4.0 + sin(tick * 2.8) * 0.8, Color(1.0, 0.68, 0.24, light))
   for k in 4:
    var a := k * TAU / 4.0 + PI / 4.0
    canvas.draw_circle(c + Vector2.from_angle(a) * r * 0.72, 1.5, Color("f4d48d"))
  "reactor":
   canvas.draw_arc(c, r * 0.76, 0, TAU, 28, Color("d56b4e"), 3.4, true)
   canvas.draw_arc(c, r * 0.53, -tick * 0.3, -tick * 0.3 + TAU * 0.84, 24, Color("ffc583"), 2.0, true)
   canvas.draw_circle(c, r * 0.29, Color("ef7354"))
   canvas.draw_circle(c, r * 0.14, Color("ffe3a4"))
   for k in 4:
    var a := k * TAU / 4.0
    canvas.draw_line(c + Vector2.from_angle(a) * r * 0.83, c + Vector2.from_angle(a) * r * 1.15, Color("b4bbb0"), 2.1)
  "processor", "cluster":
   var count := 4 if id == "cluster" else 1
   for k in count:
    var off := Vector2((k % 2) * 2 - 1, (k / 2) * 2 - 1) * r * 0.41 if count == 4 else Vector2.ZERO
    var center := c + off
    var cell_r := r * (0.29 if count == 4 else 0.48)
    canvas.draw_rect(Rect2(center - Vector2.ONE * cell_r, Vector2.ONE * cell_r * 2), Color("302a38"))
    canvas.draw_rect(Rect2(center - Vector2.ONE * cell_r, Vector2.ONE * cell_r * 2), accent * Color(1, 1, 1, light), false, 1.5)
    canvas.draw_circle(center, cell_r * 0.45, Color(0.67, 0.49, 0.87, light))
    canvas.draw_circle(center, 1.7, Color(0.96, 0.89, 1.0, light))
   for side in [-1, 1]:
    canvas.draw_line(c + Vector2(-r * 0.67, side * r * 0.67), c + Vector2(r * 0.67, side * r * 0.67), accent.darkened(0.4), 1.1)
  "radiator", "cooler":
   for k in 5:
    var offset := (k - 2) * r * 0.27
    canvas.draw_line(c + Vector2(offset, -r * 0.65), c + Vector2(offset, r * 0.58), SILVER, 2.9, true)
    canvas.draw_line(c + Vector2(offset + 1, -r * 0.54), c + Vector2(offset + 1, r * 0.48), COOL, 1.1, true)
   if id == "cooler":
    canvas.draw_arc(c, r * 0.38, tick * 1.5, tick * 1.5 + TAU * 0.7, 18, Color("d6f7ed"), 2.5)
    canvas.draw_circle(c, 2.4, Color("e5ffff"))
  "capacitor":
   canvas.draw_rect(Rect2(c + Vector2(-r * 0.58, -r * 0.62), Vector2(r * 1.16, r * 1.24)), Color("272d27"))
   var fill: float = clampf(float(p.stored) / float(d.storage), 0.0, 1.0)
   canvas.draw_rect(Rect2(c + Vector2(-r * 0.46, r * 0.47 - fill * r * 0.92), Vector2(r * 0.92, fill * r * 0.92)), Color(0.97, 0.73, 0.36, 0.85))
   canvas.draw_line(c + Vector2(-r * 0.65, -r * 0.72), c + Vector2(r * 0.65, -r * 0.72), COPPER, 2)
 if overlay == "power" and d.has("request"):
  canvas.draw_arc(c, r * 1.2, -PI * 0.5, -PI * 0.5 + TAU * ratio, 25, SIGNAL if ratio >= 0.7 else HOT, 2.2, true)

static func draw_conductor(canvas: CanvasItem, model: BloomSimulation, p: Dictionary, c: Vector2, tick: float, overlay: String) -> void:
 var d: Dictionary = Catalog.PARTS[p.id]
 var width := 5.0 if p.id == "vein" else 7.4
 var load_ratio: float = p.load / float(d.capacity)
 var lit: bool = p.load > 0.01
 var copper := COPPER.lightened(load_ratio * 0.18) if lit else COPPER.darkened(0.35)
 canvas.draw_circle(c, width + 3.0, Color("18271e"))
 for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  var q: Vector2i = Vector2i(p.x, p.y) + dir
  var j := model.at(q.x, q.y) if q.x >= 0 and q.y >= 0 and q.x < GRID and q.y < GRID else -1
  if j < 0 or not Catalog.PARTS[model.parts[j].id].has("ports"): continue
  var end := c + Vector2(dir) * CELL * 0.53
  canvas.draw_line(c, end, Color("14251b"), width + 6.0, true)
  canvas.draw_line(c, end, copper, width + 1.0, true)
  canvas.draw_line(c, end, Color(0.99, 0.78, 0.38, 0.65 if lit else 0.18), maxf(1.0, width - 3.0), true)
  if lit:
   var phase := fposmod(tick * (0.6 + load_ratio * 2.2) + p.x * 0.31 + p.y * 0.13, 1.0)
   canvas.draw_circle(c.lerp(end, phase), 2.4 + load_ratio, Color("ffeaad"))
 canvas.draw_circle(c, width * 0.62, SIGNAL if lit else Color("8b855e"))
 if p.id == "bundle":
  canvas.draw_arc(c, width + 2.0, 0, TAU, 16, COPPER.darkened(0.1), 1.2)
 if overlay == "power":
  canvas.draw_arc(c, width + 5.0, -PI * 0.5, -PI * 0.5 + TAU * load_ratio, 16, SIGNAL, 2.0)
