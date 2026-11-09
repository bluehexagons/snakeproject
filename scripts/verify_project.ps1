# Native Windows entry point; no Bash or WSL required.
[CmdletBinding()]
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'godot' }),
    [int]$Timeout = 120,
    [switch]$Rendered
)

$ErrorActionPreference = 'Stop'
$pythonCommand = Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1
$runnerArguments = @("$PSScriptRoot/verify_project.py", '--godot', $Godot, '--timeout', $Timeout)
if ($Rendered) { $runnerArguments += '--rendered' }
& $pythonCommand.Source @runnerArguments
exit $LASTEXITCODE
