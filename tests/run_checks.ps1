param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-CheckedGodot {
    param([string[]]$EngineArguments)
    $lines = & $Godot @EngineArguments 2>&1
    $engineExitCode = $LASTEXITCODE
    $outputText = $lines -join "`n"
    Write-Output $outputText
    if ($engineExitCode -ne 0 -or $outputText -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw 'Godot validation failed. Review the reported errors.'
    }
}

Invoke-CheckedGodot -EngineArguments @('--headless', '--path', $projectRoot, '--editor', '--quit')
Invoke-CheckedGodot -EngineArguments @('--headless', '--path', $projectRoot, '--quit-after', '180')
foreach ($suite in @('driving_smoke', 'weapon_smoke', 'combat_smoke', 'rival_smoke', 'rival_soak', 'match_smoke', 'audio_smoke', 'loadout_smoke', 'repair_smoke', 'impact_smoke')) {
    Invoke-CheckedGodot -EngineArguments @('--headless', '--path', $projectRoot, '--fixed-fps', '120', '--script', "res://tests/$suite.gd")
}
Write-Output 'All validation suites passed without Godot runtime errors.'
