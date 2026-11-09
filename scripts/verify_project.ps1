# Native Windows entry point; no Bash or WSL required.
[CmdletBinding()]
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { 'godot' }),
    [int]$Timeout = 120,
    [switch]$Rendered
)

$runnerArguments = @("$PSScriptRoot/verify_project.py", '--godot', $Godot, '--timeout', $Timeout)
if ($Rendered) { $runnerArguments += '--rendered' }
& python @runnerArguments
exit $LASTEXITCODE
