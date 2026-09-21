# Kingdom Sandbox RPG

## Project

Kingdom Sandbox RPG is a 2D sandbox RPG project. The current milestone establishes only the technical foundation; gameplay systems are intentionally deferred.

## Engine

Godot 4.x Standard build with GDScript.

## Current milestone

Foundation

## Architecture

```text
Main
├── WorldRoot    World and map content
├── EntityRoot   Player, NPC, and other runtime entities
├── EffectsRoot  Temporary visual effects
└── UIRoot       CanvasLayer for interface scenes
```

The registered Autoloads have deliberately narrow roles:

- `GameManager`: high-level global game state.
- `SceneManager`: validated scene transitions.
- `EventBus`: a small set of cross-system signals.
- `SaveManager`: temporary, testable persistence skeleton pending the dedicated save-system ticket.

## Run

From the workspace root, open the editor with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_godot.ps1
```

Run the project directly with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_godot.ps1 -Run
```

The same commands are available as **Run Godot Editor** and **Run Game** in VS Code's **Tasks: Run Task** menu.
