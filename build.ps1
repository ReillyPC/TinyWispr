# Builds build\tinywispr.exe with Zig's C compiler.
#   .\build.ps1            build only
#   .\build.ps1 -Install   build, copy to %LOCALAPPDATA%\Programs\TinyWispr, start at login, and launch
#   .\build.ps1 -Test      also build build\tinywispr-test.exe (accepts simulated keys, TW_FAKE=<text> skips OpenAI)
param([switch]$Install, [switch]$Test)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$zig = (Get-Command zig -ErrorAction SilentlyContinue).Source
if (-not $zig) {
    $zig = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter zig.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $zig) { throw 'Zig not found. Install it with: winget install zig.zig' }

New-Item -ItemType Directory -Force build | Out-Null
function Compile($out, $defs) {
    & $zig cc -target x86_64-windows-gnu -Os -s -std=c11 -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers `
        @defs '-Wl,--subsystem,windows' -o $out src\tinywispr.c `
        -luser32 -lgdi32 -lshell32 -lwinmm -lwinhttp -ladvapi32 -ldwmapi
    if ($LASTEXITCODE) { throw "Build failed ($LASTEXITCODE)" }
}
Compile 'build\tinywispr.exe' @()
if ($Test) { Compile 'build\tinywispr-test.exe' @('-DTW_TEST') }
Remove-Item build\*.pdb -ErrorAction SilentlyContinue
"Built build\tinywispr.exe ($([math]::Round((Get-Item build\tinywispr.exe).Length / 1KB)) KB)"

if ($Install) {
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\TinyWispr'
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-Process tinywispr, localwispr -ErrorAction SilentlyContinue | Stop-Process -Force
    # one-time cleanup from when the app was called LocalWispr (settings move on first start)
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name LocalWispr -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:LOCALAPPDATA 'Programs\LocalWispr') -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    Copy-Item build\tinywispr.exe $dest -Force
    $exe = Join-Path $dest 'tinywispr.exe'
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name TinyWispr -Value "`"$exe`""
    Start-Process $exe
    "Installed to $exe and started (runs at login)."
}
