extends RefCounted
class_name BloomCatalog

# Costs are dollars. Internal IDs stay compact because they are saved in layouts.
const PARTS := {
 "core": {
  "name":"Control Building", "category":"Build", "cost":0, "size":2,
  "description":"Fixed control room and plant-services hub. It cannot be demolished."
 },
 "gland": {
  "name":"Boiler Unit", "category":"Build", "cost":650000, "generate":55.0, "heat":5.0,
  "ports":"out", "description":"Raises process steam for connected turbine generators."
 },
 "reactor": {
  "name":"High-Pressure Boiler", "category":"Build", "cost":1450000, "size":2,
  "generate":125.0, "heat":12.0, "ports":"out", "unlock":1,
  "description":"Large high-pressure boiler. High steam output with a serious thermal load."
 },
 "processor": {
  "name":"Turbine Generator", "category":"Build", "cost":900000, "size":2,
  "request":32.0, "compute":48.0, "heat":8.0, "ports":"in",
  "description":"Consumes steam and turns it into gross electrical output."
 },
 "cluster": {
  "name":"Turbine Block", "category":"Build", "cost":2600000, "size":3,
  "request":90.0, "compute":165.0, "heat":21.0, "ports":"in", "unlock":3,
  "description":"Integrated multi-stage turbine-generator train. Powerful, expensive and hot."
 },
 "radiator": {
  "name":"Cooling Tower", "category":"Build", "cost":520000, "size":2,
  "cool":7.0, "description":"Rejects heat from nearby plant equipment without consuming steam."
 },
 "cooler": {
  "name":"Condenser Train", "category":"Build", "cost":880000, "size":2,
  "cool":13.0, "unlock":2,
  "description":"High-capacity local cooling for dense turbine and boiler districts."
 },
 "vein": {
  "name":"Steam Pipe", "category":"Pipes", "cost":35000, "capacity":42.0,
  "ports":"io", "description":"Standard steam line. Drag across the yard to paint a route."
 },
 "bundle": {
  "name":"Main Steam Header", "category":"Pipes", "cost":85000, "capacity":125.0,
  "ports":"io", "unlock":2,
  "description":"Large header for feeding several turbines without choking the route."
 },
 "capacitor": {
  "name":"Steam Accumulator", "category":"Pipes", "cost":560000, "size":2,
  "storage":120.0, "rate":28.0, "ports":"io", "unlock":1,
  "description":"Stores surplus steam and releases it during short production shortfalls."
 },
 "pump": {
  "name":"Feedwater Pump", "category":"Pipes", "cost":280000,
  "cool":1.4, "boiler_boost":0.12,
  "description":"Improves adjacent boiler throughput and provides a small local cooling effect."
 },
 "transformer": {
  "name":"Step-Up Transformer", "category":"Power", "cost":720000, "size":2,
  "grid_capacity":135.0,
  "description":"Adds export capacity between the generators and the external grid."
 },
 "switchyard": {
  "name":"Switchyard Bay", "category":"Power", "cost":420000, "size":2,
  "grid_capacity":75.0,
  "description":"Adds grid interconnection capacity and makes additional generation useful."
 },
 "tank": {
  "name":"Water Tank", "category":"Logistics", "cost":390000, "size":2,
  "cool":2.0, "description":"Water reserve and modest passive cooling for nearby thermal equipment."
 }
}

const ORDER := [
 "gland", "reactor", "processor", "cluster", "radiator", "cooler",
 "vein", "bundle", "capacitor", "pump", "transformer", "switchyard", "tank"
]

const TAB_ITEMS := {
 "Build":["gland", "reactor", "processor", "cluster", "radiator", "cooler"],
 "Power":["transformer", "switchyard"],
 "Pipes":["vein", "bundle", "capacitor", "pump"],
 "Logistics":["tank"]
}

const GOALS := [
 {"name":"GRID SYNC", "target":40.0, "seconds":4.0, "size":14, "funds":1100000, "reward":"High-Pressure Boiler + Steam Accumulator"},
 {"name":"STABLE EXPORT", "target":90.0, "seconds":10.0, "size":17, "funds":1800000, "reward":"Main Steam Header + Condenser Train"},
 {"name":"SECOND TRAIN", "target":180.0, "seconds":14.0, "size":20, "funds":2600000, "reward":"Larger central yard"},
 {"name":"PLANT EXPANSION", "target":320.0, "seconds":20.0, "size":22, "funds":3800000, "reward":"Turbine Block"},
 {"name":"FULL LOAD", "target":500.0, "seconds":30.0, "size":24, "funds":5000000, "reward":"Full-site free build"}
]
