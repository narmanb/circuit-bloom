extends RefCounted
class_name BloomSimulation

const Catalog = preload("res://scripts/Catalog.gd")
const W := 24
const DT := 0.2
const AMBIENT := 25.0

var parts: Array[Dictionary] = []
var heat: Array[float] = []
var level := 0
var active_size := 12
var funds := 5200000.0
var gross_output := 0.0
var compute := 0.0 # exported MW, kept for compatibility with the old prototype
var sold_mw := 0.0
var peak := 0.0
var generation := 0.0 # steam raised t/h
var requested := 0.0 # steam requested t/h
var delivered := 0.0 # steam delivered t/h
var grid_capacity := 0.0
var grid_demand := 72.0
var hottest := AMBIENT
var sustain := 0.0
var awakened := false
var elapsed := 0.0
var bloom_time := 0.0
var revenue_total := 0.0

func _init(starting := true) -> void:
 heat.resize(W * W)
 heat.fill(AMBIENT)
 if starting:
  # A small synchronized starter train. The player expands from here.
  place("core", 11, 8, true)
  place("gland", 8, 12, true)
  place("vein", 9, 12, true)
  place("vein", 10, 12, true)
  place("processor", 11, 11, true)
  place("switchyard", 14, 11, true)
  place("radiator", 10, 14, true)
  tick()

func index(x: int, y: int) -> int:
 return y * W + x

func active(x: int, y: int) -> bool:
 var low := (W - active_size) / 2
 return x >= low and y >= low and x < low + active_size and y < low + active_size

func at(x: int, y: int) -> int:
 for i in parts.size():
  var p := parts[i]
  var sz: int = Catalog.PARTS[p.id].get("size", 1)
  if x >= p.x and x < p.x + sz and y >= p.y and y < p.y + sz:
   return i
 return -1

func spent_value() -> float:
 var total := 0.0
 for p in parts:
  total += float(Catalog.PARTS[p.id].cost)
 return total

func can_place(id: String, x: int, y: int, initial := false) -> bool:
 if not Catalog.PARTS.has(id): return false
 var d: Dictionary = Catalog.PARTS[id]
 if id == "core" and not initial: return false
 if not initial and d.get("unlock", 0) > level: return false
 if not initial and funds + 0.01 < float(d.cost): return false
 var sz: int = d.get("size", 1)
 for cy in range(y, y + sz):
  for cx in range(x, x + sz):
   if cx < 0 or cy < 0 or cx >= W or cy >= W: return false
   if not active(cx, cy) or at(cx, cy) >= 0: return false
 return true

func place(id: String, x: int, y: int, initial := false) -> bool:
 if not can_place(id, x, y, initial): return false
 var d: Dictionary = Catalog.PARTS[id]
 parts.append({
  "id":id, "x":x, "y":y, "power":0.0, "ratio":0.0, "load":0.0,
  "compute":0.0, "stored":0.0, "flow":0.0, "steam_out":0.0
 })
 if not initial:
  funds -= float(d.cost)
 return true

func remove(x: int, y: int) -> bool:
 var i := at(x, y)
 if i < 0 or parts[i].id == "core": return false
 funds += float(Catalog.PARTS[parts[i].id].cost) * 0.72
 parts.remove_at(i)
 return true

func neighbors(x: int, y: int) -> Array[Vector2i]:
 var out: Array[Vector2i] = []
 for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
  var q: Vector2i = Vector2i(x, y) + dir
  if q.x >= 0 and q.y >= 0 and q.x < W and q.y < W: out.append(q)
 return out

func conductive(i: int) -> bool:
 return parts[i].id in ["vein", "bundle"]

func touches_part(a: int, b: int) -> bool:
 var pa: Dictionary = parts[a]
 var da: Dictionary = Catalog.PARTS[pa.id]
 var sa: int = da.get("size", 1)
 for yy in range(pa.y, pa.y + sa):
  for xx in range(pa.x, pa.x + sa):
   for q in neighbors(xx, yy):
    if at(q.x, q.y) == b: return true
 return false

func route(source: int, target: int, need: float, availability: float) -> Dictionary:
 # BFS through explicit steam-pipe cells. Every conductor on the path has its own throughput.
 var queue: Array[int] = [source]
 var parent := {source:-1}
 var head := 0
 while head < queue.size():
  var i: int = queue[head]
  head += 1
  var p: Dictionary = parts[i]
  var size: int = Catalog.PARTS[p.id].get("size", 1)
  for yy in range(p.y, p.y + size):
   for xx in range(p.x, p.x + size):
    for q in neighbors(xx, yy):
     var j := at(q.x, q.y)
     if j < 0 or parent.has(j) or j == i: continue
     if j != target and not conductive(j): continue
     if conductive(j):
      var cap := float(Catalog.PARTS[parts[j].id].capacity)
      if cap - float(parts[j].load) <= 0.001: continue
     parent[j] = i
     if j == target:
      var path: Array[int] = []
      var cursor := j
      while cursor != source:
       if conductive(cursor): path.append(cursor)
       cursor = parent[cursor]
      var amount := minf(need, availability)
      for k in path:
       amount = minf(amount, float(Catalog.PARTS[parts[k].id].capacity) - float(parts[k].load))
      return {"amount":amount, "path":path}
     queue.append(j)
 return {"amount":0.0, "path":[]}

func _deliver(target: int, sources: Array[int], available: Dictionary, amount_needed: float) -> float:
 var got := 0.0
 for src in sources:
  if got >= amount_needed - 0.001: break
  var a: float = available.get(src, 0.0)
  if a <= 0.001: continue
  var result := route(src, target, amount_needed - got, a)
  var amount: float = result.amount
  if amount <= 0.001: continue
  got += amount
  available[src] = a - amount
  for k in result.path:
   parts[k].load += amount
 return got

func boiler_multiplier(i: int) -> float:
 var boosts := 0
 for j in parts.size():
  if parts[j].id == "pump" and touches_part(i, j): boosts += 1
 return 1.0 + minf(0.36, boosts * 0.12)

func _steam() -> void:
 generation = 0.0
 requested = 0.0
 delivered = 0.0
 var boilers: Array[int] = []
 var accumulators: Array[int] = []
 var turbines: Array[int] = []
 var available := {}
 var stored_available := {}

 for i in parts.size():
  var p := parts[i]
  var d: Dictionary = Catalog.PARTS[p.id]
  p.power = 0.0
  p.ratio = 0.0
  p.load = 0.0
  p.flow = 0.0
  p.compute = 0.0
  p.steam_out = 0.0
  if d.has("generate"):
   boilers.append(i)
   var output := float(d.generate) * boiler_multiplier(i)
   generation += output
   p.steam_out = output
   available[i] = output
  if d.has("request"):
   turbines.append(i)
   requested += float(d.request)
  if d.has("storage"):
   accumulators.append(i)
   stored_available[i] = minf(float(p.stored) / DT, float(d.rate))

 for target in turbines:
  var d: Dictionary = Catalog.PARTS[parts[target].id]
  var req := float(d.request)
  var got := _deliver(target, boilers, available, req)
  if got < req and not accumulators.is_empty():
   var before := stored_available.duplicate()
   got += _deliver(target, accumulators, stored_available, req - got)
   for c in accumulators:
    var spent: float = (float(before[c]) - float(stored_available[c])) * DT
    parts[c].stored = maxf(0.0, float(parts[c].stored) - spent)
    parts[c].flow -= spent / DT
  parts[target].power = got
  parts[target].ratio = got / req if req > 0.0 else 1.0
  delivered += got

 # Store genuine routed surplus only.
 for cap in accumulators:
  var d: Dictionary = Catalog.PARTS[parts[cap].id]
  var room: float = (float(d.storage) - float(parts[cap].stored)) / DT
  if room <= 0.0: continue
  var charge := _deliver(cap, boilers, available, minf(float(d.rate), room))
  parts[cap].stored += charge * DT
  parts[cap].flow += charge

func thermal_factor(t: float) -> float:
 if t <= 65.0: return 1.0
 if t < 75.0: return lerpf(1.0, 0.86, (t - 65.0) / 10.0)
 if t < 85.0: return lerpf(0.86, 0.52, (t - 75.0) / 10.0)
 if t < 95.0: return lerpf(0.52, 0.12, (t - 85.0) / 10.0)
 return 0.02

func _heat() -> void:
 var next := heat.duplicate()
 # Thermal diffusion is a hot path (5 simulation ticks/sec on mobile). Avoid
 # allocating a neighbors array for every one of the 576 yard cells.
 for y in W:
  for x in W:
   var idx := index(x, y)
   var center: float = heat[idx]
   var diffusion := 0.0
   if x > 0: diffusion += heat[idx - 1] - center
   if x + 1 < W: diffusion += heat[idx + 1] - center
   if y > 0: diffusion += heat[idx - W] - center
   if y + 1 < W: diffusion += heat[idx + W] - center
   next[idx] += DT * (0.14 * diffusion - 0.015 * (center - AMBIENT))

 for p in parts:
  var d: Dictionary = Catalog.PARTS[p.id]
  var footprint: int = d.get("size", 1)
  var work_ratio := float(p.ratio) if d.has("request") else 1.0
  var added: float = float(d.get("heat", 0.0)) * (0.18 + 0.82 * work_ratio)
  if d.has("capacity"):
   var load_ratio := float(p.load) / maxf(1.0, float(d.capacity))
   added += 1.2 * load_ratio * load_ratio
  for yy in range(p.y, p.y + footprint):
   for xx in range(p.x, p.x + footprint):
    next[index(xx, yy)] += DT * added / float(footprint * footprint)
  if d.has("cool"):
   var strength := float(d.cool)
   for yy in range(maxi(0, p.y - 2), mini(W, p.y + footprint + 2)):
    for xx in range(maxi(0, p.x - 2), mini(W, p.x + footprint + 2)):
     var dx := 0 if xx >= p.x and xx < p.x + footprint else mini(absi(xx - p.x), absi(xx - (p.x + footprint - 1)))
     var dy := 0 if yy >= p.y and yy < p.y + footprint else mini(absi(yy - p.y), absi(yy - (p.y + footprint - 1)))
     var dist := dx + dy
     if dist <= 2:
      var idx := index(xx, yy)
      next[idx] -= DT * strength / (1.0 + dist * 1.25) * clampf((heat[idx] - AMBIENT) / 14.0, 0.0, 1.0)

 hottest = AMBIENT
 for i in next.size():
  next[i] = maxf(AMBIENT, next[i])
  hottest = maxf(hottest, next[i])
 heat = next

func part_temperature(p: Dictionary) -> float:
 var d: Dictionary = Catalog.PARTS[p.id]
 var sz: int = d.get("size", 1)
 var t := AMBIENT
 for yy in range(p.y, p.y + sz):
  for xx in range(p.x, p.x + sz): t = maxf(t, heat[index(xx, yy)])
 return t

func _electrical() -> void:
 gross_output = 0.0
 grid_capacity = 0.0
 for p in parts:
  var d: Dictionary = Catalog.PARTS[p.id]
  if d.has("compute"):
   p.compute = float(d.compute) * float(p.ratio) * thermal_factor(part_temperature(p))
   gross_output += float(p.compute)
  if d.has("grid_capacity"):
   grid_capacity += float(d.grid_capacity)

 compute = minf(gross_output, grid_capacity)
 grid_demand = minf(620.0, 72.0 + elapsed * 0.18 + level * 18.0)
 sold_mw = minf(compute, grid_demand)
 peak = maxf(peak, compute)

 # Scaled cashflow for a short prototype session rather than real-world accounting.
 var earned := sold_mw * 145.0 * DT
 funds += earned
 revenue_total += earned

func _milestones() -> void:
 if level >= Catalog.GOALS.size(): return
 var goal: Dictionary = Catalog.GOALS[level]
 var okay: bool = sold_mw >= float(goal.target) and hottest < 96.0
 sustain = sustain + DT if okay else 0.0
 if sustain >= float(goal.seconds):
  level += 1
  active_size = int(goal.size)
  funds += float(goal.funds)
  sustain = 0.0
  bloom_time = 2.0
  if level == Catalog.GOALS.size(): awakened = true

func tick() -> void:
 elapsed += DT
 bloom_time = maxf(0.0, bloom_time - DT)
 _steam()
 _heat()
 _electrical()
 _milestones()

func snapshot() -> Dictionary:
 return {
  "version":2, "parts":parts.duplicate(true), "heat":heat.duplicate(), "level":level,
  "active_size":active_size, "funds":funds, "peak":peak, "sustain":sustain,
  "awakened":awakened, "elapsed":elapsed, "revenue_total":revenue_total
 }

func restore(data: Dictionary) -> bool:
 if int(data.get("version", -1)) != 2: return false
 if not data.get("parts") is Array or not data.get("heat") is Array or data.heat.size() != W * W: return false
 var restored: Array[Dictionary] = []
 for p in data.parts:
  if not p is Dictionary or not Catalog.PARTS.has(p.get("id", "")): return false
  var px := int(p.get("x", -1))
  var py := int(p.get("y", -1))
  if px < 0 or py < 0 or px >= W or py >= W: return false
  restored.append(p.duplicate(true))
 parts = restored
 heat.clear()
 for h in data.heat: heat.append(clampf(float(h), AMBIENT, 500.0))
 level = clampi(int(data.get("level", 0)), 0, Catalog.GOALS.size())
 active_size = clampi(int(data.get("active_size", 12)), 12, W)
 funds = maxf(0.0, float(data.get("funds", 5200000.0)))
 peak = maxf(0.0, float(data.get("peak", 0.0)))
 sustain = maxf(0.0, float(data.get("sustain", 0.0)))
 awakened = bool(data.get("awakened", false))
 elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
 revenue_total = maxf(0.0, float(data.get("revenue_total", 0.0)))
 _steam()
 _electrical()
 return true
