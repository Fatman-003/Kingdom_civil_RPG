# Architecture Rules

## ARCH-001 — System separation

Do not turn `GameManager` into a god object. Dedicated gameplay systems should remain separate.

## ARCH-002 — Data-driven gameplay

Future item definitions, skills, character templates, professions, and faction definitions should not be hardcoded across gameplay scripts. Prefer Godot Resources or structured data where appropriate. Later tickets will choose the exact formats.

## ARCH-003 — Event decoupling

Use signals or `EventBus` when systems benefit from decoupling. Do not route every interaction through `EventBus`.

## ARCH-004 — Scene ownership

A scene owns its local behavior. Avoid unnecessary absolute references to unrelated scenes.

## ARCH-005 — Scope discipline

Do not implement features that are not requested by the active ticket.

## ARCH-006 — Active vs simulated NPC

Future architecture must distinguish between:

- **Active NPC:** currently loaded in a scene, with a node, sprite, animation, pathfinding, and runtime behavior.
- **Simulated NPC:** outside the current map and represented primarily as lightweight data.

Do not implement this system yet. This distinction is required because the final game may contain approximately 100–200 NPCs.

## ARCH-007 — Performance

Do not process world simulation for every NPC every frame. Future world simulation should use scheduled or event-based updates. Do not implement that simulation in this milestone.
