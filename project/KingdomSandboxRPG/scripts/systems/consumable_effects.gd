class_name ConsumableEffects
extends RefCounted

## Effect resolution stays independent from HUD and inventory presentation.
## The resolver returns the actual applied amount; zero means the use failed.
static func resolve(player: Player, definition: Dictionary) -> int:
	var effect: String = str(definition.get("use_effect", "")).to_lower()
	match effect:
		"heal":
			return player.heal(int(definition.get("use_value", 0)))
	return 0
