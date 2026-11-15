# ============================================================
#  Zeitmessung fuer den automatischen Test.
#  Wird vom Updater im Screenshot-Modus eingelesen, wenn EDEN_UPDATER_SNAPSHOT_PERF auf diese Datei zeigt
#  (siehe Start-Snapshots in src\14-screenshot-modus.ps1). Misst Startabschnitte, Seitenwechsel und
#  Listenaufbau, schreibt perf.txt in den Zielordner und beendet das Programm.
#  Gemessen wird jeweils, bis das Fenster fertig gezeichnet hat (Dispatcher im Leerlauf).
# ============================================================
function Wait-PerfIdle { $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ContextIdle) }
function Measure-PerfStep([string]$name, [scriptblock]$action) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $action
    $own = $sw.Elapsed.TotalMilliseconds
    Wait-PerfIdle
    [void]$script:PerfSteps.Add(@($name, $sw.Elapsed.TotalMilliseconds, $own))
}
function Invoke-PerfClick([string]$btn) {
    $ui[$btn].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
}

$script:PerfSteps = New-Object System.Collections.ArrayList
$info = New-Object System.Collections.ArrayList

# groessere Bibliothek: 40 Spiele
$base = @($script:Games)
$all = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt 40; $i++) {
    $n = $base[$i % $base.Count].Name + $(if ($i -ge $base.Count) { " " + [int]($i / $base.Count + 1) } else { "" })
    $g = [pscustomobject]@{ Name = $n; Path = ""; Info = "NSP  ·  4,2 GB"; Initial = $n.Substring(0, 1); Icon = ""; IconImg = $null }
    Add-GameTileProps $g
    $g | Add-Member -NotePropertyName Tid -NotePropertyValue ("0100000000{0:X2}0000" -f ($i + 1)) -Force
    $g | Add-Member -NotePropertyName IsFav -NotePropertyValue ($i -eq 2) -Force
    [void]$all.Add($g)
}
$script:Games = $all.ToArray()
Set-GameLaunchProps
Wait-PerfIdle
Measure-PerfStep "Liste Versionen aufbauen" { Update-List }
Measure-PerfStep "Liste Spiele aufbauen (unsichtbar)" { Update-GameList }

# Seitenwechsel ueber echte Klicks auf die Leiste
$navBtn = [ordered]@{ games = "BtnNavGames"; mods = "BtnNavMods"; content = "BtnNavContent"; saves = "BtnNavSaves"; firmware = "BtnNavFw"; settings = "BtnNavSet"; notes = "BtnNavNotes"; versions = "BtnNavVer" }
foreach ($round in 1..3) {
    foreach ($pg in $navBtn.Keys) {
        $script:PerfPg = $navBtn[$pg]
        Measure-PerfStep ("Seite " + $pg + " #" + $round) { Invoke-PerfClick $script:PerfPg }
        if ($script:CurrentPage -ne $pg) { throw "Klick auf $($navBtn[$pg]) hat nicht zur Seite $pg gefuehrt (ist: $($script:CurrentPage))" }
    }
}

Set-Page "games"
Measure-PerfStep "Liste Spiele aufbauen (sichtbar)" { Update-GameList }
$pick = @($ui.ListGames.ItemsSource)[3]
Measure-PerfStep "Detailansicht oeffnen (erstes Mal)" { $ui.ListGames.SelectedItem = $pick; Show-GameDetail $pick $false }
Measure-PerfStep "Detailansicht schliessen" { Hide-GameDetail }
$pick = @($ui.ListGames.ItemsSource)[5]
Measure-PerfStep "Detailansicht oeffnen" { $ui.ListGames.SelectedItem = $pick; Show-GameDetail $pick $false }
Hide-GameDetail

# Seiten Mods / Updates+DLC / Spieldaten so oeffnen wie im Betrieb (im Screenshot-Modus laesst Set-Page das aus)
Set-Page "mods";    Measure-PerfStep "Liste Mods neu aufbauen" { Update-ModGames }
Set-Page "content"; Measure-PerfStep "Liste Inhalte neu aufbauen" { Update-ContentGames }
Set-Page "saves";   Measure-PerfStep "Liste Spielstaende neu aufbauen" { Update-SaveGames }
Set-Page "versions"; Wait-PerfIdle
foreach ($round in 1..2) {
    Measure-PerfStep ("Mods oeffnen wie im Betrieb #" + $round)        { Invoke-PerfClick "BtnNavMods";    Open-ModsTab }
    if ($round -eq 2) {
        $c = $ui.ListModGames.ItemContainerGenerator.ContainerFromIndex(0)
        $r = if ($c) { $c.Template.FindName("root", $c) } else { $null }
        # kurz nach dem Oeffnen laeuft die Einblend-Animation noch: Deckkraft des ersten Eintrags liegt dann unter 1
        [void]$info.Add(("Mods erneut geoeffnet: Deckkraft des ersten Eintrags kurz danach = {0:F2} (unter 1 = blendet neu ein), Eintraege = {1}" -f $(if ($r) { $r.Opacity } else { -1 }), $ui.ListModGames.Items.Count))
    }
    Measure-PerfStep ("Updates+DLC oeffnen wie im Betrieb #" + $round) { Invoke-PerfClick "BtnNavContent"; Open-ContentTab }
    Measure-PerfStep ("Spieldaten oeffnen wie im Betrieb #" + $round)  { Invoke-PerfClick "BtnNavSaves";   Open-SavesTab }
    Measure-PerfStep ("Versionen oeffnen #" + $round)                  { Invoke-PerfClick "BtnNavVer" }
}

Measure-PerfStep "Theme wechseln (erstes Mal)" { Set-ThemeById "light" }
Measure-PerfStep "Theme wechseln" { Set-ThemeById "dark-cyan" }
Measure-PerfStep "Hintergrund-Thread starten" {
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = "MTA"; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($workerLib.ToString() + "`n1")
    $script:PerfWorker = @{ PS = $ps; RS = $rs; H = $ps.BeginInvoke() }
}
Measure-PerfStep "Meldungsfenster bauen (erstes Mal)" { $d = New-SnapDialog; $d.Close() }
Measure-PerfStep "Meldungsfenster bauen" { $d = New-SnapDialog; $d.Close() }
Measure-PerfStep "Theme-Fenster bauen" { $d = New-SnapThemeDialog "presets"; $d.Close(); $script:ThemeWin = $null }

# Cover: 40 Bilddateien erzeugen, einlesen wie beim Uebernehmen der Spieleliste
if (Get-Command Read-CoverSet -ErrorAction SilentlyContinue) {
    $cdir = Join-Path $script:Snapshot "covers"
    New-Item -ItemType Directory -Path $cdir -Force | Out-Null
    $files = @()
    for ($i = 0; $i -lt 40; $i++) {
        $dv = [System.Windows.Media.DrawingVisual]::new()
        $dc = $dv.RenderOpen()
        $br = [System.Windows.Media.LinearGradientBrush]::new((ConvertFrom-Hsv ($i * 9) 0.7 0.9), (ConvertFrom-Hsv ($i * 9 + 60) 0.8 0.4), 45)
        $dc.DrawRectangle($br, $null, [System.Windows.Rect]::new(0, 0, 260, 260))
        $dc.DrawEllipse([System.Windows.Media.Brushes]::White, $null, [System.Windows.Point]::new(60 + $i * 3, 130), 40, 40)
        $dc.Close()
        $bmp = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(260, 260, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $bmp.Render($dv)
        $enc = [System.Windows.Media.Imaging.JpegBitmapEncoder]::new()
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $f = Join-Path $cdir ("c{0}.jpg" -f $i)
        $fs = [IO.File]::Create($f); try { $enc.Save($fs) } finally { $fs.Close() }
        $files += $f
    }
    $script:PerfFiles = $files
    Measure-PerfStep "40 Cover einlesen (in der Oberflaeche, wie bisher)" { foreach ($f in $script:PerfFiles) { [void](New-GameIcon $f) } }
    Measure-PerfStep "40 Cover erneut (schon eingelesen)" { foreach ($f in $script:PerfFiles) { [void](New-GameIcon $f) } }
    # jetzt im Hintergrund einlesen lassen und nur uebernehmen
    $script:IconCache = @{}
    $csync = [hashtable]::Synchronized(@{ Done = $false; Result = $null; Paths = $files })
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = "MTA"; $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $csync)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($coverLib + "`n" + 'try { $sync.Result = Read-CoverSet $sync.Paths @{} } finally { $sync.Done = $true }')
    $h = $ps.BeginInvoke()
    $t0 = [Diagnostics.Stopwatch]::StartNew()
    while (-not $csync.Done -and $t0.ElapsedMilliseconds -lt 20000) { Start-Sleep -Milliseconds 5 }
    [void]$info.Add(("Cover im Hintergrund eingelesen: {0} von 40" -f @($csync.Result.Keys).Count))
    try { [void]$ps.EndInvoke($h) } catch {}
    try { $ps.Dispose(); $rs.Dispose() } catch {}
    $script:PerfCovers = $csync.Result
    Set-Page "games"; Wait-PerfIdle
    Measure-PerfStep "40 Cover aus dem Hintergrund uebernehmen und zeigen" {
        foreach ($k in @($script:PerfCovers.Keys)) { $script:IconCache[$k] = $script:PerfCovers[$k] }
        for ($i = 0; $i -lt 40; $i++) { $script:Games[$i].IconImg = New-GameIcon $script:PerfFiles[$i] }
        Update-GameList
    }
}

# ---- Ausgabe
$lines = New-Object System.Collections.ArrayList
$tOpen = 0.0; $tInv = 0.0
try { $tOpen = [double]$env:EDEN_UPDATER_T_OPEN; $tInv = [double]$env:EDEN_UPDATER_T_INVOKE } catch {}
[void]$lines.Add("S`tProzessstart bis Skriptbeginn`t{0:F0}" -f $script:PerfPre)
if ($tInv -gt 0) {
    [void]$lines.Add("S`t  davon PowerShell hochfahren`t{0:F0}" -f $tOpen)
    [void]$lines.Add("S`t  davon Skript einlesen`t{0:F0}" -f ($script:PerfPre - $tInv))
}
$prev = 0.0
foreach ($m in $script:PerfMarks) {
    [void]$lines.Add(("S`t{0}`t{1:F0}" -f $m[0], ($m[1] - $prev))); $prev = $m[1]
    if ($m[0] -eq "bedienbar") { break }
}
$ready = @($script:PerfMarks | Where-Object { $_[0] -eq "bedienbar" })[0][1]
$first = @($script:PerfMarks | Where-Object { $_[0] -eq "erstes Bild" })[0][1]
[void]$lines.Add("T`tSTART bis erstes Bild`t{0:F0}" -f ($script:PerfPre + $first))
[void]$lines.Add("T`tSTART bis bedienbar`t{0:F0}" -f ($script:PerfPre + $ready))
foreach ($m in $script:PerfSteps) { [void]$lines.Add(("P`t{0}`t{1:F1}`t{2:F1}" -f $m[0], $m[1], $m[2])) }
[void]$info.Add("Hilfsfunktionen aus der EXE: " + [bool]$script:Native)
[void]$info.Add("DwmTheme aus " + [IO.Path]::GetFileName([DwmTheme].Assembly.Location))
foreach ($x in $info) { [void]$lines.Add("I`t" + $x + "`t0") }
Set-Content -LiteralPath (Join-Path $script:Snapshot "perf.txt") -Value $lines -Encoding UTF8
try { $script:PerfWorker.PS.Stop(); $script:PerfWorker.RS.Dispose() } catch {}
$window.Close()
