# ============================================================
#  Baut die portable EdenUpdater.exe (Windows, .NET Framework 4.x)
#  Aufruf:  .\build\build.ps1              -> Version aus VERSION
#           .\build\build.ps1 -Version v1.2.0
#  Ergebnis: dist\EdenUpdater.exe
# ============================================================
param([string]$Version)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $Version) { $Version = ([string](Get-Content (Join-Path $root "VERSION") -TotalCount 1)).Trim() }
$Version = $Version.TrimStart('v', 'V')
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version muss das Format x.y.z haben (ist: '$Version')." }
$asmVer = "$Version.0"

$dist = Join-Path $root "dist"
$obj  = Join-Path $root "obj"
New-Item -ItemType Directory -Path $dist, $obj -Force | Out-Null

# Versionsnummer in den Starter schreiben
$cs = Get-Content (Join-Path $root "launcher\EdenUpdaterHost.cs") -Raw -Encoding UTF8
$cs = $cs -replace 'Assembly(File)?Version\("[\d\.]+"\)', ('Assembly$1Version("' + $asmVer + '")')
$csFile = Join-Path $obj "EdenUpdaterHost.cs"
[IO.File]::WriteAllText($csFile, $cs, (New-Object Text.UTF8Encoding($true)))

# C#-Compiler von .NET Framework (bei jedem Windows dabei)
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $csc)) { throw "csc.exe nicht gefunden (.NET Framework 4.x fehlt?)." }

# Teile aus src\ zu einem Skript zusammensetzen (dist\EdenUpdater.ps1)
$merged = & (Join-Path $PSScriptRoot "merge.ps1")

$exe = Join-Path $dist "EdenUpdater.exe"
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    "/win32icon:$(Join-Path $root 'assets\EdenUpdater.ico')" `
    "/win32manifest:$(Join-Path $root 'launcher\app.manifest')" `
    "/resource:$merged,EdenUpdater.ps1" `
    "/out:$exe" $csFile
if ($LASTEXITCODE -ne 0) { throw "Kompilieren fehlgeschlagen (csc Exit $LASTEXITCODE)." }

Write-Host "Fertig: $exe (Version $Version)" -ForegroundColor Green
