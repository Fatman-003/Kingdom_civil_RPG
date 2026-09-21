# Local Development Environment

## Workspace

- Workspace root: `D:\game\kingdom_rpg`
- Workspace drive: `D:`
- Game project directory: `D:\game\kingdom_rpg\project\KingdomSandboxRPG`
- Build output directory: `D:\game\kingdom_rpg\builds`

The Godot project is initialized at this path. Its main scene is `scenes\core\main.tscn`.

## Godot

- Version: Godot 4.7.2 stable, official Standard/GDScript x86_64 build
- Executable: `D:\game\kingdom_rpg\tools\godot\Godot_v4.7.2-stable_win64.exe`
- Self-contained mode: Enabled by `D:\game\kingdom_rpg\tools\godot\_sc_`
- Editor data, settings, and cache: `D:\game\kingdom_rpg\tools\godot\editor_data`
- Runtime temporary data: `D:\game\kingdom_rpg\temp\runtime`

The archive was downloaded through Godot's official download endpoint. Its SHA-256 digest matched the official GitHub release metadata:

`731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`

Both extracted executables have valid Windows Authenticode signatures from `Prehensile Tales B.V.`. The downloaded archive was removed after successful extraction and verification.

## Launching Godot

From the workspace root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_godot.ps1
```

The helper resolves every path from its own location and gives only the launched Godot process workspace-local `TEMP` and `TMP` values. It does not modify permanent user or system environment variables. It opens `project\KingdomSandboxRPG` directly in the editor.

To verify the local executable without opening the editor UI, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_godot.ps1 -Version
```

To run the main scene directly, add `-Run` to the helper command. In VS Code, use **Tasks: Run Task** and select **Run Godot Editor** or **Run Game**.

## System Scope

No global `PATH` entry, registry value, system-wide software installation, global VS Code setting, or permanent `TEMP`/`TMP` value was changed.

VS Code and the Codex extension remain installed in their existing Windows locations and are outside this workspace bootstrap.

Godot self-contained mode keeps editor data, settings, and editor cache beside the executable. Windows itself, the existing VS Code/Codex installations, certificate services, and future game `user://` save data may still use Windows-managed locations on drive C:. Exported projects do not inherit editor self-contained mode.
