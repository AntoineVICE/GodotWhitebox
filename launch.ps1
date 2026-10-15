param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$Editor
)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    foreach ($name in @('godot', 'godot4')) {
        $candidate = Get-Command $name -ErrorAction SilentlyContinue
        if ($candidate) { $GodotPath = $candidate.Source; break }
    }
}
if (-not $GodotPath) {
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    $candidate = Get-ChildItem -LiteralPath $downloads -Filter 'Godot*' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*console.exe' -File } |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($candidate) { $GodotPath = $candidate.FullName }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Pass -GodotPath with the path to a Godot 4 standard executable, or set GODOT_BIN.'
}
$version = (& $GodotPath --version | Out-String).Trim()
if ($version -notmatch '^4\.' -or $version -match 'mono') { throw "Godot 4 standard required: $version" }
if ($Editor) { & $GodotPath --path $PSScriptRoot --editor }
else {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.godot\global_script_class_cache.cfg'))) {
        & $GodotPath --headless --path $PSScriptRoot --editor --quit
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    }
    $buildOutput = & $GodotPath --headless --path $PSScriptRoot --script res://scripts/build_story.gd 2>&1
    $buildOutput | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($buildOutput | Out-String) -match 'SCRIPT ERROR:|ERROR:') { throw 'Ink compilation failed. The game was not started with stale content.' }
    & $GodotPath --path $PSScriptRoot
}
exit $LASTEXITCODE
