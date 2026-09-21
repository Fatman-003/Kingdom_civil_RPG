class_name LootPickup
extends Node2D
@export var item_id: String = ""
@export var amount: int = 1
var grid_position: Vector2i
func setup(new_item_id: String, new_amount: int, cell: Vector2i) -> void:
	item_id = new_item_id
	amount = new_amount
	grid_position = cell
	position = GridUtils.grid_to_world(cell)
