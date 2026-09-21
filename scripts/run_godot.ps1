[CmdletBinding()]
param(
    [switch]$Version,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$godotDirectory = Join-Path $workspaceRoot 'tools\godot'
$projectDirectory = Join-Path $workspaceRoot 'project\KingdomSandboxRPG'
$projectFile = Join-Path $projectDirectory 'project.godot'
$runtimeDirectory = Join-Path $workspaceRoot 'temp\runtime'

New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null

$godotExecutable = Get-ChildItem -LiteralPath $godotDirectory -File -Filter 'Godot_v*-stable_win64.exe' |
    Sort-Object -Property Name -Descending |
    Select-Object -First 1

if (-not $godotExecutable) {
    throw "Workspace-local Godot executable not found in: $godotDirectory"
}

# ProcessStartInfo lets TEMP/TMP apply only to Godot without changing the user or
# machine environment (or even the environment of this PowerShell process).
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $godotExecutable.FullName
$startInfo.WorkingDirectory = $workspaceRoot
$startInfo.UseShellExecute = $false
$startInfo.EnvironmentVariables['TEMP'] = $runtimeDirectory
$startInfo.EnvironmentVariables['TMP'] = $runtimeDirectory

if ($Version) {
    $startInfo.Arguments = '--version'
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($standardOutput) {
        Write-Output $standardOutput.TrimEnd()
    }
    if ($standardError) {
        Write-Error $standardError.TrimEnd()
    }
    exit $process.ExitCode
}

if ($Run) {
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
        throw "Cannot run the game because project.godot was not found: $projectFile"
    }
    $startInfo.Arguments = "--path `"$projectDirectory`""
} elseif (Test-Path -LiteralPath $projectFile -PathType Leaf) {
    $startInfo.Arguments = "--editor --path `"$projectDirectory`""
}

[System.Diagnostics.Process]::Start($startInfo) | Out-Null
