# ============================================================
#  Setzt die Teile aus src\ (01-..., 02-..., in Namensreihenfolge) zu einem
#  einzigen Skript zusammen:  dist\EdenUpdater.ps1
#  Dieses eine Skript wird getestet, in die EXE eingebettet und fuer die
#  Screenshots gestartet. Bearbeitet werden nur die Teile in src\.
#  Aufruf:  .\build\merge.ps1        (gibt den Pfad des fertigen Skripts zurueck)
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "src"
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Path $dist -Force | Out-Null

$parts = @(Get-ChildItem -LiteralPath $src -Filter "*.ps1" -File | Sort-Object Name)
if (-not $parts.Count) { throw "Keine Teile in $src gefunden." }
$sb = New-Object System.Text.StringBuilder
foreach ($p in $parts) {
    # ReadAllText entfernt ein BOM am Dateianfang; jeder Teil endet mit genau einem Zeilenumbruch
    $t = [IO.File]::ReadAllText($p.FullName, [Text.Encoding]::UTF8)
    if (-not $t.EndsWith("`n")) { $t += "`n" }
    [void]$sb.Append($t)
}
$out = Join-Path $dist "EdenUpdater.ps1"
[IO.File]::WriteAllText($out, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
Write-Host ("Zusammengesetzt: {0} Teile -> {1}" -f $parts.Count, $out)
return $out
