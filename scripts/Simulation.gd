extends RefCounted
class_name BloomSimulation

const Catalog = preload("res://scripts/Catalog.gd")
const W := 24
const DT := 0.2
var parts: Array[Dictionary] = []
var heat: Array[float] = []
var level := 0
var active_size := 10
var biomass_max := 70
var compute := 0.0
var peak := 0.0
var generation := 0.0
var requested := 0.0
var delivered := 0.0
var hottest := 25.0
var sustain := 0.0
var awakened := false
var elapsed := 0.0
var bloom_time := 0.0

func _init(starting := true) -> void:
 heat.resize(W * W)
 heat.fill(25.0)
 if starting:
  place("core", 11, 11, true)
  place("gland", 9, 12, true)
  place("vein", 10, 12, true)
  place("vein", 11, 12, true)
  place("vein", 12, 12, true)
  place("processor", 13, 12, true)
  place("radiator", 13, 13, true)
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

func biomass_used() -> int:
 var total := 0
 for p in parts:
  total += Catalog.PARTS[p.id].cost
 return total

func can_place(id: String, x: int, y: int, initial := false) -> bool:
 if not Catalog.PARTS.has(id): return false
 var d: Dictionary = Catalog.PARTS[id]
 if not initial and d.get("unlock", 0) > level: return false
 if not initial and biomass_used() + d.cost > biomass_max: return false
 var sz: int = d.get("size", 1)
 for cy in range(y, y + sz):
  for cx in range(x, x + sz):
   if cx < 0 or cy < 0 or cx >= W or cy >= W or not active(cx, cy) or at(cx, cy) >= 0: return false
 return true

func place(id: String, x: int, y: int, initial := false) -> bool:
 if not can_place(id, x, y, initial): return false
 parts.append({"id":id, "x":x, "y":y, "power":0.0, "ratio":0.0, "load":0.0, "compute":0.0, "stored":0.0, "flow":0.0})
 return true

func remove(x: int, y: int) -> bool:
 var i := at(x, y)
 if i < 0 or parts[i].id == "core": return false
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

func route(source: int, target: int, need: float, availability: float) -> Dictionary:
 # Breadth-first search over actual conductor cells. A route consumes segment throughput.
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
     if conductive(j) and float(Catalog.PARTS[parts[j].id].capacity) - parts[j].load <= 0.001: continue
     parent[j] = i
     if j == target:
      var path: Array[int] = []
      var cursor := j
      while cursor != source:
       if conductive(cursor): path.append(cursor)
       cursor = parent[cursor]
      var amount := minf(need, availability)
      for k in path:
       amount = minf(amount, float(Catalog.PARTS[parts[k].id].capacity) - parts[k].load)
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

func _power() -> void:
 generation = 0.0
 requested = 0.0
 delivered = 0.0
 var generators: Array[int] = []
 var caps: Array[int] = []
 var consumers: Array[int] = []
 var available := {}
 var cap_remaining := {}
 for i in parts.size():
  var p := parts[i]
  var d: Dictionary = Catalog.PARTS[p.id]
  p.power = 0.0
  p.ratio = 0.0
  p.load = 0.0
  p.flow = 0.0
  p.compute = 0.0
  var req: float = d.get("request", 0.0)
  requested += req
  if req > 0.0: consumers.append(i)
  if d.has("generate"):
   generators.append(i)
   generation += d.generate
   available[i] = float(d.generate)
  if p.id == "capacitor":
   caps.append(i)
   cap_remaining[i] = minf(float(p.stored) / DT, float(Catalog.PARTS["capacitor"].rate))
 # Core, active cooling, processors. Stable position/order within each class.
 consumers.sort_custom(func(a: int, b: int) -> bool:
  var order := {"core":0, "cooler":1, "processor":2, "cluster":2}
  var pa: Dictionary = parts[a]
  var pb: Dictionary = parts[b]
  return order.get(pa.id, 3) < order.get(pb.id, 3) if order.get(pa.id, 3) != order.get(pb.id, 3) else a < b)
 for target in consumers:
  var d: Dictionary = Catalog.PARTS[parts[target].id]
  var req: float = d.request
  var got := _deliver(target, generators, available, req)
  if got < req and not caps.is_empty():
   var before := cap_remaining.duplicate()
   got += _deliver(target, caps, cap_remaining, req - got)
   for c in caps:
    var spent: float = (float(before[c]) - float(cap_remaining[c])) * DT
    parts[c].stored -= spent
    parts[c].flow -= spent / DT
  parts[target].power = got
  parts[target].ratio = got / req
  delivered += got
 # Charge only through a valid connected route, never with free global surplus.
 for cap in caps:
  var room: float = (float(Catalog.PARTS["capacitor"].storage) - float(parts[cap].stored)) / DT
  var charge := _deliver(cap, generators, available, minf(float(Catalog.PARTS["capacitor"].rate), room))
  parts[cap].stored += charge * DT
  parts[cap].flow += charge
 # Independent emergency trickle for a disconnected core, not routed to consumers.
 for p in parts:
  if p.id == "core" and p.power <= 0.001:
   p.power = minf(float(Catalog.PARTS["core"].reserve), float(Catalog.PARTS["core"].request))
   p.ratio = p.power / float(Catalog.PARTS["core"].request)

func thermal_factor(t: float) -> float:
 if t <= 65.0: return 1.0
 if t < 75.0: return lerpf(1.0, 0.85, (t - 65.0) / 10.0)
 if t < 85.0: return lerpf(0.85, 0.5, (t - 75.0) / 10.0)
 if t < 95.0: return lerpf(0.5, 0.12, (t - 85.0) / 10.0)
 return 0.02

func _heat() -> void:
 var next := heat.duplicate()
 for y in W:
  for x in W:
   var idx := index(x, y)
   var sum := 0.0
   for q in neighbors(x, y): sum += heat[index(q.x, q.y)] - heat[idx]
   next[idx] += DT * (0.16 * sum - 0.018 * (heat[idx] - 25.0))
 for p in parts:
  var d: Dictionary = Catalog.PARTS[p.id]
  var footprint: int = d.get("size", 1)
  var ratio: float = p.ratio if d.get("request", 0.0) > 0.0 else 1.0
  var added: float = d.get("heat", 0.0) * (0.15 + 0.85 * ratio)
  if d.has("capacity"):
   var load_ratio: float = p.load / float(d.capacity)
   added += 1.5 * load_ratio * load_ratio
  for yy in range(p.y, p.y + footprint):
   for xx in range(p.x, p.x + footprint): next[index(xx, yy)] += DT * added / (footprint * footprint)
  if d.has("cool"):
   var strength: float = d.cool * ratio
   for yy in range(maxi(0, p.y - 2), mini(W, p.y + 3)):
    for xx in range(maxi(0, p.x - 2), mini(W, p.x + 3)):
     var dist: int = absi(xx - p.x) + absi(yy - p.y)
     if dist <= 2:
      var idx := index(xx, yy)
      next[idx] -= DT * strength / (1.0 + dist * 1.5) * clampf((heat[idx] - 25.0) / 15.0, 0.0, 1.0)
 hottest = 25.0
 for i in next.size():
  next[i] = maxf(25.0, next[i])
  hottest = maxf(hottest, next[i])
 heat = next

func _compute() -> void:
 compute = 0.0
 for p in parts:
  var d: Dictionary = Catalog.PARTS[p.id]
  if d.has("compute"):
   var sz: int = d.get("size", 1)
   var temp := 25.0
   for yy in range(p.y, p.y + sz):
    for xx in range(p.x, p.x + sz): temp = maxf(temp, heat[index(xx, yy)])
   p.compute = float(d.compute) * p.ratio * thermal_factor(temp)
   compute += p.compute
 peak = maxf(peak, compute)

func _milestones() -> void:
 if level >= Catalog.GOALS.size(): return
 var goal: Dictionary = Catalog.GOALS[level]
 var core_on := false
 var processors_on := true
 for p in parts:
  if p.id == "core": core_on = p.ratio >= 0.7
  if p.id in ["processor", "cluster"] and p.ratio <= 0.001: processors_on = false
 var okay: bool = compute >= goal.target and core_on
 if level == 2: okay = okay and hottest < 85.0
 if level == 3: okay = okay and processors_on
 if level == 4: okay = okay and hottest < 95.0 and generation - delivered > 0.0
 sustain = sustain + DT if okay else 0.0
 if sustain >= float(goal.seconds):
  level += 1
  active_size = goal.size
  biomass_max = goal.biomass
  sustain = 0.0
  bloom_time = 2.0
  if level == Catalog.GOALS.size(): awakened = true

func tick() -> void:
 elapsed += DT
 bloom_time = maxf(0.0, bloom_time - DT)
 _power()
 _heat()
 _compute()
 _milestones()

func snapshot() -> Dictionary:
 return {"version":1, "parts":parts.duplicate(true), "heat":heat.duplicate(), "level":level, "active_size":active_size, "biomass_max":biomass_max, "peak":peak, "sustain":sustain, "awakened":awakened, "elapsed":elapsed}

func restore(data: Dictionary) -> bool:
 if data.get("version", -1) != 1 or not data.get("parts") is Array or not data.get("heat") is Array or data.heat.size() != W * W: return false
 var restored: Array[Dictionary] = []
 for p in data.parts:
  if not p is Dictionary or not Catalog.PARTS.has(p.get("id", "")): return false
  if int(p.get("x", -1)) < 0 or int(p.get("x", -1)) >= W or int(p.get("y", -1)) < 0 or int(p.get("y", -1)) >= W: return false
  restored.append(p.duplicate(true))
 parts = restored
 heat.clear()
 for h in data.heat: heat.append(clampf(float(h), 25.0, 500.0))
 level = clampi(int(data.get("level", 0)), 0, Catalog.GOALS.size())
 active_size = clampi(int(data.get("active_size", 10)), 10, W)
 biomass_max = maxi(70, int(data.get("biomass_max", 70)))
 peak = float(data.get("peak", 0.0))
 sustain = float(data.get("sustain", 0.0))
 awakened = bool(data.get("awakened", false))
 elapsed = float(data.get("elapsed", 0.0))
 _power()
 _compute()
 return true
