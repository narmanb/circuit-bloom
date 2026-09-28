extends RefCounted
class_name BloomCatalog

const PARTS := {
 "core": {"name":"Core Socket", "category":"Support", "cost":0, "request":2.0, "reserve":2.0, "heat":0.4, "ports":"io", "description":"The living control chip. Keep its socket connected."},
 "gland": {"name":"Power Node", "category":"Power", "cost":8, "generate":40.0, "heat":2.0, "ports":"out", "description":"A compact power stage. Produces 40 power with little heat."},
 "reactor": {"name":"Flux Reactor", "category":"Power", "cost":15, "generate":80.0, "heat":8.0, "ports":"out", "unlock":1, "description":"Double the node's output and four times its heat. Cool this district."},
 "vein": {"name":"Copper Trace", "category":"Connections", "cost":1, "capacity":25.0, "ports":"io", "description":"A narrow live PCB route. Drag to lay connected traces."},
 "processor": {"name":"Processor Chip", "category":"Compute", "cost":6, "request":12.0, "compute":10.0, "heat":7.0, "ports":"in", "description":"Computes when powered; heat throttles its output."},
 "radiator": {"name":"Heat Sink", "category":"Cooling", "cost":5, "cool":3.2, "description":"Silver fins cool neighboring chips without using power."},
 "cooler": {"name":"Active Cooler", "category":"Cooling", "cost":7, "request":8.0, "cool":9.0, "ports":"in", "unlock":2, "description":"Powered cooling for nearby chips and traces."},
 "capacitor": {"name":"Capacitor Bank", "category":"Support", "cost":6, "storage":40.0, "rate":10.0, "ports":"io", "unlock":1, "description":"Stores spare power and briefly supports a brownout."},
 "bundle": {"name":"Bus Lane", "category":"Connections", "cost":2, "capacity":60.0, "ports":"io", "unlock":3, "description":"A thick parallel route with higher throughput."},
 "cluster": {"name":"Processor Array", "category":"Compute", "cost":14, "size":2, "request":35.0, "compute":45.0, "heat":25.0, "ports":"in", "unlock":3, "description":"Four chips in a 2×2 package. Powerful and hot."}
}
const ORDER := ["vein", "bundle", "gland", "reactor", "processor", "cluster", "radiator", "cooler", "capacitor"]
const GOALS := [
 {"name":"FIRST PULSE", "target":50.0, "seconds":0.2, "size":14, "biomass":160, "reward":"Capacitor Bank + Flux Reactor"},
 {"name":"STABLE CIRCUIT", "target":120.0, "seconds":15.0, "size":18, "biomass":360, "reward":"Active Cooler"},
 {"name":"LIVING NETWORK", "target":250.0, "seconds":20.0, "size":22, "biomass":620, "reward":"Bus Lane + Processor Array"},
 {"name":"SYNAPTIC GROWTH", "target":500.0, "seconds":30.0, "size":24, "biomass":950, "reward":"Full substrate"},
 {"name":"AWAKENING", "target":1000.0, "seconds":60.0, "size":24, "biomass":950, "reward":"Autonomous computation"}
]
