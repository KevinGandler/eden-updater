# ------------------------------------------------------------
#  Screenshot-Modus: jede Seite in jedem Theme als PNG speichern, dann beenden
# ------------------------------------------------------------
function Save-Snapshot([System.Windows.FrameworkElement]$root, $bg, [string]$name) {
    $root.UpdateLayout()
    $w = [int][Math]::Ceiling($root.ActualWidth); $h = [int][Math]::Ceiling($root.ActualHeight)
    if ($w -le 0 -or $h -le 0) { return }
    $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($root)
    $enc = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create((Join-Path $script:Snapshot ($name + ".png")))
    try { $enc.Save($fs) } finally { $fs.Close() }
}

function Start-Snapshots {
    New-Item -ItemType Directory -Path $script:Snapshot -Force | Out-Null
    # Beispieldaten
    $script:Releases = @(for ($i = 0; $i -lt 9; $i++) {
        [pscustomobject]@{ Tag = ("v17937{0}5818.0{1}677aa50{0}" -f (9 - $i), $i); Url = ""; Date = [DateTime]::Now.AddDays(-$i * 2).ToString("g") }
    })
    $script:Games = @("Abenteuer im Nebelwald", "Kart Turbo Deluxe", "Pixel Quest", "Sternenhafen Chroniken 2", "Sternenhafen Chroniken 3", "Sternenhafen Chroniken: Definitive Edition", "Zeitreise-Labor") | ForEach-Object {
        $g = [pscustomobject]@{ Name = $_; Path = ""; Info = "NSP  ·  4,2 GB"; Initial = $_.Substring(0, 1); Icon = ""; IconImg = $null }
        Add-GameTileProps $g
        $g
    }
    $script:GamesLoaded = $true
    $script:GamesDirs   = 1
    $i = 0
    foreach ($g in $script:Games) { $i++; $g | Add-Member -NotePropertyName Tid -NotePropertyValue ("0100000000{0:X2}0000" -f $i) -Force }
    foreach ($g in $script:Games) { $g | Add-Member -NotePropertyName IsFav -NotePropertyValue ($g.Name -eq "Pixel Quest") -Force }
    $script:LaunchData = @{
        "0100000000050000" = @{ Count = 202; Time = [DateTime]::Now.AddDays(-2) }
        "0100000000020000" = @{ Count = 9;   Time = [DateTime]::Now.AddDays(-20) }
        "0100000000030000" = @{ Count = 45;  Time = [DateTime]::Now.AddDays(-70) }
    }
    Set-GameLaunchProps
    $script:Settings.GamesSort = "recent"
    $script:SortFilling = $true
    try { $ui.CmbGameSort.SelectedValue = "recent" } finally { $script:SortFilling = $false }
    $script:Mods = @(
        @{ Tid = "0100000000010000"; Name = "60 FPS"; Path = ""; Size = 48KB; Parts = "exefs" },
        @{ Tid = "0100000000010000"; Name = "HD-Texturen"; Path = ""; Size = 1.4GB; Parts = "romfs" },
        @{ Tid = "0100000000010000"; Name = "Unendlich Ausdauer"; Path = ""; Size = 2KB; Parts = "cheats" },
        @{ Tid = "0100000000020000"; Name = "Dynamische Aufloesung aus"; Path = ""; Size = 12KB; Parts = "exefs" }
    )
    $script:ModsLoaded = $true
    $script:Content = @(
        @{ Base = "0100000000010000"; Tid = "0100000000010800"; Kind = "update"; Version = 196608; Name = "Abenteuer im Nebelwald"; File = "a.nsp"; Path = ""; Size = 812MB; Source = "ext"; Managed = $true },
        @{ Base = "0100000000010000"; Tid = "0100000000010800"; Kind = "update"; Version = 131072; Name = "Abenteuer im Nebelwald"; File = "b.nsp"; Path = ""; Size = 640MB; Source = "game"; Managed = $false },
        @{ Base = "0100000000010000"; Tid = "0100000000011001"; Kind = "dlc"; Version = 0; Name = "Abenteuer im Nebelwald - Erweiterungspass"; File = "c.nsp"; Path = ""; Size = 2.1GB; Source = "ext"; Managed = $true },
        @{ Base = "0100000000020000"; Tid = "0100000000020800"; Kind = "update"; Version = 65536; Name = "Kart Turbo Deluxe"; File = "d.nsp"; Path = ""; Size = 420MB; Source = "ext"; Managed = $true },
        @{ Base = "0100000000010000"; Tid = "0100000000011002"; Kind = "dlc"; Version = 0; Name = ""; File = "e.nca"; Path = ""; Paths = @(); Size = 96MB; Source = "nand"; Managed = $false }
    )
    $script:ContentLoaded = $true
    $now = Get-Date
    $script:SaveData = @{
        Saves = @(
            @{ Tid = "0100000000010000"; Dirs = @(); Size = 2.4MB; Files = 3; Newest = $now.AddHours(-2).ToUniversalTime() },
            @{ Tid = "0100000000030000"; Dirs = @(); Size = 640KB; Files = 1; Newest = $now.AddDays(-3).ToUniversalTime() }
        )
        Shaders = @{ "0100000000010000" = @{ Size = 245MB; Path = "" }; "0100000000020000" = @{ Size = 88MB; Path = "" } }
        Backups = @(
            @{ Tid = "0100000000010000"; Path = ""; File = "a.zip"; Time = $now.AddHours(-2); Reason = "manual"; Size = 2.3MB },
            @{ Tid = "0100000000010000"; Path = ""; File = "b.zip"; Time = $now.AddDays(-1); Reason = "auto"; Size = 2.2MB },
            @{ Tid = "0100000000010000"; Path = ""; File = "c.zip"; Time = $now.AddDays(-6); Reason = "restore"; Size = 1.9MB }
        )
    }
    $script:SavesLoaded = $true
    Update-List
    Update-GameList
    Update-ModGames
    Update-ContentGames
    Update-SaveGames
    $ui.ListModGames.SelectedIndex = 0
    $ui.List.SelectedIndex = 1
    $ui.ListGames.SelectedIndex = 0
    $ui.TxtNotesTitle.Text = $script:Releases[1].Tag
    $ui.TxtNotes.Text = "Neu`r`n  • Beispiel-Eintrag für die Vorschau`r`n  • Noch ein Eintrag mit etwas längerem Text, damit der Umbruch sichtbar wird`r`n`r`nBehoben`r`n  • Absturz beim Laden bestimmter Spielstände"
    $ui.TxtLog.Visibility = "Visible"
    $ui.TxtLog.Text = "Suche nach Releases...`r`n9 Versionen gefunden.`r`nFEHLER: Beispiel-Fehlermeldung"

    $themes = if ($env:EDEN_UPDATER_SNAPSHOT_THEMES) { $env:EDEN_UPDATER_SNAPSHOT_THEMES -split ',' } else { @($ThemePresets.Keys) }
    $script:SnapSteps = New-Object System.Collections.Queue
    foreach ($t in $themes) {
        foreach ($pg in @("versions", "notes", "games", "mods", "content", "saves", "firmware", "settings", "settings-end", "dialog", "themes", "themes-custom")) {
            $script:SnapSteps.Enqueue(@{ Theme = $t; Page = $pg })
        }
    }
    # Optional: Animationen wirklich ablaufen lassen (Theme-Welle, Seitenwechsel, Aktivitaet) und
    # mittendrin fotografieren - so fallen Fehler in diesen Pfaden im automatischen Test auf.
    if ($env:EDEN_UPDATER_SNAPSHOT_FX) {
        foreach ($pg in @("fx-theme", "fx-nav", "fx-busy")) { $script:SnapSteps.Enqueue(@{ Theme = $themes[0]; Page = $pg }) }
    }
    $script:SnapTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:SnapTimer.Interval = [TimeSpan]::FromMilliseconds(700)
    $script:SnapPending = $null
    $script:SnapTimer.Add_Tick({
        try {
            # 1. vorbereiteten Schritt fotografieren
            if ($script:SnapPending) {
                $st = $script:SnapPending
                $script:SnapPending = $null
                $name = "{0}-{1}" -f $st.Theme, $st.Page
                if ($st.Page -like "themes*" -and -not $st.Win) { return }
                if ($st.Win) {
                    Save-Snapshot ([System.Windows.Media.VisualTreeHelper]::GetChild($st.Win, 0)) $st.Win.Background $name
                    $st.Win.Close()
                    $script:ThemeWin = $null
                } else {
                    Save-Snapshot ([System.Windows.Media.VisualTreeHelper]::GetChild($window, 0)) $window.Background $name
                }
                return
            }
            if ($script:SnapSteps.Count -eq 0) { $script:SnapTimer.Stop(); $window.Close(); return }
            # 2. naechsten Schritt vorbereiten (Animationen bekommen bis zum naechsten Tick Zeit)
            $st = $script:SnapSteps.Dequeue()
            Set-SnapTheme $st.Theme
            switch ($st.Page) {
                "settings-end" { Set-Page "settings"; $ui.SettingsScroll.ScrollToEnd() }
                "settings"     { Set-Page "settings"; $ui.SettingsScroll.ScrollToTop() }
                "dialog"       { Set-Page "versions"; $st.Win = New-SnapDialog }
                "themes"        { Set-Page "versions"; $st.Win = New-SnapThemeDialog "presets" }
                "themes-custom" { Set-Page "versions"; $st.Win = New-SnapThemeDialog "custom" }
                "fx-theme"     { Set-Page "versions"; Invoke-SnapFx { Set-ThemeById "dark-sunset" } "fx-theme-mid" 300 }
                "fx-nav"       { Set-Page "versions"; Invoke-SnapFx { Set-Page "settings"; Set-LogVisible $false } "fx-nav-mid" 130 }
                "fx-busy"      { Invoke-SnapFx { Set-Page "versions"; Set-BusyVisual $true; Set-FlowAnim $true; Set-DotPulse $true; Set-LogVisible $true } "fx-busy-mid" 200 }
                default        { Set-Page $st.Page }
            }
            $script:SnapPending = $st
        } catch {
            try { Add-Content -Path (Join-Path $script:Snapshot "errors.txt") -Value ($_.Exception.Message + " | " + $_.InvocationInfo.PositionMessage) } catch {}
        }
    })
    $script:SnapTimer.Start()
}

# Fuehrt $action mit eingeschalteten Animationen aus und fotografiert nach $ms Millisekunden
function Invoke-SnapFx([scriptblock]$action, [string]$name, [int]$ms) {
    $dir = $script:Snapshot
    $script:Snapshot = ""
    $script:ThemeAnimate = $true
    try { & $action } finally { $script:Snapshot = $dir; $script:ThemeAnimate = $false }
    $script:FxName  = $name
    $script:FxTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:FxTimer.Interval = [TimeSpan]::FromMilliseconds($ms)
    $script:FxTimer.Add_Tick({
        $script:FxTimer.Stop()
        try { Save-Snapshot ([System.Windows.Media.VisualTreeHelper]::GetChild($window, 0)) $window.Background $script:FxName }
        catch { try { Add-Content -Path (Join-Path $script:Snapshot "errors.txt") -Value ("FX " + $_.Exception.Message) } catch {} }
    })
    $script:FxTimer.Start()
}

# Theme fuer Screenshots setzen (Hook, damit es auch fuer spaetere Theme-Systeme passt)
function Set-SnapTheme([string]$key) {
    if (Get-Command Set-ThemeById -ErrorAction SilentlyContinue) { Set-ThemeById $key } else { Set-ThemeByKey $key }
}

function New-SnapDialog {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $d = [Windows.Markup.XamlReader]::Parse($msgDlgXaml.Replace('__RES__', $resBlock))
    foreach ($k in $script:ThemeKeys) { $d.Resources[$k] = $window.Resources[$k] }
    Set-LangResources $d
    $d.Owner = $window
    $d.FindName("MsgTitle").Text = T "DlgQuestion"
    $d.FindName("MsgText").Text  = TF "AskInstallBackup" "v1793745818.07677aa500"
    $bh = $d.FindName("MsgButtons")
    foreach ($def in @(@((T "No"), "Btn"), @((T "Yes"), "BtnPrimary"))) {
        $b = [System.Windows.Controls.Button]::new()
        $b.Content = $def[0]
        $b.Style = $window.FindResource($def[1])
        $b.MinWidth = 90
        $b.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        [void]$bh.Children.Add($b)
    }
    $d.Show()
    return $d
}

function New-SnapThemeDialog([string]$tab) {
    $d = New-ThemeDialog $tab
    $d.Show()
    return $d
}

$window.Add_ContentRendered({
    if ($script:Initialized) { return }
    $script:Initialized = $true
    Set-SettingsControls
    Set-NotesLayout
    Set-Page "versions"
    Update-Ui
    $timer.Start()
    if ($script:Snapshot) { Start-Snapshots; return }
    # Auftritt: Seitenleiste gleitet von links herein, der Inhalt steigt von unten auf
    $script:ThemeAnimate = $true
    Start-FadeIn $ui.SideBar 0 -22 420
    Start-FadeIn $ui.MainArea 18 0 520
    if ($script:FirstRun) { Invoke-FirstRun }
    if ($script:SelfExe) {
        $dir = Split-Path -Parent $script:SelfExe
        if (@(Get-ChildItem -LiteralPath $dir -Filter "EdenUpdater*.old" -Force -ErrorAction SilentlyContinue).Count) {
            Add-UiLog (TF "SelfUpdated" (Format-Ver $script:SelfVersion))
        }
        Remove-SelfOld
        $script:SelfCleanAt = [DateTime]::Now.AddSeconds(4)   # falls die alte Instanz noch kurz lief
        if ($script:Settings.SelfUpdateCheck) { Start-SelfCheck $true }
    }
    if ($script:Settings.AutoCheck) { Start-Load ([int]$script:Settings.Pages) }
    else { Add-UiLog (TF "LogAutoOff" (T "BtnReload")); $script:StartupCheck = $false }
})

Set-LangResources $window
Set-ThemeById (Get-ThemeKey)
if (-not $script:Snapshot) { Restore-WindowPlacement }
try { Update-WindowChromeState } catch {}
[void]$window.ShowDialog()
