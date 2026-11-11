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

function Complete-GameScan {
    $w = $script:GameWorker
    $script:GameWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $gameSync.Result
    $script:GamesLoaded = $true
    if ($r -and $r.Ok) {
        foreach ($g in @($r.Games)) {
            $img = $null
            if ($g.Icon) {
                try {
                    $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
                    $bi.BeginInit()
                    $bi.CacheOption      = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bi.DecodePixelWidth = 192
                    $bi.UriSource        = [Uri]::new([string]$g.Icon)
                    $bi.EndInit()
                    $bi.Freeze()
                    $img = $bi
                } catch {}
            }
            $g | Add-Member -NotePropertyName IconImg -NotePropertyValue $img -Force
            $g | Add-Member -NotePropertyName IsFav -NotePropertyValue (Test-GameFav $g) -Force
            Add-GameTileProps $g
        }
        $script:Games     = @($r.Games)
        Read-LaunchData
        Set-GameLaunchProps
        if ($r.CacheNames) { $script:CacheNames = $r.CacheNames }
        $script:GamesDirs = [int]$r.Dirs
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

