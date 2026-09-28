extends Control

const Sim = preload("res://scripts/Simulation.gd")
const Catalog = preload("res://scripts/Catalog.gd")
const SAVE_PATH := "user://circuit_bloom_v1.json"
const CELL := 34.0
var model: BloomSimulation
var tool := ""
var overlay := ""
var selected := -1
var paused := false
var speed := 1
var zoom := 1.0
var pan := Vector2.ZERO
var clock := 0.0
var visual_time := 0.0
var save_clock := 0.0
var tutorial := 0
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var touches := {}
var gesture_start := Vector2.ZERO
var previous_point := Vector2.ZERO
var dragging := false
var painting := false
var pinch_distance := 0.0
var pinch_midpoint := Vector2.ZERO
var message := ""
var message_time := 0.0
var last_level := 0

func _ready() -> void:
 model = Sim.new()
 load_game()
 last_level = model.level
 set_process(true)
 queue_redraw()

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
  save_game()

func save_game() -> void:
 var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
 if file:
  file.store_string(JSON.stringify({"simulation":model.snapshot(), "settings":{"speed":speed, "overlay":overlay, "tutorial":tutorial}}))

func load_game() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
 if not file: return
 var data = JSON.parse_string(file.get_as_text())
 if not data is Dictionary or not data.get("simulation") is Dictionary: return
 var candidate := Sim.new(false)
 if candidate.restore(data.simulation):
  model = candidate
  var settings: Dictionary = data.get("settings", {})
  speed = clampi(int(settings.get("speed", 1)), 1, 4)
  overlay = str(settings.get("overlay", ""))
  tutorial = int(settings.get("tutorial", 0))

func _process(delta: float) -> void:
 visual_time += delta
 message_time -= delta
 if not paused:
  clock += minf(delta, 0.25) * speed
  while clock >= Sim.DT:
   model.tick()
   clock -= Sim.DT
   if model.level != last_level:
    last_level = model.level
    message = "AWAKENING — Continue in Sandbox" if model.awakened else "BLOOM: " + Catalog.GOALS[last_level - 1].reward
    message_time = 5.0
    save_game()
  save_clock += delta
  if save_clock >= 25.0:
   save_clock = 0.0
   save_game()
 queue_redraw()

func board_origin() -> Vector2:
 return Vector2(size.x * 0.5, (size.y - 105.0) * 0.5 + 48.0) + pan

func world_to_screen(cell: Vector2) -> Vector2:
 return board_origin() + (cell - Vector2(12, 12)) * CELL * zoom

func screen_to_cell(point: Vector2) -> Vector2i:
 var f := (point - board_origin()) / (CELL * zoom) + Vector2(12, 12)
 return Vector2i(floori(f.x), floori(f.y))

func palette_items() -> Array[Dictionary]:
 var items: Array[Dictionary] = []
 items.append({"id":"select", "label":"Select"})
 for id in Catalog.ORDER:
  items.append({"id":id, "label":Catalog.PARTS[id].name})
 items.append({"id":"remove", "label":"Remove"})
 return items

func ui_button_at(pos: Vector2) -> String:
 var right := size.x
 if pos.y < 89.0:
  if pos.x > right - 90: return "pause"
  if pos.x > right - 168: return "speed"
  if pos.x > right - 252: return "heat"
  if pos.x > right - 338: return "power"
  if pos.x > right - 420: return "redo"
  if pos.x > right - 500: return "undo"
 if pos.y > size.y - 106.0:
  var items := palette_items()
  var width := minf(112.0, (size.x - 20.0) / items.size())
  var slot := floori((pos.x - 10.0) / width)
  if slot >= 0 and slot < items.size(): return items[slot].id
 return ""

func choose_button(id: String) -> void:
 match id:
  "pause":
   paused = not paused
   save_game()
  "speed":
   speed = 2 if speed == 1 else (4 if speed == 2 else 1)
  "heat": overlay = "" if overlay == "heat" else "heat"
  "power": overlay = "" if overlay == "power" else "power"
  "undo": undo()
  "redo": redo()
  "select": tool = ""
  "remove": tool = "remove"
  _:
   if Catalog.PARTS.has(id):
    if Catalog.PARTS[id].get("unlock", 0) > model.level:
     message = "Unlock at " + Catalog.GOALS[int(Catalog.PARTS[id].unlock) - 1].name
     message_time = 2.5
    else: tool = "" if tool == id else id
 tutorial = maxi(tutorial, 1)

func remember() -> void:
 history.append(model.snapshot())
 if history.size() > 40: history.pop_front()
 future.clear()

func undo() -> void:
 if history.is_empty(): return
 future.append(model.snapshot())
 model.restore(history.pop_back())
 last_level = model.level
 save_game()

func redo() -> void:
 if future.is_empty(): return
 history.append(model.snapshot())
 model.restore(future.pop_back())
 last_level = model.level
 save_game()

func edit_at(pos: Vector2) -> void:
 var c := screen_to_cell(pos)
 if c.x < 0 or c.y < 0 or c.x >= Sim.W or c.y >= Sim.W: return
 if tool == "":
  selected = model.at(c.x, c.y)
  return
 var existing := model.at(c.x, c.y)
 if tool == "remove":
  if existing >= 0 and model.parts[existing].id != "core":
   remember()
   model.remove(c.x, c.y)
   selected = -1
   save_game()
 elif not (existing >= 0 and model.parts[existing].id == tool):
  var prior := model.snapshot()
  if model.place(tool, c.x, c.y):
   history.append(prior)
   if history.size() > 40: history.pop_front()
   future.clear()
   selected = model.parts.size() - 1
   save_game()
  elif not painting:
   message = "Blocked: space, dormant tissue, unlock, or biomass"
   message_time = 2.0

func pointer_down(pos: Vector2, index: int) -> void:
 touches[index] = pos
 if touches.size() == 1:
  gesture_start = pos
  previous_point = pos
  dragging = false
  painting = false
 elif touches.size() == 2:
  var points := touches.values()
  pinch_distance = points[0].distance_to(points[1])
  pinch_midpoint = (points[0] + points[1]) * 0.5
  dragging = true

func pointer_move(pos: Vector2, index: int) -> void:
 if not touches.has(index): return
 touches[index] = pos
 if touches.size() == 2:
  var points := touches.values()
  var new_mid: Vector2 = (points[0] + points[1]) * 0.5
  var new_dist: float = points[0].distance_to(points[1])
  pan += new_mid - pinch_midpoint
  if pinch_distance > 5.0: zoom = clampf(zoom * new_dist / pinch_distance, 0.45, 2.5)
  pinch_distance = new_dist
  pinch_midpoint = new_mid
  return
 if gesture_start.distance_to(pos) > 13.0: dragging = true
 if dragging and gesture_start.y < size.y - 106.0 and gesture_start.y > 89.0:
  if tool in ["vein", "bundle", "remove"]:
   if not painting:
    edit_at(gesture_start)
    painting = true
   # Fill skipped cells on fast drags.
   var from := screen_to_cell(previous_point)
   var to := screen_to_cell(pos)
   var steps := maxi(1, maxi(absi(to.x - from.x), absi(to.y - from.y)))
   for step in range(steps + 1):
    var v := Vector2(from).lerp(Vector2(to), float(step) / steps)
    edit_at(world_to_screen(v + Vector2(0.5, 0.5)))
  else:
   pan += pos - previous_point
 previous_point = pos

func pointer_up(pos: Vector2, index: int) -> void:
 if not touches.has(index): return
 var single := touches.size() == 1
 touches.erase(index)
 if not single or dragging: return
 if tutorial == 0:
  tutorial = 1
  return
 var button := ui_button_at(pos)
 if button != "": choose_button(button)
 elif pos.y > 89.0 and pos.y < size.y - 106.0: edit_at(pos)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed: pointer_down(event.position, event.index)
  else: pointer_up(event.position, event.index)
  accept_event()
 elif event is InputEventScreenDrag:
  pointer_move(event.position, event.index)
  accept_event()
 elif event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = minf(2.5, zoom * 1.12)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = maxf(0.45, zoom / 1.12)
  elif event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed: pointer_down(event.position, -1)
   else: pointer_up(event.position, -1)
  accept_event()
 elif event is InputEventMouseMotion and touches.has(-1):
  pointer_move(event.position, -1)
  accept_event()
 elif event is InputEventKey and event.pressed:
  if event.keycode == KEY_ESCAPE: tool = ""
  if event.keycode == KEY_SPACE: paused = not paused
  if event.ctrl_pressed and event.keycode == KEY_Z: undo()
  if event.ctrl_pressed and event.keycode == KEY_Y: redo()

func label(text: String, pos: Vector2, font_size := 17, color := Color(0.78, 0.91, 0.87)) -> void:
 draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("080f17"))
 draw_set_transform(board_origin() - Vector2(12, 12) * CELL * zoom, 0.0, Vector2.ONE * zoom)
 draw_board()
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
 draw_ui()

func draw_board() -> void:
 var tick: float = visual_time
 for y in Sim.W:
  for x in Sim.W:
   var center := Vector2(x + 0.5, y + 0.5) * CELL
   var awake := model.active(x, y)
   var phase := sin(float(x * 17 + y * 29) * 0.37 + tick * 1.1)
   var base := Color(0.045, 0.105, 0.13) if awake else Color(0.025, 0.044, 0.07)
   draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), base)
   var fiber := Color(0.12, 0.27, 0.27, 0.35) if awake else Color(0.10, 0.16, 0.19, 0.25)
   draw_line(center + Vector2(-16, -9), center + Vector2(5, 1), fiber, 1.5)
   draw_line(center + Vector2(5, 1), center + Vector2(17, 11), fiber, 1.0)
   if (x * 7 + y * 11) % 5 == 0:
    draw_circle(center + Vector2(11, -8), 2.0 + phase * 0.3, Color(0.23, 0.43, 0.38, 0.35 if awake else 0.12))
   if not awake:
    draw_arc(center, 12.0, 0.3, 4.9, 10, Color(0.14, 0.18, 0.24, 0.35), 1.0)
   if overlay == "heat":
    var t: float = model.heat[model.index(x, y)]
    var strength := clampf((t - 30.0) / 65.0, 0.0, 0.73)
    draw_circle(center, CELL * 0.65, Color(1.0, 0.32 if t < 80.0 else 0.09, 0.08, strength))
   if tool != "":
    draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), Color(0.38, 0.62, 0.58, 0.12), false, 0.8)
 for p in model.parts:
  draw_part(p, tick)
 if selected >= 0 and selected < model.parts.size():
  var p: Dictionary = model.parts[selected]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  draw_rect(Rect2(Vector2(p.x, p.y) * CELL, Vector2.ONE * CELL * sz), Color("c6f8df"), false, 2.0)
 if not touches.is_empty() and tool != "" and not dragging:
  var c := screen_to_cell(previous_point)
  if c.x >= 0 and c.y >= 0 and c.x < Sim.W and c.y < Sim.W:
   var sz: int = Catalog.PARTS.get(tool, {}).get("size", 1)
   var okay: bool = tool == "remove" or model.can_place(tool, c.x, c.y)
   draw_rect(Rect2(Vector2(c) * CELL, Vector2.ONE * CELL * sz), Color(0.3, 1.0, 0.7, 0.3) if okay else Color(1.0, 0.22, 0.2, 0.3))
 if model.bloom_time > 0.0:
  var wave := (2.0 - model.bloom_time) * 420.0
  draw_arc(Vector2(12, 12) * CELL, wave, 0, TAU, 90, Color(0.34, 1.0, 0.76, model.bloom_time / 2.0), 3.0)

func draw_part(p: Dictionary, tick: float) -> void:
 var id: String = p.id
 var d: Dictionary = Catalog.PARTS[id]
 var sz: int = d.get("size", 1)
 var c := Vector2(p.x + sz * 0.5, p.y + sz * 0.5) * CELL
 var r := CELL * (0.38 if sz == 1 else 0.78)
 var temp: float = model.heat[model.index(p.x, p.y)]
 var powered: float = p.ratio if d.has("request") else 1.0
 var pulse := 0.78 + 0.22 * sin(tick * 3.0 + p.x)
 var glow := Color(0.22, 0.95, 0.68, 0.13 * pulse * maxf(powered, 0.1))
 if temp > 70.0: glow = Color(1.0, 0.22, 0.08, clampf((temp - 55.0) / 130.0, 0.1, 0.55))
 draw_circle(c, r * 1.4, glow)
 if id in ["vein", "bundle"]:
  var width := 3.0 if id == "vein" else 5.0
  var load_ratio: float = p.load / float(d.capacity)
  var vein_color := Color(0.18 + load_ratio * 0.2, 0.37 + load_ratio * 0.4, 0.38 + load_ratio * 0.3) if p.load > 0 else Color(0.18, 0.27, 0.29)
  draw_circle(c, width + 2.0, Color(0.11, 0.27, 0.28))
  for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
   var q: Vector2i = Vector2i(p.x, p.y) + dir
   var j := model.at(q.x, q.y) if q.x >= 0 and q.y >= 0 and q.x < Sim.W and q.y < Sim.W else -1
   if j < 0 or not Catalog.PARTS[model.parts[j].id].has("ports"): continue
   var end := c + Vector2(dir) * CELL * 0.52
   draw_line(c, end, Color(0.07, 0.19, 0.22), width + 6.0, true)
   draw_line(c, end, vein_color, width, true)
   if p.load > 0.01:
    var phase := fposmod(tick * (0.8 + load_ratio * 2.5) + p.x * 0.31 + p.y * 0.13, 1.0)
    draw_circle(c.lerp(end, phase), 2.2 + load_ratio * 1.5, Color(0.68, 1.0, 0.77, 0.7))
  if overlay == "power":
   label("%d/%d" % [roundi(p.load), roundi(d.capacity)], c + Vector2(-14, -12), 9, Color.WHITE)
  return
 var shell := Color(0.15, 0.38, 0.38) if powered > 0.05 else Color(0.12, 0.17, 0.21)
 if id == "gland": shell = Color(0.19, 0.46, 0.34)
 if id in ["radiator", "cooler"]: shell = Color(0.13, 0.40, 0.52)
 if id in ["processor", "cluster"]: shell = Color(0.30, 0.33, 0.52)
 draw_circle(c, r, Color(0.06, 0.16, 0.20))
 draw_arc(c, r * (0.84 + 0.035 * sin(tick * 2.0)), 0, TAU, 24, shell, 4.0)
 for k in 6:
  var angle := float(k) * TAU / 6.0 + float(p.x % 3) * 0.2
  var edge := c + Vector2.from_angle(angle) * r * 0.89
  draw_line(c + Vector2.from_angle(angle + 0.35) * r * 0.38, edge, shell.lightened(0.25), 1.5, true)
  draw_circle(edge, 2.0, shell.lightened(0.3))
 if id == "core":
  draw_arc(c, r * 0.68, tick * 0.15, tick * 0.15 + TAU * 0.8, 20, Color(0.4, 0.95, 0.75), 2.3)
  draw_circle(c, r * (0.25 + sin(tick * 2.2) * 0.035), Color(0.69, 1.0, 0.82))
 elif id == "gland":
  draw_circle(c, r * (0.42 + sin(tick * 2.8) * 0.04), Color(0.38, 0.92, 0.55))
  draw_arc(c, r * 0.63, -1.2, 1.4, 12, Color(0.86, 1.0, 0.66), 2.0)
 elif id in ["processor", "cluster"]:
  var count := 4 if id == "cluster" else 1
  for k in count:
   var off := Vector2((k % 2) * 2 - 1, (k / 2) * 2 - 1) * (r * 0.31) if count == 4 else Vector2.ZERO
   draw_circle(c + off, r * (0.2 if count == 4 else 0.34), Color(0.49, 0.83, 0.96, maxf(0.16, powered)))
   draw_circle(c + off, r * 0.09, Color(0.86, 0.99, 1.0, maxf(0.16, powered)))
 elif id in ["radiator", "cooler"]:
  for k in 4:
   var a := -0.9 + k * 0.6
   draw_line(c + Vector2(0, r * 0.5), c + Vector2.from_angle(a) * r * 0.65, Color(0.43, 0.79, 0.86), 2.8, true)
  draw_circle(c + Vector2(0, -r * 0.1), 3.0, Color(0.61, 0.95, 1.0))
 elif id == "capacitor":
  draw_circle(c, r * 0.5, Color(0.17, 0.26, 0.35))
  draw_arc(c, r * 0.48, -PI / 2.0, -PI / 2.0 + TAU * float(p.stored) / float(d.storage), 20, Color(0.69, 0.95, 0.98), 4.0)
 if overlay == "power" and d.has("request"):
  draw_arc(c, r * 1.12, -PI / 2.0, -PI / 2.0 + TAU * powered, 20, Color(0.4, 1.0, 0.64) if powered > 0.7 else Color(1.0, 0.35, 0.22), 2.0)

func draw_ui() -> void:
 draw_rect(Rect2(0, 0, size.x, 89), Color(0.055, 0.10, 0.15, 0.97))
 draw_rect(Rect2(0, size.y - 106, size.x, 106), Color(0.055, 0.10, 0.15, 0.97))
 label("CIRCUIT BLOOM", Vector2(15, 25), 18, Color("9de8c7"))
 label("%.1f CU/s    Peak %.1f" % [model.compute, model.peak], Vector2(15, 52), 18)
 label("Power %d / %d   Reserve %d" % [roundi(model.delivered), roundi(model.requested), roundi(model.generation - model.delivered)], Vector2(260, 27), 15)
 label("Biomass %d / %d    Hot %.0f°C" % [model.biomass_used(), model.biomass_max, model.hottest], Vector2(260, 53), 15)
 if model.level < Catalog.GOALS.size():
  var g: Dictionary = Catalog.GOALS[model.level]
  label("%s: %d CU/s  %d/%ds" % [g.name, roundi(g.target), floori(model.sustain), roundi(g.seconds)], Vector2(15, 78), 13, Color("c8d8b4"))
 else: label("AWAKENING — Sandbox continues", Vector2(15, 78), 14, Color("acefc4"))
 var labels := ["Undo", "Redo", "Power", "Heat", "%dx" % speed, "Play" if paused else "Pause"]
 for i in labels.size():
  var x := size.x - 500 + i * 82
  draw_rect(Rect2(x, 8, 78, 57), Color(0.11, 0.22, 0.26), true)
  label(labels[i], Vector2(x + 8, 42), 15)
 var items := palette_items()
 var width := minf(112.0, (size.x - 20.0) / items.size())
 for i in items.size():
  var id: String = items[i].id
  var x := 10.0 + i * width
  var locked: bool = Catalog.PARTS.has(id) and Catalog.PARTS[id].get("unlock", 0) > model.level
  var bg := Color(0.17, 0.36, 0.36) if tool == id else Color(0.10, 0.19, 0.24)
  if locked: bg = Color(0.08, 0.11, 0.14)
  draw_rect(Rect2(x, size.y - 98, width - 4, 86), bg)
  label(id.substr(0, 1).to_upper(), Vector2(x + 11, size.y - 61), 27, Color(0.43, 0.91, 0.73) if not locked else Color(0.31, 0.39, 0.4))
  label(id.capitalize(), Vector2(x + 5, size.y - 37), 12, Color(0.75, 0.91, 0.88) if not locked else Color(0.43, 0.48, 0.5))
  if Catalog.PARTS.has(id):
   label("%d biomass" % Catalog.PARTS[id].cost, Vector2(x + 5, size.y - 17), 10)
 if selected >= 0 and selected < model.parts.size():
  var p: Dictionary = model.parts[selected]
  var d: Dictionary = Catalog.PARTS[p.id]
  var rect := Rect2(size.x - 238, 99, 228, 213)
  draw_rect(rect, Color(0.05, 0.12, 0.17, 0.94))
  label(d.name, rect.position + Vector2(9, 26), 17)
  label("Power: %.1f / %.1f (%.0f%%)" % [p.power, d.get("request", 0.0), p.ratio * 100.0], rect.position + Vector2(9, 54), 13)
  label("Compute: %.1f CU/s" % p.compute, rect.position + Vector2(9, 78), 13)
  label("Temp: %.1f°C    Biomass: %d" % [model.heat[model.index(p.x, p.y)], d.cost], rect.position + Vector2(9, 102), 13)
  if d.has("capacity"): label("Flow: %.1f / %.0f" % [p.load, d.capacity], rect.position + Vector2(9, 126), 13)
  if d.has("storage"): label("Charge: %.1f / %.0f" % [p.stored, d.storage], rect.position + Vector2(9, 126), 13)
  label("Online" if p.ratio >= 0.9 or not d.has("request") else ("Brownout" if p.ratio > 0 else "Offline"), rect.position + Vector2(9, 151), 13)
  label(d.description.substr(0, 29), rect.position + Vector2(9, 180), 12)
  label(d.description.substr(29, 29), rect.position + Vector2(9, 198), 12)
 if tutorial == 0:
  draw_rect(Rect2(size.x * 0.24, size.y * 0.31, size.x * 0.52, 127), Color(0.06, 0.17, 0.21, 0.96))
  label("This organism is already computing.", Vector2(size.x * 0.28, size.y * 0.36), 21)
  label("Pulses carry power. Compute creates heat; radiators cool it.", Vector2(size.x * 0.28, size.y * 0.40), 16)
  label("Build new cells and reach 50 CU/s. Tap anywhere to begin.", Vector2(size.x * 0.28, size.y * 0.44), 16)
 if message_time > 0.0:
  draw_rect(Rect2(size.x * 0.3, 100, size.x * 0.4, 42), Color(0.13, 0.32, 0.3, 0.95))
  label(message, Vector2(size.x * 0.31, 128), 16)
