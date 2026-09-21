# Presentation foundation (TICKET-021)

## Shared UI

`FantasyTheme.shared()` caches one Godot Theme. Slate/teal panels, jade selection,
warm paper text, restrained brass outlines and rose damage/negative gauges are
shared across the HUD, Character Panel, dialogue, interaction and quest tracker.
`FantasyTheme.select()` styles the controllers' existing keyboard selection;
it deliberately does not introduce a second native button-focus cursor.

Character tabs share a header. Equipment keeps slots, preview/stats and details
in three columns. Skill prerequisites remain visible in selected-node details.
No relationship thresholds or choice effects are exposed.

Canvas layers, low to high:

| Layer | Content |
| --- | --- |
| 1 | Combat HUD, HP, action slots, reserved quick-item slots |
| 2 | Quest tracker |
| 3 | Debug HUD (F3 toggles only this layer's Control) |
| 10 | Character Panel |
| 20 | Dialogue, interaction and gift picker |
| 30 | Defeat confirmation |

`ActionIcon` draws original placeholders and cooldown darkening. It can later
be replaced with texture artwork without changing action/cooldown ownership.
Quick slots are visual placeholders only. No quick-item behavior was added.

## Actor visuals

`ActorPresentation` owns only the existing Visual child's local transform/tint.
Its simple priority is Death > Hurt > Attack/Skill > Move > Idle. Gameplay calls
`play()` or reports locomotion through `set_moving()`; no gameplay action awaits
an animation. Grid position, reservations, hit timing, HP and cooldowns remain
owned by the existing gameplay systems. Shadows/collisions stay outside Visual.

Player and monster attacks use a small directional lunge, skills a jade pulse,
hurt a short recoil/flash, and death a collapse. A dying monster leaves a short
cosmetic copy while its actual death/loot/occupancy flow completes immediately.
The non-hostile dummy uses the same hurt presentation, without XP or loot.

Floating damage and pickup labels are attached outside entity collections and
free themselves after 0.65 seconds. Death copies last 0.24 seconds. Scene removal
also removes these effects. Text/tint parameters permit future presentation
variants without adding critical-hit rules. Future sprites can replace `_render`
without changing combat logic.

## Validation

Run from the Godot project directory, replacing `godot` with the local executable:

```text
godot --headless --path . --script tests/presentation_smoke_test.gd
godot --path . --script tests/presentation_smoke_test.gd -- --capture --capture-dir=<absolute-output-directory>
godot --headless --path . --script tests/presentation_smoke_test.gd -- --soak
```

The presentation test checks viewport-dispatched I/Tab/K/C/J/Escape input,
modal movement locks, all five panel layouts, dialogue choices/gift cancellation,
HP/cooldowns, dummy feedback, animation priority and immediate death occupancy.
Capture mode produces actual 1280x720 rendered screenshots. Soak mode runs ten
minutes of repeated movement/combat/panel/death/scene teardown cycles and reports
node counts. This is automated runtime coverage, not a human ten-minute playtest
or a GPU performance benchmark.

Existing movement, NPC occupancy, inventory, overworld, quest, progression and
Luck/loot smoke tests remain relevant. The open-floor movement test now freezes
NPC wandering so random crossings cannot invalidate its movement-only route;
the separate NPC test still exercises wandering/reservations.

Validated with Godot 4.7.2: parser, rendered presentation/keyboard smoke test and
the seven relevant existing smoke tests passed. The 600-second automated soak
passed, with 269 nodes at each periodic checkpoint through 75 encounter restarts.
The Windows sandbox headless runs emitted a system certificate-store read error;
the rendered run had no such error and no game script/runtime errors. Screenshots
were reviewed for the HUD, five tabs, dialogue/choices, gift picker and defeat UI.
