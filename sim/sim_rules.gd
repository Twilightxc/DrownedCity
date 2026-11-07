class_name SimRules
extends Resource
## SimCore tunables for the base economy. Instances live in data/sim/*.tres.

@export_group("New game")
@export var starting_survivors: PackedStringArray = PackedStringArray(["Mali", "Somchai", "Rosa"])
@export var starting_stock: Dictionary[String, float] = {"food": 8.0, "water": 12.0, "materials": 6.0, "ammo": 30.0, "medicine": 2.0}

@export_group("Daily upkeep (GDD §11)")
@export var food_per_survivor: float = 1.0
@export var water_per_survivor: float = 1.5
@export var materials_per_day: float = 1.0

@export_group("Shortage penalties, per day short (hunger and thirst themselves: data/sim/needs.json)")
@export var shortage_morale_loss: float = 15.0

@export_group("Spike harness")
@export var scavenge_haul: Dictionary[String, float] = {"food": 3.0, "water": 4.0, "materials": 2.0, "ammo": 10.0}
