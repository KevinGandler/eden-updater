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

function Read-LaunchData {
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
    $script:LaunchStamp = $stamp
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
    return ($parts -join "  ·  ")
}

# Startdaten an die Spiele haengen (Zuordnung ueber die Title-ID)
function Set-GameLaunchProps {
    foreach ($g in @($script:Games)) {
        $e = $null
        if ($g.Tid) { $e = $script:LaunchData[([string]$g.Tid).ToUpperInvariant()] }
        $g | Add-Member -NotePropertyName LastPlayed  -NotePropertyValue $(if ($e) { $e.Time } else { $null }) -Force
        $g | Add-Member -NotePropertyName LaunchCount -NotePropertyValue $(if ($e) { [int]$e.Count } else { 0 }) -Force
        $txt = Get-PlayedText $g
        $g | Add-Member -NotePropertyName PlayedTip -NotePropertyValue $(if ($g.LastPlayed) { TF "GamesLastPlayed" $txt } elseif ($txt) { $txt } else { $null }) -Force
    }
}

# Hat Eden seit dem letzten Lesen etwas gestartet? Dann Liste und "Weiterspielen" auffrischen
function Update-LaunchDataIfChanged {
    if (-not $script:GamesLoaded -or $script:Snapshot) { return }
    $stamp = $null
    try { $p = Get-LaunchFile; if (Test-Path -LiteralPath $p) { $stamp = (Get-Item -LiteralPath $p).LastWriteTimeUtc } } catch {}
    if ($stamp -eq $script:LaunchStamp) { return }
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

