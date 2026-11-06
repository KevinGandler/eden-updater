# ============================================================
#  Prueft EdenUpdater.ps1 ohne das Programm zu starten:
#   1. Syntax (PowerShell-Parser)
#   2. Sprachen: jede Sprache hat alle Texte, Platzhalter passen,
#      jeder Text aus dem XAML existiert
#   3. XAML: Hauptfenster, Dialoge und Theme-Karten lassen sich laden
#      (nur unter Windows, braucht WPF)
#  Exit-Code 0 = alles ok, 1 = Fehler
# ============================================================
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root "src\EdenUpdater.ps1"
if (-not (Test-Path $script)) { $script = Join-Path $root "src/EdenUpdater.ps1" }
$fail = 0
function Bad([string]$m) { Write-Host "  FEHLER: $m" -ForegroundColor Red; $script:fail++ }
function Ok([string]$m)  { Write-Host "  ok: $m" -ForegroundColor Green }

# ---------- 1) Syntax ----------
Write-Host "Syntax"
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errs)
if ($errs.Count) { foreach ($e in $errs) { Bad ("Zeile {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) } }
else { Ok "keine Parse-Fehler" }

function Get-AssignedString([string]$name) {
    $a = $ast.Find({
        param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $n.Left.VariablePath.UserPath -eq $name
    }, $true)
    if (-not $a) { return $null }
    return $a.Right.Expression.Value
}

# ---------- 2) Sprachen ----------
Write-Host "Sprachen"
$langAssign = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
    $n.Left.VariablePath.UserPath -eq 'LangData'
}, $true)
$tables = @{}
foreach ($kv in $langAssign.Right.Expression.KeyValuePairs) {
    $code = $kv.Item1.Value
    $text = $kv.Item2.PipelineElements[0].Expression.Value
    $h = @{}
    foreach ($line in ($text -split "\r?\n")) {
        $i = $line.IndexOf('=')
        if ($i -lt 1 -or $line.StartsWith('#')) { continue }
        $h[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1)
    }
    $tables[$code] = $h
}
$de = $tables['de']
foreach ($code in $tables.Keys) {
    $t = $tables[$code]
    $miss = @($de.Keys | Where-Object { -not $t.ContainsKey($_) })
    if ($miss.Count) { Bad "$code fehlt: $($miss -join ', ')" }
    foreach ($k in $de.Keys) {
        if (-not $t.ContainsKey($k)) { continue }
        $a = [regex]::Matches($de[$k], '\{\d').Count
        $b = [regex]::Matches($t[$k], '\{\d').Count
        if ($a -ne $b) { Bad "$code/$k Platzhalter passen nicht" }
    }
}
Ok "$($tables.Count) Sprachen, je $($de.Count) Texte"

$xaml = Get-AssignedString 'xaml'
$used = [regex]::Matches($xaml, 'L_(\w+)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing = @($used | Where-Object { -not $de.ContainsKey($_) })
if ($missing.Count) { Bad "Texte im XAML ohne Uebersetzung: $($missing -join ', ')" } else { Ok "alle $($used.Count) XAML-Texte vorhanden" }

# ---------- 3) XAML laden ----------
$isWin = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
if (-not $isWin) {
    Write-Host "XAML (uebersprungen, braucht Windows)"
} else {
    Write-Host "XAML"
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $res = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $tests = [ordered]@{
        "Hauptfenster"  = $xaml
        "Theme-Dialog"  = (Get-AssignedString 'themeDlgXaml').Replace('__RES__', $res)
        "Meldung"       = (Get-AssignedString 'msgDlgXaml').Replace('__RES__', $res)
        "Theme-Karte"   = (Get-AssignedString 'themeCardXaml').Replace('@@KEY@@', 'dark-cyan').Replace('@@BG@@', '#0F1419').Replace('@@PANEL@@', '#171D26').Replace('@@TEXT@@', '#E6EDF3').Replace('@@ACCENT@@', '#22D3EE').Replace('@@LABEL@@', 'Test')
    }
    foreach ($name in $tests.Keys) {
        try { [void][Windows.Markup.XamlReader]::Parse($tests[$name]); Ok $name }
        catch { Bad "$name : $($_.Exception.InnerException.Message) $($_.Exception.Message)" }
    }
}

Write-Host ""
if ($fail) { Write-Host "$fail Fehler." -ForegroundColor Red; exit 1 }
Write-Host "Alles ok." -ForegroundColor Green
exit 0
