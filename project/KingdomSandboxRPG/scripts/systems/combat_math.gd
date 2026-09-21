class_name CombatMath
extends RefCounted


static func resolve_physical_damage(incoming_attack: int, defense: int) -> int:
	if incoming_attack <= 0:
		return 0
	return maxi(incoming_attack - defense, 1)
