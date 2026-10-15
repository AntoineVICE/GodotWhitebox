param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$Graphical
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = Join-Path $PSScriptRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
# Documents contains unrelated projects/media. Import only an explicit allowlist
# into our own ignored cache; never add .gdignore files to the user's folders.
$verifyRoot = Join-Path $projectRoot '.godot\whitebox_verify'
New-Item -ItemType Directory -Path $verifyRoot -Force | Out-Null
foreach ($item in @('project.godot','export_presets.cfg','THIRD_PARTY_NOTICES.md','scripts','scenes','data','story','addons','tools','tests')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $item) -Destination $verifyRoot -Recurse -Force
}
function Invoke-Verified([string]$Name, [string[]]$EngineArgs) {
    $log = Join-Path $artifactRoot ($Name + '.log')
    & $GodotPath @EngineArgs --log-file $log
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "$Name returned $code; see $log" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:|FAIL:' -Quiet) {
        throw "$Name logged an error despite exit code zero; see $log"
    }
}
& $GodotPath --version
if ($LASTEXITCODE -ne 0) { throw 'Cannot query Godot version.' }
Invoke-Verified 'editor_import' @('--headless','--path',$verifyRoot,'--editor','--quit')
Invoke-Verified 'ink_compile' @('--headless','--path',$projectRoot,'--script','res://scripts/build_story.gd')
Copy-Item -LiteralPath (Join-Path $projectRoot 'story\compiled') -Destination (Join-Path $verifyRoot 'story') -Recurse -Force
Invoke-Verified 'core' @('--headless','--path',$projectRoot,'--script','res://tests/test_runner.gd')
Invoke-Verified 'ink_authoring' @('--headless','--path',$projectRoot,'--script','res://tests/ink_authoring_tests.gd')
Invoke-Verified 'startup' @('--headless','--path',$projectRoot,'--quit-after','120')
$pack = Join-Path $verifyRoot 'whitebox_validation.pck'
Invoke-Verified 'export_pack' @('--headless','--path',$verifyRoot,'--export-pack','Windows Desktop',$pack)
Invoke-Verified 'pack_startup' @('--headless','--path',$verifyRoot,'--main-pack',$pack,'--quit-after','120')
if ($Graphical) {
    Invoke-Verified 'gui' @('--path',$projectRoot,'--position','60,60','--script','res://tests/gui_runner.gd')
}
Write-Output 'All requested checks passed (exit codes and engine logs inspected).'
