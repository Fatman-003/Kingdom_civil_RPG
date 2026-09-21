extends Node

signal game_started
signal scene_change_started(scene_path: String)
signal scene_changed(scene_path: String)
signal player_grid_position_changed(grid_position: Vector2i)
signal player_facing_changed(direction: String)
signal dialogue_requested(npc: Node)
signal dialogue_started(npc: Node)
signal dialogue_ended(npc: Node)
signal npc_interaction_requested(npc: Node)
signal npc_interaction_opened
signal npc_interaction_closed
signal gift_flow_requested(npc: Node)
signal inventory_opened
signal inventory_closed
signal monster_killed(monster_id: String)
signal item_added(item_id: String, amount: int)
signal npc_talked_to(npc_id: String)
