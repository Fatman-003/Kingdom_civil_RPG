class_name GridUtils
extends RefCounted

const CELL_SIZE: int = 32
const CELL_CENTER_OFFSET: Vector2 = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)


static func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position * CELL_SIZE) + CELL_CENTER_OFFSET


static func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / CELL_SIZE),
		floori(world_position.y / CELL_SIZE)
	)
