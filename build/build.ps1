# Baut die portable XC3HD.exe (Windows, .NET Framework 4.x)
# Erwartet maptex\target\release\xc3_maptex.exe (wird eingebettet)
param([string]$Version)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Version) { $Version = ([string](Get-Content (Join-Path $root "VERSION") -TotalCount 1)).Trim() }
$Version = $Version.TrimStart('v', 'V')
$asmVer = "$Version.0"
$dist = Join-Path $root "dist"; $obj = Join-Path $root "obj"
New-Item -ItemType Directory -Path $dist, $obj -Force | Out-Null

$cs = Get-Content (Join-Path $root "launcher\XC3HDHost.cs") -Raw -Encoding UTF8
$cs = $cs -replace 'Assembly(File)?Version\("[\d\.]+"\)', ('Assembly$1Version("' + $asmVer + '")')
$csFile = Join-Path $obj "XC3HDHost.cs"
[IO.File]::WriteAllText($csFile, $cs, (New-Object Text.UTF8Encoding($true)))

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }

$maptex = Join-Path $root "maptex\target\release\xc3_maptex.exe"
$res = @("/resource:$(Join-Path $root 'src\XC3HD.ps1'),XC3HD.ps1")
if (Test-Path $maptex) { $res += "/resource:$maptex,xc3_maptex.exe" } else { Write-Warning "xc3_maptex.exe fehlt - wird nicht eingebettet" }

$exe = Join-Path $dist "XC3HD.exe"
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    "/win32icon:$(Join-Path $root 'assets\XC3HD.ico')" `
    "/win32manifest:$(Join-Path $root 'launcher\app.manifest')" `
    @res "/out:$exe" $csFile
if ($LASTEXITCODE -ne 0) { throw "Kompilieren fehlgeschlagen (csc Exit $LASTEXITCODE)." }
if (Test-Path $maptex) { Copy-Item $maptex $dist }
Write-Host "Fertig: $exe (Version $Version)"
