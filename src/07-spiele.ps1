# ------------------------------------------------------------
#  Spiele-Tab
# ------------------------------------------------------------
$script:Games       = @()
$script:GameWorker  = $null
$script:GamesLoaded = $false
$script:GamesDirs   = 0

function Start-GameScan {
    if ($script:GameWorker) { return }
    $ui.TxtGamesInfo.Text = T "GamesScanning"
    $ui.TxtGamesEmpty.Visibility = "Collapsed"
    $gameSync.Args   = @{ EdenPath = [string]$script:Settings.EdenPath }
    $gameSync.Done   = $false
    $gameSync.Result = $null
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $gameSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($jobGames.ToString())
    $script:GameWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

# Bild aus Datei laden (ganz in den Speicher, damit die Datei nicht gesperrt bleibt)
function New-GameIcon([string]$path) {
    try {
        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.CacheOption      = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.DecodePixelWidth = 192
        $bi.UriSource        = [Uri]::new($path)
        $bi.EndInit()
        $bi.Freeze()
        return $bi
    } catch { return $null }
}

# ============================================================
#  Cover und Spielnamen aus dem Internet
#  Aktuelle Eden-Versionen legen beides nicht mehr im Cache ab. Deshalb wird pro Title-ID
#  einmal bei api.nlib.cc nachgefragt (Name in der eingestellten Sprache + Icon) und das
#  Ergebnis unter %LOCALAPPDATA%\EdenUpdater\covers gemerkt. Abschaltbar in den Einstellungen.
#  Uebertragen wird nur die Title-ID.
# ============================================================
$script:MetaWorker = $null
$script:MetaCache  = @{}      # Title-ID -> @{ Name; Lang; Miss (unbekannte ID); NoIcon (kein Bild vorhanden); At (Datum) }
$script:MetaPending = $false
$script:MetaDirty  = $false
$script:MetaRefreshAt = [DateTime]::MinValue
$metaSync = [hashtable]::Synchronized(@{ Args = $null; Done = $false; Stop = $false; Queue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue)) })

function Get-MetaDir { return (Join-Path (Split-Path -Parent $PointerFile) "covers") }
function Get-MetaIconPath([string]$tid) { return (Join-Path (Get-MetaDir) ($tid.ToUpperInvariant() + ".jpg")) }

# Sprache fuer die Abfrage: was die Datenbank nicht kennt, kommt auf Englisch
function Get-MetaLang {
    $l = [string]$script:LangCode
    if (@("en", "ja", "es", "de", "fr", "nl", "pt", "it", "zh", "ko", "ru") -contains $l) { return $l }
    return "en"
}

function Read-MetaCache {
    $c = @{}
    try {
        $f = Join-Path (Get-MetaDir) "titles.json"
        if (Test-Path -LiteralPath $f) {
            $j = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($pr in $j.PSObject.Properties) {
                $c[$pr.Name.ToUpperInvariant()] = @{ Name = [string]$pr.Value.Name; Lang = [string]$pr.Value.Lang; Miss = [bool]$pr.Value.Miss; NoIcon = [bool]$pr.Value.NoIcon; At = [string]$pr.Value.At }
            }
        }
    } catch {}
    $script:MetaCache = $c
    $script:MetaDirty = $false
}

function Save-MetaCache {
    if (-not $script:MetaDirty) { return }
    try {
        $d = Get-MetaDir
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        [IO.File]::WriteAllText((Join-Path $d "titles.json"), ($script:MetaCache | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
        $script:MetaDirty = $false
    } catch {}
}

# Name und Cover an ein Spiel haengen (Markenzeichen wie (TM) fliegen aus dem Namen)
function Set-GameMeta($g, [string]$name, [string]$iconPath) {
    if ($name) {
        $clean = [regex]::Replace($name, '[\u2122\u00AE\u00A9]', '')
        $clean = [regex]::Replace($clean, '\s{2,}', ' ').Trim()
        if ($clean) {
            $g.Name    = $clean
            $g.Initial = $clean.Substring(0, 1).ToUpper()
            Add-GameTileProps $g
            if ($g.Tid) { $script:CacheNames[([string]$g.Tid).ToUpperInvariant()] = $clean }
        }
    }
    if ($iconPath -and (Test-Path -LiteralPath $iconPath)) {
        $img = New-GameIcon $iconPath
        if ($img) { $g.IconImg = $img }
    }
}

# Einmalige Frage, ob Cover und Namen aus dem Internet geladen werden sollen - mit Vor- und Nachteilen.
# Solange nicht geantwortet wurde (OnlineMeta = $null), wird nichts geladen. Fenster schliessen zaehlt als Nein.
function Invoke-OnlineMetaAsk {
    if ($null -ne $script:Settings.OnlineMeta) { return }
    $ans = Show-Dialog (T "OnlineAskText") "YesNo" "Question" (T "OnlineAskTitle") 640 $true
    $script:Settings.OnlineMeta = ($ans -eq "Yes")
    try { Save-Settings } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
    $ui.ChkOnlineMeta.IsChecked = [bool]$script:Settings.OnlineMeta
    if ($script:Settings.OnlineMeta -and $script:GamesLoaded) { Start-GameScan }
}

# Nach dem Einlesen der Spiele: Gemerktes sofort anwenden, Fehlendes im Hintergrund holen
function Update-GameMeta {
    if (-not $script:Settings.OnlineMeta -or $script:Snapshot) { return }
    Read-MetaCache
    $lang = Get-MetaLang
    $need = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($g in @($script:Games)) {
        if (-not $g.Tid) { continue }
        $tid = ([string]$g.Tid).ToUpperInvariant()
        $e = $script:MetaCache[$tid]
        $icon = Get-MetaIconPath $tid
        $hasIcon = Test-Path -LiteralPath $icon
        if ($e -and -not $e.Miss) { Set-GameMeta $g $(if ($e.Lang -eq $lang) { $e.Name } else { "" }) $icon }
        if ($seen.ContainsKey($tid)) { continue }
        $seen[$tid] = $true
        if (-not $e) {
            [void]$need.Add(@{ Tid = $tid; Name = $true; Icon = (-not $hasIcon) })
        } elseif ($e.Miss) {
            # unbekannte Title-ID: fruehestens nach 7 Tagen wieder fragen
            $at = [DateTime]::MinValue
            [void][DateTime]::TryParse($e.At, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$at)
            if (([DateTime]::Now - $at).TotalDays -ge 7) { [void]$need.Add(@{ Tid = $tid; Name = $true; Icon = (-not $hasIcon) }) }
        } else {
            $needName = ($e.Lang -ne $lang)                       # Sprache gewechselt
            $needIcon = (-not $hasIcon) -and (-not $e.NoIcon)     # Bild fehlt (und die Datenbank hat eins)
            if ($needName -or $needIcon) { [void]$need.Add(@{ Tid = $tid; Name = [bool]$needName; Icon = [bool]$needIcon }) }
        }
    }
    if ($need.Count) { Start-MetaFetch @($need) $lang }
}

$jobMeta = {
    # Laeuft im Hintergrund; meldet jedes Ergebnis einzeln ueber $sync.Queue
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $a = $sync.Args
        if (-not (Test-Path -LiteralPath $a.Dir)) { New-Item -ItemType Directory -Path $a.Dir -Force | Out-Null }
        function Get-Bytes([string]$url) {
            # liefert @{ Code; Data }; Code 0 = Netzwerkfehler
            $rs = $null
            try {
                $rq = [Net.HttpWebRequest][Net.WebRequest]::Create($url)
                $rq.Timeout = 15000; $rq.ReadWriteTimeout = 15000
                $rq.UserAgent = $a.Agent
                $rs = $rq.GetResponse()
                $ms = New-Object IO.MemoryStream
                $rs.GetResponseStream().CopyTo($ms)
                return @{ Code = [int]$rs.StatusCode; Data = $ms.ToArray() }
            } catch [Net.WebException] {
                $code = 0
                if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch {} }
                return @{ Code = $code; Data = $null }
            } catch { return @{ Code = 0; Data = $null } }
            finally { if ($rs) { $rs.Close() } }
        }
        $fails = 0
        foreach ($t in @($a.Items)) {
            if ($sync.Stop -or $fails -ge 3) { break }     # 3 Netzwerkfehler in Folge: offline, aufhoeren
            # Net = Name wegen Netzwerkfehler nicht geholt; IconTried = Bild wurde angefragt und die Antwort kam an
            $res = @{ Tid = $t.Tid; Name = $null; Miss = $false; Icon = $false; IconTried = $false; Net = $false }
            if ($t.Name) {
                $r = Get-Bytes ("https://api.nlib.cc/nx/" + $t.Tid + "?fields=name&lang=" + $a.Lang)
                if ($r.Code -eq 200 -and $r.Data) {
                    $fails = 0
                    try { $res.Name = [string]([Text.Encoding]::UTF8.GetString($r.Data) | ConvertFrom-Json).name } catch {}
                } elseif ($r.Code -eq 404) { $fails = 0; $res.Miss = $true }
                else { $fails++; $res.Net = $true }
            }
            if ($t.Icon -and -not $res.Miss -and -not $res.Net) {
                $r = Get-Bytes ("https://api.nlib.cc/nx/" + $t.Tid + "/icon/260")
                # nur echte JPEGs uebernehmen (beginnen mit FF D8)
                if ($r.Code -eq 200 -and $r.Data -and $r.Data.Length -gt 1000 -and $r.Data[0] -eq 0xFF -and $r.Data[1] -eq 0xD8) {
                    $fails = 0
                    $tmp = Join-Path $a.Dir ($t.Tid + ".tmp")
                    $dst = Join-Path $a.Dir ($t.Tid + ".jpg")
                    [IO.File]::WriteAllBytes($tmp, $r.Data)
                    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
                    Move-Item -LiteralPath $tmp -Destination $dst -Force
                    $res.Icon = $true; $res.IconTried = $true
                } elseif ($r.Code -eq 0) { $fails++ }
                else { $fails = 0; $res.IconTried = $true }
            }
            $sync.Queue.Enqueue($res)
        }
    } catch {} finally { $sync.Done = $true }
}

function Start-MetaFetch($items, [string]$lang) {
    if ($script:MetaWorker -or -not $items -or -not @($items).Count) { return }
    $metaSync.Args = @{ Items = @($items); Lang = $lang; Dir = (Get-MetaDir); Agent = ("EdenUpdater/" + [string]$script:SelfVersion) }
    $metaSync.Done = $false
    $metaSync.Stop = $false
    $metaSync.Queue.Clear()
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $metaSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($jobMeta.ToString())
    $script:MetaLang   = $lang
    $script:MetaGot    = 0
    $script:MetaWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

# Vom UI-Timer aufgerufen: fertige Ergebnisse uebernehmen; die Listen werden hoechstens alle 2 s neu aufgebaut
function Receive-GameMeta {
    $changed = $false
    while ($metaSync.Queue.Count -gt 0) {
        $r = $metaSync.Queue.Dequeue()
        if (-not $r -or $r.Net) { continue }
        $tid = [string]$r.Tid
        $today = [DateTime]::Now.ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
        if ($r.Miss) {
            $script:MetaCache[$tid] = @{ Name = ""; Lang = $script:MetaLang; Miss = $true; NoIcon = $false; At = $today }
            $script:MetaDirty = $true
            continue
        }
        $e = $script:MetaCache[$tid]
        if (-not $e -or $e.Miss) {
            if (-not $r.Name) { continue }      # weder gemerkt noch jetzt ein Name: nichts festhalten
            $e = @{ Name = ""; Lang = $script:MetaLang; Miss = $false; NoIcon = $false; At = $today }
        }
        if ($r.Name) { $e.Name = [string]$r.Name; $e.Lang = $script:MetaLang; $e.At = $today }
        if ($r.IconTried) { $e.NoIcon = (-not $r.Icon) }
        $script:MetaCache[$tid] = $e
        $script:MetaDirty = $true
        foreach ($g in @($script:Games)) {
            if ($g.Tid -and ([string]$g.Tid).ToUpperInvariant() -eq $tid) {
                Set-GameMeta $g ([string]$r.Name) $(if ($r.Icon) { Get-MetaIconPath $tid } else { "" })
                $changed = $true
            }
        }
        if ($r.Name -or $r.Icon) { $script:MetaGot++ }
    }
    if ($changed) { $script:MetaPending = $true }
    $done = [bool]$metaSync.Done -and ($metaSync.Queue.Count -eq 0)
    if ($script:MetaPending -and ($done -or [DateTime]::Now -ge $script:MetaRefreshAt)) {
        $script:MetaPending   = $false
        $script:MetaRefreshAt = [DateTime]::Now.AddSeconds(2)
        Set-GameLaunchProps
        $selKey = Get-GameKey $ui.ListGames.SelectedItem
        Update-GameList
        if ($selKey) {
            foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
        }
        try { if ($script:ModsLoaded) { Update-ModGames } } catch {}
        try { if ($script:ContentLoaded) { Update-ContentGames } } catch {}
        try { if ($script:SavesLoaded) { Update-SaveGames } } catch {}
    }
    if ($done) {
        $w = $script:MetaWorker
        $script:MetaWorker = $null
        try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
        try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
        Save-MetaCache
    }
}

function Complete-GameScan {
    $w = $script:GameWorker
    $script:GameWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $gameSync.Result
    $script:GamesLoaded = $true
    if ($r -and $r.Ok) {
        foreach ($g in @($r.Games)) {
            $img = if ($g.Icon) { New-GameIcon ([string]$g.Icon) } else { $null }
            $g | Add-Member -NotePropertyName IconImg -NotePropertyValue $img -Force
            $g | Add-Member -NotePropertyName IsFav -NotePropertyValue (Test-GameFav $g) -Force
            Add-GameTileProps $g
        }
        $script:Games     = @($r.Games)
        Read-LaunchData
        Set-GameLaunchProps
        if ($r.CacheNames) { $script:CacheNames = $r.CacheNames }
        $script:GamesDirs = [int]$r.Dirs
        try { Update-GameMeta } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
    } else {
        $script:Games = @()
        $script:GamesDirs = 0
        if ($r) { Add-UiLog ((T "ErrPrefix") + " " + $r.Error) }
    }
    Update-GameList
    if ($script:ModsLoaded) { Update-ModGames }
    if ($script:ContentLoaded) { Update-ContentGames }
    if ($script:SavesLoaded) { Update-SaveGames }
}

# Kuerzel fuer Spiele ohne Cover: Anfangsbuchstaben der Woerter, Zahlen bleiben erhalten
# ("Xenoblade Chronicles 3" -> "XC3", "Mario and Luigi Brothership" -> "MLB")
function Get-GameAbbr([string]$name) {
    $out = ""
    foreach ($m in [regex]::Matches([string]$name, '[\p{L}\p{N}]+')) {
        $w = $m.Value
        if ($w -match '^\d+$') { $out += $w.Substring(0, [Math]::Min(2, $w.Length)) }
        elseif ($w -cmatch '^(and|the|of|for|und|der|die|das|no|de|la|le)$') { continue }
        else { $out += $w.Substring(0, 1).ToUpper() }
        if ($out.Length -ge 4) { break }
    }
    if (-not $out) { return "?" }
    return $out.Substring(0, [Math]::Min(4, $out.Length))
}

# Farbverlauf, der sich aus dem Namen ergibt: gleiches Spiel = immer gleiche Farbe
$script:TileBrushes = @{}
function Get-GameTileBrush([string]$name) {
    # Pruefsumme breit streuen, damit sich auch "... 2" und "... 3" deutlich unterscheiden
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { $sum = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(([string]$name).ToLowerInvariant())) } finally { $md5.Dispose() }
    $h = (([int]$sum[0] * 256) + [int]$sum[1]) % 360
    if (-not $script:TileBrushes.ContainsKey($h)) {
        $b = [System.Windows.Media.LinearGradientBrush]::new()
        $b.StartPoint = [System.Windows.Point]::new(0, 0)
        $b.EndPoint   = [System.Windows.Point]::new(1, 1)
        $b.GradientStops.Add([System.Windows.Media.GradientStop]::new((ConvertFrom-Hsv $h 0.60 0.66), 0))
        $b.GradientStops.Add([System.Windows.Media.GradientStop]::new((ConvertFrom-Hsv ($h + 38) 0.72 0.36), 1))
        $b.Freeze()
        $script:TileBrushes[$h] = $b
    }
    return $script:TileBrushes[$h]
}

function Add-GameTileProps($g) {
    $g | Add-Member -NotePropertyName Abbr      -NotePropertyValue (Get-GameAbbr $g.Name) -Force
    $g | Add-Member -NotePropertyName TileBrush -NotePropertyValue (Get-GameTileBrush $g.Name) -Force
}

# Liegt das angeklickte Element in einem Listeneintrag (und nicht im leeren Bereich der Liste)?
function Test-InListItem($src) {
    $d = $src
    while ($d) {
        if ($d -is [System.Windows.Controls.ListBoxItem]) { return $true }
        $d = if ($d -is [System.Windows.Media.Visual]) { [System.Windows.Media.VisualTreeHelper]::GetParent($d) } else { $null }
    }
    return $false
}

# ---- Zuletzt gespielt: Eden fuehrt in <Daten>\cache\launched.json pro Title-ID Startzahl und Zeitpunkt ----
$script:LaunchData  = @{}
$script:LaunchStamp = $null
function Get-LaunchFile { return (Join-Path (Get-EdenDataDir) "cache\launched.json") }

# Spielzeit: Eden schreibt <Daten>\play_time\*.bin - Saetze zu je 16 Byte: Title-ID (8 Byte) + Sekunden (8 Byte), Little Endian
$script:PlayTime = @{}
function Get-PlayTimeDir { return (Join-Path (Get-EdenDataDir) "play_time") }

function Read-PlayTime {
    $d = @{}
    try {
        $dir = Get-PlayTimeDir
        if (Test-Path -LiteralPath $dir) {
            foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter "*.bin" -File -ErrorAction SilentlyContinue)) {
                $b = [IO.File]::ReadAllBytes($f.FullName)
                for ($i = 0; $i + 16 -le $b.Length; $i += 16) {
                    $tid = [BitConverter]::ToUInt64($b, $i).ToString("X16")
                    $sec = [BitConverter]::ToUInt64($b, $i + 8)
                    if ($sec -gt 0 -and $sec -lt 3153600000) {      # unter 100 Jahren, sonst ist der Satz kaputt
                        $d[$tid] = [double]$(if ($d.ContainsKey($tid)) { $d[$tid] } else { 0 }) + [double]$sec    # mehrere Profile: zusammenzaehlen
                    }
                }
            }
        }
    } catch {}
    $script:PlayTime = $d
}

# "21 h 20 min" / "45 min"; leer, wenn nichts gezaehlt wurde
function Format-PlayTime($sec) {
    $s = [double]$sec
    if ($s -le 0) { return "" }
    if ($s -lt 60) { return "< 1 min" }
    $h = [Math]::Floor($s / 3600); $m = [Math]::Floor(($s % 3600) / 60)
    if ($h -ge 1) { return ("{0} h {1} min" -f $h, $m) }
    return ("{0} min" -f $m)
}

# Zeitstempel der Dateien, aus denen Start- und Spielzeitdaten kommen (zum Erkennen von Aenderungen)
function Get-LaunchStamp {
    $t = [DateTime]::MinValue
    try {
        $files = @()
        $p = Get-LaunchFile
        if (Test-Path -LiteralPath $p) { $files += (Get-Item -LiteralPath $p) }
        $pd = Get-PlayTimeDir
        if (Test-Path -LiteralPath $pd) { $files += @(Get-ChildItem -LiteralPath $pd -Filter "*.bin" -File -ErrorAction SilentlyContinue) }
        foreach ($f in $files) { if ($f.LastWriteTimeUtc -gt $t) { $t = $f.LastWriteTimeUtc } }
    } catch {}
    return $t
}

function Read-LaunchData {
    Read-PlayTime
    $d = @{}
    $stamp = $null
    try {
        $p = Get-LaunchFile
        if (Test-Path -LiteralPath $p) {
            $stamp = (Get-Item -LiteralPath $p).LastWriteTimeUtc
            $j = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($pr in $j.PSObject.Properties) {
                $ts = 0L
                try { $ts = [long]$pr.Value.timestamp } catch {}
                $n = 0
                try { $n = [int]$pr.Value.launch_count } catch {}
                $d[$pr.Name.ToUpperInvariant()] = @{ Count = $n; Time = $(if ($ts -gt 0) { [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime } else { $null }) }
            }
        }
    } catch {}
    $script:LaunchData  = $d
    $script:LaunchStamp = Get-LaunchStamp
}

# "08.11.2026  ·  202× gestartet" (Datum in der Schreibweise der gewaehlten Sprache)
function Get-PlayedText($g) {
    $parts = @()
    if ($g.LastPlayed) {
        $cul = $null
        try { $cul = [Globalization.CultureInfo]::GetCultureInfo([string]$script:LangCulture) } catch {}
        $parts += $(if ($cul) { $g.LastPlayed.ToString("d", $cul) } else { $g.LastPlayed.ToString("d") })
    }
    if ([int]$g.LaunchCount -gt 0) { $parts += (TF "GamesLaunches" ([int]$g.LaunchCount)) }
    $pt = Format-PlayTime $g.PlaySeconds
    if ($pt) { $parts += $pt }
    return ($parts -join "  ·  ")
}

# Startdaten an die Spiele haengen (Zuordnung ueber die Title-ID)
function Set-GameLaunchProps {
    foreach ($g in @($script:Games)) {
        $e = $null
        if ($g.Tid) { $e = $script:LaunchData[([string]$g.Tid).ToUpperInvariant()] }
        $g | Add-Member -NotePropertyName LastPlayed  -NotePropertyValue $(if ($e) { $e.Time } else { $null }) -Force
        $g | Add-Member -NotePropertyName LaunchCount -NotePropertyValue $(if ($e) { [int]$e.Count } else { 0 }) -Force
        $ps = 0
        if ($g.Tid -and $script:PlayTime.ContainsKey(([string]$g.Tid).ToUpperInvariant())) { $ps = $script:PlayTime[([string]$g.Tid).ToUpperInvariant()] }
        $g | Add-Member -NotePropertyName PlaySeconds -NotePropertyValue $ps -Force
        $txt = Get-PlayedText $g
        $g | Add-Member -NotePropertyName PlayedTip -NotePropertyValue $(if ($g.LastPlayed) { TF "GamesLastPlayed" $txt } elseif ($txt) { $txt } else { $null }) -Force
    }
}

# Hat Eden seit dem letzten Lesen etwas gestartet? Dann Liste und "Weiterspielen" auffrischen
function Update-LaunchDataIfChanged {
    if (-not $script:GamesLoaded -or $script:Snapshot) { return }
    if ((Get-LaunchStamp) -eq $script:LaunchStamp) { return }
    Read-LaunchData
    Set-GameLaunchProps
    $selKey = Get-GameKey $ui.ListGames.SelectedItem
    Update-GameList
    if ($selKey) {
        foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
    }
}

# Karte "Weiterspielen": das zuletzt gestartete Spiel, nur ohne Suchtext und wenn Eden vorhanden ist
$script:ContinueGame = $null
function Update-GameContinue([bool]$show) {
    $g = $null
    if ($show) {
        foreach ($x in @($script:Games)) { if ($x.LastPlayed -and (-not $g -or $x.LastPlayed -gt $g.LastPlayed)) { $g = $x } }
    }
    $script:ContinueGame = $g
    if (-not $g) { $ui.GameContinue.Visibility = "Collapsed"; return }
    $ui.ContTile.Background = $g.TileBrush
    $ui.ContAbbr.Text       = [string]$g.Abbr
    if ($g.IconImg) {
        $ib = [System.Windows.Media.ImageBrush]::new($g.IconImg)
        $ib.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        $ui.ContImg.Background = $ib
    } else { $ui.ContImg.Background = $null }
    $ui.TxtContName.Text = [string]$g.Name
    $ui.TxtContInfo.Text = Get-PlayedText $g
    $ui.GameContinue.Visibility = "Visible"
}

function Update-GameList {
    $q = $ui.TxtGameSearch.Text.Trim()
    $ui.TxtGameSearchHint.Visibility = if ($ui.TxtGameSearch.Text) { "Collapsed" } else { "Visible" }
    if (-not $script:GamesLoaded) { return }
    $list = if ($q) { @($script:Games | Where-Object { $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 }) } else { @($script:Games) }
    # Favoriten zuerst; danach alphabetisch oder - je nach Auswahl - zuletzt gespielt zuerst (nie gespielte am Ende)
    if ([string]$script:Settings.GamesSort -eq "recent") {
        $list = @($list | Sort-Object -Property @{ Expression = { if ($_.IsFav) { 0 } else { 1 } } },
                                                @{ Expression = { if ($_.LastPlayed) { [long]::MaxValue - $_.LastPlayed.Ticks } else { [long]::MaxValue } } }, Name)
    } else {
        $list = @($list | Sort-Object -Property @{ Expression = { if ($_.IsFav) { 0 } else { 1 } } }, Name)
    }
    $ui.ListGames.ItemsSource = $list
    $hasEden = Test-Path (Join-Path $script:Settings.EdenPath "eden.exe")
    Update-GameContinue ([bool](($hasEden -or $script:Snapshot) -and -not $q))
    if (-not $hasEden -and $script:Games.Count -gt 0) {
        # Spiele gefunden, aber Eden fehlt: Hinweis in der Info-Zeile statt ueber der Liste
        $ui.TxtGamesInfo.Text = T "GamesNoEden"
        $ui.TxtGamesEmpty.Visibility = "Collapsed"
    } elseif (-not $hasEden) {
        $ui.TxtGamesInfo.Text  = ""
        $ui.TxtGamesEmpty.Text = T "GamesNoEden"
        $ui.TxtGamesEmpty.Visibility = "Visible"
    } elseif ($script:Games.Count -eq 0) {
        $ui.TxtGamesInfo.Text  = TF "GamesInfo" 0 $script:GamesDirs
        $ui.TxtGamesEmpty.Text = T "GamesEmpty"
        $ui.TxtGamesEmpty.Visibility = "Visible"
    } else {
        $ui.TxtGamesInfo.Text = TF "GamesInfo" $script:Games.Count $script:GamesDirs
        $ui.TxtGamesEmpty.Visibility = "Collapsed"
    }
    Update-GameButton
}

# Favoriten: Schluessel ist die Title-ID (bleibt beim Verschieben/Umbenennen gleich), sonst der Dateipfad
function Get-GameKey($g) {
    if (-not $g) { return "" }
    if ($g.Tid) { return ([string]$g.Tid).ToUpperInvariant() }
    return [string]$g.Path
}

function Test-GameFav($g) {
    $k = Get-GameKey $g
    if (-not $k) { return $false }
    foreach ($f in @($script:Settings.FavoriteGames)) { if ([string]$f -eq $k) { return $true } }
    return $false
}

function Switch-GameFav($g) {
    $k = Get-GameKey $g
    if (-not $k) { return }
    $on = -not [bool]$g.IsFav
    foreach ($x in $script:Games) { if ((Get-GameKey $x) -eq $k) { $x.IsFav = $on } }
    $favs = @(@($script:Settings.FavoriteGames) | Where-Object { $_ -and ([string]$_ -ne $k) } | ForEach-Object { [string]$_ })
    if ($on) { $favs += $k }
    $script:Settings.FavoriteGames = $favs
    if (-not $script:Snapshot) { try { Save-Settings } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) } }
    # Auswahl beibehalten, obwohl die Liste neu sortiert wird
    $selKey = Get-GameKey $ui.ListGames.SelectedItem
    Update-GameList
    if ($selKey) {
        foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
    }
}

# Liegt das angeklickte Element im Stern-Button? (dann kein Spielstart per Doppelklick)
function Test-InFavButton($src) {
    $d = $src
    while ($d -and -not ($d -is [System.Windows.Controls.ListBoxItem])) {
        if ($d -is [System.Windows.Controls.Button] -and [string]$d.Tag -eq "fav") { return $true }
        if ($d -is [System.Windows.Media.Visual] -or $d -is [System.Windows.Media.Media3D.Visual3D]) { $d = [System.Windows.Media.VisualTreeHelper]::GetParent($d) }
        else { $d = [System.Windows.LogicalTreeHelper]::GetParent($d) }
    }
    return $false
}

# ============================================================
#  Detailansicht eines Spiels
# ============================================================
# Was Eden zuletzt fuer ein Spiel erkannt hat, steht in <Daten>\cache\game_list\<Title-ID>.pv.txt, eine Zeile je Eintrag:
#   "Update (NAND) (2.2.0)"  /  "DLC (1, 2, 3)"  /  "Modname (IPSwitch)"  -  ein vorangestelltes "[D] " heisst deaktiviert
function Read-GamePatchInfo([string]$tid) {
    $r = @{ Found = $false; Update = ""; UpdateOff = $false; Dlc = 0; ModsOn = 0; ModsOff = 0 }
    try {
        if (-not $tid) { return $r }
        $f = Join-Path (Get-EdenDataDir) ("cache\game_list\" + $tid.ToUpperInvariant() + ".pv.txt")
        if (-not (Test-Path -LiteralPath $f)) { return $r }
        $r.Found = $true
        foreach ($raw in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
            $l = $raw.Trim()
            if (-not $l) { continue }
            $off = $false
            if ($l.StartsWith("[D]")) { $off = $true; $l = $l.Substring(3).Trim() }
            if ($l -match '^Update\b.*\(([^()]+)\)\s*$') { if (-not $r.Update -or -not $off) { $r.Update = $Matches[1].Trim(); $r.UpdateOff = $off } }
            elseif ($l -match '^Update\b') { if (-not $r.Update) { $r.Update = "?"; $r.UpdateOff = $off } }
            elseif ($l -match '^DLC\b\s*\(([^()]*)\)') { $r.Dlc = @($Matches[1] -split ',' | Where-Object { $_.Trim() }).Count }
            elseif ($l -match '^DLC\b') { $r.Dlc = [Math]::Max(1, $r.Dlc) }
            elseif ($off) { $r.ModsOff++ } else { $r.ModsOn++ }
        }
    } catch {}
    return $r
}

function Add-DetailRow([string]$label, [string]$value, [bool]$mono = $false) {
    $g = [System.Windows.Controls.Grid]::new()
    $g.Margin = [System.Windows.Thickness]::new(0, 0, 0, 9)
    $c0 = [System.Windows.Controls.ColumnDefinition]::new(); $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = [System.Windows.Controls.ColumnDefinition]::new(); $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add($c1)
    $a = [System.Windows.Controls.TextBlock]::new()
    $a.Text = $label
    $a.MaxWidth = 130
    $a.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $a.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "BrMuted")
    $b = [System.Windows.Controls.TextBlock]::new()
    $b.Text = $value
    $b.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $b.TextAlignment = [System.Windows.TextAlignment]::Right
    $b.Margin = [System.Windows.Thickness]::new(14, 0, 0, 0)
    $b.FontWeight = [System.Windows.FontWeights]::SemiBold
    if ($mono) { $b.FontFamily = $window.FindResource("FontMono"); $b.FontWeight = [System.Windows.FontWeights]::Normal; $b.FontSize = 12 }
    [System.Windows.Controls.Grid]::SetColumn($b, 1)
    [void]$g.Children.Add($a); [void]$g.Children.Add($b)
    [void]$ui.DetRows.Children.Add($g)
}

$script:DetailGame = $null
function Show-GameDetail($g, [bool]$animate = $true) {
    if (-not $g) { Hide-GameDetail; return }
    $script:DetailGame = $g
    $dash = [string][char]0x2013
    $ui.DetTile.Background = $g.TileBrush
    $ui.DetAbbr.Text       = [string]$g.Abbr
    if ($g.IconImg) {
        $ib = [System.Windows.Media.ImageBrush]::new($g.IconImg)
        $ib.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        $ui.DetImg.Background = $ib
    } else { $ui.DetImg.Background = $null }
    $ui.TxtDetName.Text = [string]$g.Name
    $ui.TxtDetInfo.Text = [string]$g.Info

    $ui.DetRows.Children.Clear()
    $last = ""
    if ($g.LastPlayed) {
        $last = $g.LastPlayed.ToString("d", $script:CI)
        if ([int]$g.LaunchCount -gt 0) { $last += "  ·  " + (TF "GamesLaunches" ([int]$g.LaunchCount)) }
    }
    Add-DetailRow (T "GamesSortRecent") $(if ($last) { $last } else { $dash })
    $pt = Format-PlayTime $g.PlaySeconds
    Add-DetailRow (T "DetPlayTime") $(if ($pt) { $pt } else { $dash })
    $pi = if ($script:Snapshot -and $g.SnapPatch) { $g.SnapPatch } else { Read-GamePatchInfo ([string]$g.Tid) }
    if ($pi.Found) {
        Add-DetailRow (T "DetUpdate") $(if ($pi.Update) { $pi.Update } else { $dash })
        Add-DetailRow "DLC" $(if ($pi.Dlc) { [string]$pi.Dlc } else { $dash })
        Add-DetailRow (T "NavMods") $(if ($pi.ModsOn + $pi.ModsOff) { TF "DetModsVal" $pi.ModsOn $pi.ModsOff } else { $dash })
    }
    $ui.TxtDetHint.Visibility = if ($pi.Found) { "Visible" } else { "Collapsed" }
    if ($g.Tid) { Add-DetailRow "Title-ID" ([string]$g.Tid) $true }
    if ($g.Path) { Add-DetailRow (T "DetFile") ([IO.Path]::GetFileName([string]$g.Path)) }

    $hasEden = Test-Path (Join-Path $script:Settings.EdenPath "eden.exe")
    $ui.BtnDetStart.IsEnabled = [bool]$hasEden
    $vis = if ($g.Tid) { "Visible" } else { "Collapsed" }     # ohne Title-ID gibt es keine Zuordnung zu Mods/Inhalten/Spieldaten
    $ui.BtnDetMods.Visibility = $vis; $ui.BtnDetContent.Visibility = $vis; $ui.BtnDetSaves.Visibility = $vis
    $ui.BtnDetShow.Visibility = if ($g.Path) { "Visible" } else { "Collapsed" }

    $wasOpen = ($ui.GameDetail.Visibility -eq "Visible")
    $ui.GameDetail.Visibility = "Visible"
    if (-not $wasOpen -and $animate) { Start-FadeIn $ui.GameDetail 0 36 280 }
}

function Hide-GameDetail {
    $script:DetailGame = $null
    $ui.GameDetail.Visibility = "Collapsed"
}

# Auswahl hat sich geaendert: offene Detailansicht mitziehen (oder schliessen, wenn nichts mehr gewaehlt ist)
function Sync-GameDetail {
    if ($ui.GameDetail.Visibility -ne "Visible") { return }
    $sel = $ui.ListGames.SelectedItem
    if ($sel) { Show-GameDetail $sel $false } else { Hide-GameDetail }
}

# Aus der Detailansicht in einen anderen Tab springen und dort dasselbe Spiel auswaehlen
$script:WantTid = @{}
function Show-GameIn([string]$page, $g) {
    if (-not $g -or -not $g.Tid) { return }
    $script:WantTid[$page] = [string]$g.Tid
    Set-Page $page
}

# In einer der Spielelisten (Mods, Updates/DLC, Spieldaten) das gewuenschte Spiel auswaehlen, sobald es da ist
function Select-WantedGame([string]$page, $listBox, $items) {
    $want = $script:WantTid[$page]
    if (-not $want) { return }
    $hit = @($items | Where-Object { $_.Tid -eq $want }) | Select-Object -First 1
    if ($hit) {
        $listBox.SelectedItem = $hit
        try { $listBox.ScrollIntoView($hit) } catch {}
        $script:WantTid.Remove($page)
    }
}

function Show-GameInExplorer($g) {
    try {
        if ($g -and $g.Path -and (Test-Path -LiteralPath $g.Path)) { Start-Process explorer.exe -ArgumentList ('/select,"' + [string]$g.Path + '"') }
    } catch {}
}

function Update-GameButton {
    $ui.BtnGameStart.IsEnabled = [bool]($ui.ListGames.SelectedItem -and (Test-Path (Join-Path $script:Settings.EdenPath "eden.exe")))
}

function Start-Game($game) {
    if (-not $game) { return }
    $exe = Join-Path $script:Settings.EdenPath "eden.exe"
    if (-not (Test-Path $exe)) { Show-Msg ((T "ErrNoExe") + "`n" + $exe); return }
    $argList = @()
    if ($script:Settings.GamesFullscreen) { $argList += "-f" }
    $argList += "-g"
    $argList += ('"' + $game.Path + '"')
    Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $script:Settings.EdenPath
    Add-UiLog (TF "LogGameStart" $game.Name)
    # Standard: in die Taskleiste minimieren; optional ganz schliessen
    if ($script:Settings.GamesCloseOnStart) { $window.Close() }
    else { $window.WindowState = [System.Windows.WindowState]::Minimized }
}

