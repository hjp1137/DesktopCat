param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$engineDir = Join-Path $env:LOCALAPPDATA 'DesktopCat\source-engine'
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null
$engine = Join-Path $engineDir 'SourceGodot.exe'
# The renamed executable has no matching PCK; --path always reads source.
Copy-Item -LiteralPath (Join-Path $repo 'build\DesktopCat.exe') -Destination $engine -Force
if (Test-Path -LiteralPath (Join-Path $engineDir 'SourceGodot.pck')) {
    throw 'Source engine directory contains SourceGodot.pck; remove that package before launching.'
}
& $engine --path $repo @GodotArgs
exit $LASTEXITCODE
