# Quick items (TICKET-022)

`Player` owns the four quick-slot assignments and the consumable cooldown-group
clock. `InventorySystem` remains authoritative for item definitions and stack
quantities. A slot stores only an `item_id`, so assignment never duplicates or
removes inventory ownership. `GameManager.quick_item_assignments` keeps those
references through encounter scene restart; application save/load is intentionally
out of scope.

`ConsumableEffects` resolves item data (`use_effect`, `use_value`, `cooldown`,
`cooldown_group`). Only `heal` is implemented. The Player `heal()` API clamps to
runtime max HP, rejects defeated/full-health use, emits the normal HP signal and
adds a short cosmetic feedback number. Inventory UI and the HUD never write
`current_hp` directly.

Inventory assignment is keyboard-first: select a consumable, press Enter/Space,
choose 1–4, then confirm. `C` clears the selected slot while the assignment prompt
is open. The same item may be assigned to multiple slots, but all items in the
`consumable` cooldown group share one timer. An empty stack retains its item ID;
the HUD shows `OUT_OF_STOCK` and automatically becomes ready when inventory gains
that item again.

The gameplay input path checks `quick_item_1` through `quick_item_4` only when the
Player is stationary and no dialogue, interaction menu or Character Panel is open.
The HUD only renders `EMPTY`, `READY`, `COOLDOWN`, `OUT_OF_STOCK` and `UNAVAILABLE`;
it does not decide whether a use succeeds. Quest rewards, loot pickups and future
shops can call `InventorySystem.add_item()` normally and the HUD updates from the
shared quantity source.
