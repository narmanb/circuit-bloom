extends RefCounted
class_name BloomCatalog

# Internal IDs are intentionally preserved from the motherboard prototype so the
# simulation and regression tests can be reused while the theme is prototyped.
const PARTS := {
 "core": {"name":"Plant Control", "category":"Support", "cost":0, "request":2.0, "reserve":2.0, "heat":0.4, "ports":"io", "description":"Fixed plant control and auxiliary-service hub. Keep it tied into the process network."},
 "gland": {"name":"Boiler Unit", "category":"Power", "cost":8, "generate":40.0, "heat":2.0, "ports":"out", "description":"Basic boiler producing 40 t/h of usable process steam."},
 "reactor": {"name":"High-Pressure Boiler", "category":"Power", "cost":15, "generate":80.0, "heat":8.0, "ports":"out", "unlock":1, "description":"High-output boiler. Twice the steam, but much more thermal load."},
 "vein": {"name":"Steam Pipe", "category":"Connections", "cost":1, "capacity":25.0, "ports":"io", "description":"Standard process pipe. Drag to route steam between plant equipment."},
 "processor": {"name":"Turbine Generator", "category":"Compute", "cost":6, "request":12.0, "compute":10.0, "heat":7.0, "ports":"in", "description":"Consumes process steam and converts it into electrical output."},
 "radiator": {"name":"Cooling Tower", "category":"Cooling", "cost":5, "cool":3.2, "description":"Passive heat rejection for nearby equipment."},
 "cooler": {"name":"Condenser Train", "category":"Cooling", "cost":7, "request":8.0, "cool":9.0, "ports":"in", "unlock":2, "description":"Active process cooling. Uses service flow to pull down local temperatures."},
 "capacitor": {"name":"Steam Accumulator", "category":"Support", "cost":6, "storage":40.0, "rate":10.0, "ports":"io", "unlock":1, "description":"Stores excess steam and discharges it when turbine demand spikes."},
 "bundle": {"name":"Main Steam Header", "category":"Connections", "cost":2, "capacity":60.0, "ports":"io", "unlock":3, "description":"Large high-throughput steam header for feeding several generation trains."},
 "cluster": {"name":"Turbine Block", "category":"Compute", "cost":14, "size":2, "request":35.0, "compute":45.0, "heat":25.0, "ports":"in", "unlock":3, "description":"Integrated 2×2 turbine-generator block. Efficient output, heavy steam demand and heat."}
}

const ORDER := ["vein", "bundle", "gland", "reactor", "processor", "cluster", "radiator", "cooler", "capacitor"]

const GOALS := [
 {"name":"GRID SYNC", "target":30.0, "seconds":3.0, "size":14, "biomass":160, "reward":"Steam Accumulator + High-Pressure Boiler"},
 {"name":"STABLE OUTPUT", "target":75.0, "seconds":8.0, "size":16, "biomass":320, "reward":"Condenser Train"},
 {"name":"SECOND TRAIN", "target":150.0, "seconds":12.0, "size":18, "biomass":520, "reward":"Main Steam Header + Turbine Block"},
 {"name":"PLANT EXPANSION", "target":300.0, "seconds":20.0, "size":20, "biomass":800, "reward":"Full central yard"},
 {"name":"FULL LOAD", "target":500.0, "seconds":30.0, "size":20, "biomass":800, "reward":"Free-build operations"}
]
