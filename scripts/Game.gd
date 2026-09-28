extends Control

const Sim = preload("res://scripts/Simulation.gd")
const Catalog = preload("res://scripts/Catalog.gd")
const BoardArt = preload("res://scripts/rendering/BoardArt.gd")
const InterfaceArt = preload("res://scripts/ui/InterfaceArt.gd")
const SAVE_PATH := "user://circuit_bloom_powerplant_v1.json"
const CELL := 34.0

var model: BloomSimulation
var tool := ""
var category := "Build"
var overlay := ""
var selected := -1
var paused := false
var speed := 1
var zoom := 0.78
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
var help_index := -1
var last_level := 0
var grid_visible := false

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
  file.store_string(JSON.stringify({
   "simulation":model.snapshot(),
   "settings":{"speed":speed, "overlay":overlay, "tutorial":tutorial, "category":category, "grid":grid_visible}
  }))

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
  category = str(settings.get("category", "Build"))
  if not category in InterfaceArt.CATEGORIES: category = "Build"
  grid_visible = bool(settings.get("grid", false))

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
    if model.level >= Catalog.GOALS.size():
     message = "FULL LOAD — Free-build operations unlocked"
    else:
     message = "MILESTONE — " + str(Catalog.GOALS[model.level - 1].reward)
    message_time = 5.0
    save_game()
  save_clock += delta
  if save_clock >= 20.0:
   save_clock = 0.0
   save_game()
 queue_redraw()

func board_origin() -> Vector2:
 var usable := Vector2(size.x - InterfaceArt.SIDE_W, size.y - InterfaceArt.TOP - InterfaceArt.BOTTOM)
 return Vector2(usable.x * 0.5, InterfaceArt.TOP + usable.y * 0.5) + pan

func on_board(pos: Vector2) -> bool:
 return pos.x >= 0.0 and pos.x < size.x - InterfaceArt.SIDE_W and pos.y > InterfaceArt.TOP and pos.y < size.y - InterfaceArt.BOTTOM

func world_to_screen(cell: Vector2) -> Vector2:
 return board_origin() + (cell - Vector2(12, 12)) * CELL * zoom

func screen_to_cell(point: Vector2) -> Vector2i:
 var f := (point - board_origin()) / (CELL * zoom) + Vector2(12, 12)
 return Vector2i(floori(f.x), floori(f.y))

func ui_button_at(pos: Vector2) -> String:
 for i in InterfaceArt.ACTIONS.size():
  if InterfaceArt.action_rect(i, size).has_point(pos): return InterfaceArt.ACTIONS[i]
 for i in 5:
  if InterfaceArt.metric_rect(i, size).has_point(pos): return "metric:" + str(i)
 for i in InterfaceArt.CATEGORIES.size():
  if InterfaceArt.category_rect(i, size).has_point(pos): return "category:" + InterfaceArt.CATEGORIES[i]
 var items := InterfaceArt.items_for(category)
 for i in mini(items.size(), 6):
  if InterfaceArt.part_rect(i, size).has_point(pos): return items[i]
 var bottom_y := size.y - InterfaceArt.BOTTOM
 for i in 3:
  var rect := Rect2(10 + i * 94, bottom_y + 6, 84, 52)
  if rect.has_point(pos):
   return ["select", "grid", "remove"][i]
 return ""

func choose_button(id: String) -> void:
 if id.begins_with("metric:"):
  var requested := int(id.substr(7))
  help_index = -1 if help_index == requested else requested
  return
 if id.begins_with("category:"):
  category = id.substr(9)
  tool = ""
  selected = -1
  return
 match id:
  "pause":
   paused = not paused
   save_game()
  "speed": speed = 2 if speed == 1 else (4 if speed == 2 else 1)
  "heat": overlay = "" if overlay == "heat" else "heat"
  "power": overlay = "" if overlay == "power" else "power"
  "undo": undo()
  "redo": redo()
  "select": tool = ""
  "grid": grid_visible = not grid_visible
  "remove": tool = "remove"
  _:
   if Catalog.PARTS.has(id):
    var d: Dictionary = Catalog.PARTS[id]
    if int(d.get("unlock", 0)) > model.level:
     message = "Locked — reach the next output milestone"
     message_time = 2.5
    elif model.funds + 0.01 < float(d.cost):
     message = "Not enough funds"
     message_time = 2.0
    else:
     tool = "" if tool == id else id
 tutorial = maxi(tutorial, 1)

func remember() -> void:
 history.append(model.snapshot())
 if history.size() > 50: history.pop_front()
 future.clear()

func undo() -> void:
 if history.is_empty(): return
 future.append(model.snapshot())
 model.restore(history.pop_back())
 last_level = model.level
 selected = -1
 save_game()

func redo() -> void:
 if future.is_empty(): return
 history.append(model.snapshot())
 model.restore(future.pop_back())
 last_level = model.level
 selected = -1
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
  return
 if existing >= 0:
  selected = existing
  return
 var prior := model.snapshot()
 if model.place(tool, c.x, c.y):
  history.append(prior)
  if history.size() > 50: history.pop_front()
  future.clear()
  selected = model.parts.size() - 1
  save_game()
 elif not painting:
  message = "Cannot build here — check funds, yard boundary, unlock, or occupied space"
  message_time = 2.4

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
  if pinch_distance > 5.0: zoom = clampf(zoom * new_dist / pinch_distance, 0.42, 1.75)
  pinch_distance = new_dist
  pinch_midpoint = new_mid
  return
 if gesture_start.distance_to(pos) > 13.0: dragging = true
 if dragging and on_board(gesture_start):
  if tool in ["vein", "bundle", "remove"]:
   if not painting:
    edit_at(gesture_start)
    painting = true
   var from := screen_to_cell(previous_point)
   var to := screen_to_cell(pos)
   var steps := maxi(1, maxi(absi(to.x - from.x), absi(to.y - from.y)))
   for step in range(steps + 1):
    var v := Vector2(from).lerp(Vector2(to), float(step) / float(steps))
    edit_at(world_to_screen(v + Vector2(0.5, 0.5)))
  elif tool == "":
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
 if help_index >= 0:
  if button.begins_with("metric:"): choose_button(button)
  else: help_index = -1
  return
 if button != "": choose_button(button)
 elif on_board(pos): edit_at(pos)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed: pointer_down(event.position, event.index)
  else: pointer_up(event.position, event.index)
  accept_event()
 elif event is InputEventScreenDrag:
  pointer_move(event.position, event.index)
  accept_event()
 elif event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = minf(1.75, zoom * 1.12)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = maxf(0.42, zoom / 1.12)
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

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("081017"))
 draw_set_transform(board_origin() - Vector2(12, 12) * CELL * zoom, 0.0, Vector2.ONE * zoom)
 var preview := Vector2i(-1, -1)
 var preview_ok := false
 if not touches.is_empty() and tool != "" and not dragging and on_board(previous_point):
  preview = screen_to_cell(previous_point)
  if preview.x >= 0 and preview.y >= 0 and preview.x < Sim.W and preview.y < Sim.W:
   if tool == "remove":
    var found := model.at(preview.x, preview.y)
    preview_ok = found >= 0 and model.parts[found].id != "core"
   else:
    preview_ok = model.can_place(tool, preview.x, preview.y)
  else:
   preview = Vector2i(-1, -1)
 BoardArt.draw_board(self, model, visual_time, overlay, tool, selected, preview, preview_ok, grid_visible)
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
 InterfaceArt.draw(self, model, size, category, tool, selected, overlay, paused, speed, tutorial, message, message_time, help_index, zoom, grid_visible)
