extends RefCounted
class_name BloomCatalog

const PARTS := {
 "core": {"name":"Bio Core", "category":"Support", "cost":0, "request":2.0, "reserve":2.0, "heat":0.4, "ports":"io", "description":"The living control organ. Keep it connected."},
 "gland": {"name":"Energy Gland", "category":"Power", "cost":8, "generate":40.0, "heat":2.0, "ports":"out", "description":"Produces power and a little heat."},
 "vein": {"name":"Conductive Tissue", "category":"Connections", "cost":1, "capacity":25.0, "ports":"io", "description":"A low-capacity living conductor. Drag to paint."},
 "processor": {"name":"Processor Cell", "category":"Compute", "cost":6, "request":12.0, "compute":10.0, "heat":7.0, "ports":"in", "description":"Computes when powered; heat throttles it."},
 "radiator": {"name":"Passive Radiator", "category":"Cooling", "cost":5, "cool":3.2, "description":"Local cooling without a power draw."},
 "cooler": {"name":"Cooling Gland", "category":"Cooling", "cost":7, "request":8.0, "cool":9.0, "ports":"in", "unlock":2, "description":"Power-hungry cooling across nearby tissue."},
 "capacitor": {"name":"Capacitor Cell", "category":"Support", "cost":6, "storage":40.0, "rate":10.0, "ports":"io", "unlock":1, "description":"Stores surplus power and softens brownouts."},
 "bundle": {"name":"Neural Bundle", "category":"Connections", "cost":2, "capacity":60.0, "ports":"io", "unlock":3, "description":"A thicker nerve with greater throughput."},
 "cluster": {"name":"Processor Cluster", "category":"Compute", "cost":14, "size":2, "request":35.0, "compute":45.0, "heat":25.0, "ports":"in", "unlock":3, "description":"Four synchronized cells. Powerful, hot, and 2×2."}
}
const ORDER := ["vein", "bundle", "gland", "processor", "cluster", "radiator", "cooler", "capacitor"]
const GOALS := [
 {"name":"FIRST PULSE", "target":50.0, "seconds":0.2, "size":14, "biomass":160, "reward":"Capacitor Cell"},
 {"name":"STABLE CIRCUIT", "target":120.0, "seconds":15.0, "size":18, "biomass":280, "reward":"Cooling Gland"},
 {"name":"LIVING NETWORK", "target":250.0, "seconds":20.0, "size":22, "biomass":500, "reward":"Neural Bundle + Processor Cluster"},
 {"name":"SYNAPTIC GROWTH", "target":500.0, "seconds":30.0, "size":24, "biomass":950, "reward":"Full substrate"},
 {"name":"AWAKENING", "target":1000.0, "seconds":60.0, "size":24, "biomass":950, "reward":"Autonomous computation"}
]
