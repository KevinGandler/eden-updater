$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root "src\XC3HD.ps1"
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errs)
if ($errs) { $errs | ForEach-Object { Write-Host $_.ToString() }; throw "Syntaxfehler" }
$src = Get-Content $file -Raw
# XAML pruefen
Add-Type -AssemblyName PresentationFramework
$x = [regex]::Match($src, "(?s)\`$xaml = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
[void][Windows.Markup.XamlReader]::Parse($x)
# Engine + C#-Helfer laden und Grundfunktionen testen
$cs = [regex]::Match($src, "(?s)\`$Xc3ImgSource = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
$Xc3ImgSource = $cs
$engine = [regex]::Match($src, "(?s)\`$Engine = \{(.*)\r?\n\}\s*# =====").Groups[1].Value
if (-not $engine) { throw "Engine nicht gefunden" }
$Root = Join-Path $env:TEMP "xc3hd-test"; New-Item -ItemType Directory $Root -Force | Out-Null
$S = $null
. ([scriptblock]::Create($engine))
$c = Get-Cfg; Save-Cfg $c; $c2 = Get-Cfg
if ($c2.MaxSize -ne 4096) { throw "Einstellungen" }
# Bild-Helfer testen
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 64, 64
for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 64; $x++) { $bmp.SetPixel($x, $y, [Drawing.Color]::FromArgb(200, $x * 4, $y * 4, 90)) } }
$png = Join-Path $Root "t.png"; $bmp.Save($png); $bmp.Dispose()
$hasA = [Xc3Img]::Prepare($png, "$Root\p.png", "$Root\a.png", 8)
if (-not $hasA) { throw "Alpha nicht erkannt" }
[Xc3Img]::Upscale("$Root\p.png", "$Root\up.png", 320, 320)
[Xc3Img]::Finish("$Root\up.png", "$Root\a.png", 64, 64, 8, 4, 128, 128, "$Root\f.png")
$f = [Drawing.Image]::FromFile("$Root\f.png"); if ($f.Width -ne 128) { throw "Finish" }; $f.Dispose()
Write-Host "Tests ok"
