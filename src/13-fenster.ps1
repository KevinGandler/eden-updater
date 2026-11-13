# ------------------------------------------------------------
#  Fenster aufbauen
# ------------------------------------------------------------
try {
    $xml    = [xml]$xaml
    $reader = New-Object System.Xml.XmlNodeReader $xml
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [void][System.Windows.MessageBox]::Show("UI konnte nicht geladen werden:`n$($_.Exception.Message)", "Eden Updater", "OK", "Error")
    exit 1
}

$ui = @{}
foreach ($n in @("BtnNavVer","BtnNavNotes","BtnNavSet","PanelNotes","PanelNotesSide","NotesContent","TxtNotesHint","ColList","ColNotes","CmbNotes","BtnRestore","ChkClose","TxtThemeName","BtnThemePick","CmbLang","RootGrid","TxtPageTitle","TxtPageSub","ChipState","TxtChip","DotState","BtnLogToggle","TxtSelfVersion","TxtSelfState","BtnSelfCheck","BtnSelfInstall","BtnSelfNotes","ChkSelfUpdate","BtnNavGames","PanelGames","BtnNavMods","PanelMods","BtnNavContent","PanelContent","TxtContentInfo","BtnContentReload","ContentBanner","ListContentGames","TxtContentGameTitle","TxtContentGameSub","BtnContentAdd","BtnContentFolder","ListContent","TxtContentEmpty","BtnNavFw","PanelFirmware","BtnNavSaves","PanelSaves","TxtSavesInfo","BtnShaderAll","BtnSaveBackupDir","BtnSavesReload","SavesBanner","ListSaveGames","TxtSaveGameTitle","TxtSaveGameSub","TxtSaveState","BtnSaveFolder","BtnSaveBackup","TxtShaderState","BtnShaderDelete","ListSaveBackups","TxtSaveBackupsEmpty","FwBanner","TxtFwState","TxtFwSub","FwWarn","TxtFwWarn","BtnFwZip","BtnFwDir","BtnFwDelete","BtnFwFolder","TxtKeysState","TxtKeysSub","BtnKeysInstall","BtnKeysDelete","BtnKeysFolder","TxtModsInfo","BtnModsReload","ModsBanner","ListModGames","TxtModGameTitle","TxtModGameSub","BtnModAdd","BtnModFolder","ListMods","TxtModsEmpty","TxtGameSearch","TxtGameSearchHint","BtnGamesReload","ChkGamesFull","ChkGamesClose","ListGames","TxtGamesInfo","TxtGamesEmpty","BtnGameStart","SettingsScroll","TxtSettingsFile","TxtInstalled","TxtLatest","BtnUpdate","BtnLaunch",
                 "PanelVersions","PanelSettings","List","BtnInstallSel","BtnMore","BtnReload","TxtListInfo",
                 "TxtPath","BtnBrowse","CmbVariant","PanelPattern","TxtPattern","TxtPages","ChkBackup","ChkSaveAuto","ChkStart","ChkAuto","ChkAutoInstall","ChkOnlineMeta","BtnSave",
                 "TxtStatus","BtnCancel","Pb","TxtLog","TxtNotesTitle","BtnNotesWeb","TxtNotes",
                 "GameDetail","DetTile","DetAbbr","DetImg","TxtDetName","TxtDetInfo","BtnDetClose","DetRows","TxtDetHint","BtnDetStart","BtnDetMods","BtnDetContent","BtnDetSaves","BtnDetShow",
                 "SelfNotesBox","TxtSelfNotesTitle","TxtSelfNotes","BtnWinMin","BtnWinMax","BtnWinClose","GameContinue","ContTile","ContAbbr","ContImg","TxtContName","TxtContInfo","BtnGameContinue","CmbGameSort",
                 "SideBar","MainArea","HeadText","NavHost","NavPill","LogoRing","TxtSideVer","DotRing","DotBusy","Flow1","Flow2","Flow3")) {
    $ui[$n] = $window.FindName($n)
}

function Update-LangCombo {
    $sys = Get-SystemLang
    $items = New-Object System.Collections.ArrayList
    [void]$items.Add((New-CbItem ((TF "LangAuto" $script:LangTables[$sys].Name)) ("auto")))
    foreach ($c in $LangOrder) {
        [void]$items.Add((New-CbItem ([string]$script:LangTables[$c].Name) ($c)))
    }
    $cur = [string]$script:Settings.Language
    if (-not ($LangOrder -contains $cur)) { $cur = "auto" }
    $ui.CmbLang.ItemsSource   = $items.ToArray()
    $ui.CmbLang.SelectedValue = $cur
}

# Sichtbare Listen neu aufbauen (z.B. nach Sprachwechsel)
function Refresh-LoadedTabs {
    try { Update-GameList } catch {}
    try { if ($script:ModsLoaded) { Update-ModGames } } catch {}
    try { if ($script:ContentLoaded) { Update-ContentGames } } catch {}
    try { if ($script:SavesLoaded) { Update-SaveGames } } catch {}
    try { Update-FirmwarePage } catch {}
}

function Update-SettingsFileLabel {
    $ui.TxtSettingsFile.Text = TF "SetStoredAt" (Get-SettingsPathFor ([string]$script:Settings.EdenPath))
}

function Set-SettingsControls {
    Update-SettingsFileLabel
    $s = $script:Settings
    $ui.TxtPath.Text    = [string]$s.EdenPath
    $ui.TxtPattern.Text = [string]$s.AssetPattern
    Update-VariantCombo
    $ui.TxtPages.Text   = [string]$s.Pages
    $ui.CmbNotes.ItemsSource = @(
        (New-CbItem ((T "NotesOptPage")) ("page")),
        (New-CbItem ((T "NotesOptSide")) ("side"))
    )
    $ui.CmbNotes.SelectedValue = if ([string]$s.NotesLayout -eq "side") { "side" } else { "page" }
    $ui.ChkBackup.IsChecked      = [bool]$s.Backup
    $ui.ChkSaveAuto.IsChecked    = [bool]$s.SaveBackupOnUpdate
    $ui.ChkStart.IsChecked       = [bool]$s.StartAfter
    $ui.ChkClose.IsChecked       = [bool]$s.CloseAfterStart
    Update-ThemeLabel
    Update-LangCombo
    $ui.ChkAuto.IsChecked        = [bool]$s.AutoCheck
    $ui.ChkAutoInstall.IsChecked = [bool]$s.AutoInstall
    $ui.ChkOnlineMeta.IsChecked  = [bool]$s.OnlineMeta
    $ui.ChkSelfUpdate.IsChecked  = [bool]$s.SelfUpdateCheck
    $ui.ChkGamesFull.IsChecked   = [bool]$s.GamesFullscreen
    $ui.ChkGamesClose.IsChecked  = [bool]$s.GamesCloseOnStart
    $script:SortFilling = $true
    try {
        $ui.CmbGameSort.ItemsSource = @(
            (New-CbItem ((T "GamesSortName")) ("name")),
            (New-CbItem ((T "GamesSortRecent")) ("recent"))
        )
        $ui.CmbGameSort.SelectedValue = if ([string]$s.GamesSort -eq "recent") { "recent" } else { "name" }
    } finally { $script:SortFilling = $false }
    try { if ($script:GamesLoaded) { Set-GameLaunchProps } } catch {}
    try { Update-GameList } catch {}
    Update-SelfCard
}

# --- Navigation
$ui.BtnNavVer.Add_Click({ Set-Page "versions" })
$ui.BtnNavNotes.Add_Click({ Set-Page "notes" })
$ui.BtnNavSet.Add_Click({ Set-Page "settings" })
$ui.BtnNavGames.Add_Click({ Set-Page "games" })
$ui.BtnNavMods.Add_Click({ Set-Page "mods" })
$ui.BtnModsReload.Add_Click({ $script:GamesLoaded = $false; Start-GameScan; Start-ModScan })
$ui.BtnModAdd.Add_Click({ Add-ModFromZip })
$ui.BtnModFolder.Add_Click({ Open-ModFolder })
$ui.ListModGames.Add_SelectionChanged({ Update-ModList })
# Schalter und Loeschen-Buttons in der Mod-Liste (Uid unterscheidet die Aktion)
$ui.ListMods.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $src = $e.OriginalSource
    $mod = $src.DataContext
    if (-not $mod) { return }
    if ($src.Uid -eq "toggle") { Set-ModEnabled $mod ([bool]$src.IsChecked) }
    elseif ($src.Uid -eq "delete") { Remove-Mod $mod }
})
$ui.BtnNavContent.Add_Click({ Set-Page "content" })
$ui.BtnNavFw.Add_Click({ Set-Page "firmware" })
$ui.BtnNavSaves.Add_Click({ Set-Page "saves" })
$ui.BtnSavesReload.Add_Click({ $script:GamesLoaded = $false; Start-GameScan; Start-SavesScan })
$ui.BtnSaveBackupDir.Add_Click({ Open-Dir (Get-SaveBackupDir) })
$ui.BtnShaderAll.Add_Click({ Remove-ShaderCache $true })
$ui.BtnShaderDelete.Add_Click({ Remove-ShaderCache $false })
$ui.BtnSaveBackup.Add_Click({ Invoke-SaveBackup })
$ui.BtnSaveFolder.Add_Click({ Open-SaveFolder })
$ui.ListSaveGames.Add_SelectionChanged({ Update-SaveDetail })
$ui.ListSaveBackups.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $src = $e.OriginalSource
    $item = $src.DataContext
    if (-not $item) { return }
    if ($src.Uid -eq "restore") { Invoke-SaveRestore $item }
    elseif ($src.Uid -eq "delete") { Remove-SaveBackupItem $item }
})
$ui.BtnContentReload.Add_Click({ $script:GamesLoaded = $false; Start-GameScan; Start-ContentScan })
$ui.BtnContentAdd.Add_Click({ Add-ContentFiles })
$ui.BtnContentFolder.Add_Click({ Open-ContentFolder })
$ui.ListContentGames.Add_SelectionChanged({ Update-ContentList })
$ui.ListContent.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $src = $e.OriginalSource
    $item = $src.DataContext
    if (-not $item) { return }
    if ($src.Uid -eq "toggle") { Set-ContentEnabled $item ([bool]$src.IsChecked) }
    elseif ($src.Uid -eq "delete") { Remove-ContentItem $item }
})
$ui.BtnFwZip.Add_Click({ Install-Firmware $true })
$ui.BtnFwDir.Add_Click({ Install-Firmware $false })
$ui.BtnFwDelete.Add_Click({ Remove-Firmware })
$ui.BtnFwFolder.Add_Click({ Open-Dir (Get-FirmwareDir) })
$ui.BtnKeysInstall.Add_Click({ Install-Keys })
$ui.BtnKeysDelete.Add_Click({ Remove-Keys })
$ui.BtnKeysFolder.Add_Click({ Open-Dir (Get-KeysDir) })
$ui.BtnGamesReload.Add_Click({ Start-GameScan })
$ui.BtnGameStart.Add_Click({ Start-Game $ui.ListGames.SelectedItem })
$ui.ListGames.Add_MouseDoubleClick({ param($s, $e) if ((Test-InFavButton $e.OriginalSource) -or -not (Test-InListItem $e.OriginalSource)) { return }; if ($ui.ListGames.SelectedItem) { Start-Game $ui.ListGames.SelectedItem } })
$ui.ListGames.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $b = $e.OriginalSource
    if ($b -is [System.Windows.Controls.Button] -and [string]$b.Tag -eq "fav") { $e.Handled = $true; Switch-GameFav $b.DataContext }
})
$ui.ListGames.Add_SelectionChanged({ Update-GameButton; try { Sync-GameDetail } catch {} })
# Klick auf eine Kachel oeffnet die Detailansicht (nicht beim Stern)
$ui.ListGames.Add_PreviewMouseLeftButtonUp({
    param($s, $e)
    try {
        if ((Test-InFavButton $e.OriginalSource) -or -not (Test-InListItem $e.OriginalSource)) { return }
        if ($ui.ListGames.SelectedItem) { Show-GameDetail $ui.ListGames.SelectedItem }
    } catch {}
})
$ui.BtnDetClose.Add_Click({ Hide-GameDetail })
$ui.BtnDetStart.Add_Click({ if ($script:DetailGame) { Start-Game $script:DetailGame } })
$ui.BtnDetMods.Add_Click({ Show-GameIn "mods" $script:DetailGame })
$ui.BtnDetContent.Add_Click({ Show-GameIn "content" $script:DetailGame })
$ui.BtnDetSaves.Add_Click({ Show-GameIn "saves" $script:DetailGame })
$ui.BtnDetShow.Add_Click({ Show-GameInExplorer $script:DetailGame })
# Esc schliesst die Detailansicht
$window.Add_PreviewKeyDown({
    param($s, $e)
    if ($e.Key -eq "Escape" -and $script:CurrentPage -eq "games" -and $ui.GameDetail.Visibility -eq "Visible") { Hide-GameDetail; $e.Handled = $true }
})
$ui.ListGames.Add_KeyDown({ param($s, $e) if ($e.Key -eq "Return" -and $ui.ListGames.SelectedItem) { Start-Game $ui.ListGames.SelectedItem } })
$ui.TxtGameSearch.Add_TextChanged({ Update-GameList })
$ui.BtnGameContinue.Add_Click({ if ($script:ContinueGame) { Start-Game $script:ContinueGame } })
$ui.CmbGameSort.Add_SelectionChanged({
    if ($script:SortFilling) { return }
    $sel = $ui.CmbGameSort.SelectedItem
    if (-not $sel) { return }
    $v = if ([string]$sel.Tag -eq "recent") { "recent" } else { "name" }
    if ([string]$script:Settings.GamesSort -eq $v) { return }
    $script:Settings.GamesSort = $v
    try { Save-Settings } catch {}
    $selKey = Get-GameKey $ui.ListGames.SelectedItem
    Update-GameList
    if ($selKey) {
        foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
    }
})
# Zurueck im Fenster (z.B. nach dem Spielen): Startdaten neu einlesen, falls Eden sie geaendert hat
$window.Add_Activated({ try { Update-LaunchDataIfChanged } catch {} })
$ui.ChkGamesClose.Add_Click({
    $script:Settings.GamesCloseOnStart = [bool]$ui.ChkGamesClose.IsChecked
    try { Save-Settings } catch {}
})
$ui.ChkGamesFull.Add_Click({
    $script:Settings.GamesFullscreen = [bool]$ui.ChkGamesFull.IsChecked
    try { Save-Settings } catch {}
})

# --- Aktionen
$ui.BtnUpdate.Add_Click({
    try { if ($script:Releases.Count -gt 0) { Start-Install $script:Releases[0] } }
    catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})

$ui.BtnInstallSel.Add_Click({
    try {
        $sel = $ui.List.SelectedItem
        if (-not $sel) { return }
        $q = TF $(if ($script:Settings.Backup) { "AskInstallBackup" } else { "AskInstallNoBackup" }) $sel.Tag
        $a = (Show-Dialog $q "YesNo" "Question")
        if ($a -eq "Yes") { Start-Install $sel }
    } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})

$ui.BtnRestore.Add_Click({
    try {
        if ($script:Busy) { return }
        $bv = Get-BackupVersion
        $q = if ($bv) { TF "AskRestoreVer" $bv } else { T "AskRestore" }
        $a = (Show-Dialog $q "YesNo" "Question")
        if ($a -eq "Yes") { Start-Restore }
    } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})
$ui.BtnLaunch.Add_Click({ try { Start-Eden } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) } })
$ui.BtnReload.Add_Click({ try { Start-Load ([int]$script:Settings.Pages) } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) } })
$ui.BtnMore.Add_Click({
    try { Start-Load ([math]::Min(10, [math]::Max(1, $script:LoadedPages) + 1)) }
    catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})
$ui.BtnSelfCheck.Add_Click({ Start-SelfCheck $false })
$ui.BtnSelfInstall.Add_Click({ Start-SelfDownload })
$ui.BtnSelfNotes.Add_Click({ try { if ($script:SelfInfo.Page) { Start-Process $script:SelfInfo.Page } } catch {} })
$ui.BtnLogToggle.Add_Click({ Set-LogVisible (-not $script:LogOpen) })
# Klick auf den Update-Status oben rechts fuehrt zur Versionsliste
$ui.ChipState.Add_MouseLeftButtonUp({ try { Set-Page "versions" } catch {} })
$ui.BtnCancel.Add_Click({ $sync.Cancel = $true; Add-UiLog (T "LogCancelReq") })
$ui.List.Add_SelectionChanged({ Update-Ui; try { Show-Notes } catch {} })
$ui.BtnNotesWeb.Add_Click({
    try {
        $sel = $ui.List.SelectedItem
        if ($sel) { Start-Process ("https://git.eden-emu.dev/eden-ci/nightly/releases/tag/" + [uri]::EscapeDataString([string]$sel.Tag)) }
    } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})
$ui.CmbVariant.Add_SelectionChanged({ if (-not $script:SuppressVariantEvent) { Update-PatternVisibility } })

# --- Einstellungen
$ui.BtnThemePick.Add_Click({
    try { Show-ThemeDialog } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})
$ui.BtnBrowse.Add_Click({
    try {
        $sel = Show-FolderDialog (T "SetBrowseTitle") $ui.TxtPath.Text
        if ($sel) { $ui.TxtPath.Text = $sel }
    } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
})

$ui.BtnSave.Add_Click({
    try {
        $path = $ui.TxtPath.Text.Trim()
        if (-not $path) { throw (T "ErrNoPath") }
        $variant = [string]$ui.CmbVariant.SelectedValue
        $pat = $ui.TxtPattern.Text.Trim()
        if ($variant -eq "__custom__") {
            if (-not $pat) { throw (T "ErrNoFilter") }
            [void][regex]::new($pat)
        } elseif (-not $pat) { $pat = "Windows.*amd64.*pgo" }
        $pages = 0
        if (-not [int]::TryParse($ui.TxtPages.Text.Trim(), [ref]$pages) -or $pages -lt 1 -or $pages -gt 10) {
            throw (T "ErrPages")
        }
        $lang = [string]$ui.CmbLang.SelectedValue
        if (-not ($LangOrder -contains $lang)) { $lang = "auto" }
        $old = $script:Settings
        $langChanged = ([string]$old.Language -ne $lang)
        $reload = ([string]$old.AssetVariant -ne $variant) -or (($variant -eq "__custom__") -and ($old.AssetPattern -ne $pat)) -or ([int]$old.Pages -ne $pages)
        $script:Settings = @{
            EdenPath     = $path
            NotesLayout  = $(if ([string]$ui.CmbNotes.SelectedValue -eq "side") { "side" } else { "page" })
            AssetVariant = $variant
            AssetPattern = $pat
            Pages        = $pages
            Backup       = [bool]$ui.ChkBackup.IsChecked
            StartAfter   = [bool]$ui.ChkStart.IsChecked
            CloseAfterStart = [bool]$ui.ChkClose.IsChecked
            ThemePreset  = (Get-ThemeKey)
            CustomTheme  = $old.CustomTheme
            AutoCheck    = [bool]$ui.ChkAuto.IsChecked
            AutoInstall  = [bool]$ui.ChkAutoInstall.IsChecked
            OnlineMeta   = [bool]$ui.ChkOnlineMeta.IsChecked
            SelfUpdateCheck = [bool]$ui.ChkSelfUpdate.IsChecked
            GamesFullscreen = [bool]$ui.ChkGamesFull.IsChecked
            GamesCloseOnStart = [bool]$ui.ChkGamesClose.IsChecked
            GamesSort    = $(if ([string]$old.GamesSort -eq "recent") { "recent" } else { "name" })
            WinLeft      = $old.WinLeft
            WinTop       = $old.WinTop
            WinWidth     = $old.WinWidth
            WinHeight    = $old.WinHeight
            WinMax       = [bool]$old.WinMax
            FavoriteGames = @($old.FavoriteGames)
            FirmwareVersion = [string]$old.FirmwareVersion
            SaveBackupOnUpdate = [bool]$ui.ChkSaveAuto.IsChecked
            SaveBackupKeep = $old.SaveBackupKeep
            Language     = $lang
        }
        Save-Settings
        if ($langChanged) {
            # Sprache sofort umschalten (alle Texte sind Ressourcen bzw. werden neu gesetzt)
            Initialize-Language
            Set-LangResources $window
            Set-SettingsControls
            if (-not $script:Busy) { $ui.TxtStatus.Text = T "StReady" }
        }
        Update-SettingsFileLabel
        if ([string]$old.EdenPath -ne $path) {
            # anderer Eden-Ordner: alles, was aus dem alten Ordner gelesen wurde, verwerfen
            $script:GamesLoaded = $false; $script:Games = @(); $script:CacheNames = @{}
            $script:ModsLoaded = $false; $script:Mods = @()
            $script:ContentLoaded = $false; $script:Content = @()
            $script:SavesLoaded = $false; $script:SaveData = $null
            $script:FwPendingVersion = ""
        } elseif ($langChanged) {
            Refresh-LoadedTabs
            if ($script:GamesLoaded -and $script:Settings.OnlineMeta) { Start-GameScan }   # Namen in der neuen Sprache
        } elseif ([bool]$old.OnlineMeta -ne [bool]$script:Settings.OnlineMeta) {
            if ($script:GamesLoaded) { Start-GameScan }
        }
        Add-UiLog (T "LogSettingsSaved")
        Set-NotesLayout
        Update-List
        Update-Ui
        if ($reload) { Start-Load $pages }
        Set-Page "versions"
    } catch { Show-Msg $_.Exception.Message }
})

# --- Timer: holt Log/Fortschritt aus dem Hintergrund-Thread
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    try {
        Flush-Log
        if ($script:Worker) {
            $ui.TxtStatus.Text = [string]$sync.Status
            if ($sync.Progress -lt 0) { $ui.Pb.IsIndeterminate = $true }
            else { $ui.Pb.IsIndeterminate = $false; Set-ProgressValue ([double]$sync.Progress) }
            if ($sync.CanCancel -ne $ui.BtnCancel.IsEnabled) { $ui.BtnCancel.IsEnabled = [bool]$sync.CanCancel }
            if ($sync.Done) { Complete-Worker }
        }
        if ($script:NotesWorker -and $notesSync.Done) { Complete-Notes }
        if ($script:SelfWorker -and $selfSync.Done) { Complete-Self }
        if ($script:GameWorker -and $gameSync.Done) { Complete-GameScan }
        if ($script:MetaWorker) { Receive-GameMeta }
        if ($script:ModWorker -and $modSync.Done) { Complete-ModWorker }
        if ($script:CurrentPage -eq "mods") { Update-ModsBanner }
        if ($script:ContentWorker) {
            if ($contentSync.Done) { Complete-ContentWorker }
            elseif ($contentSync.Args.Mode -eq "add" -and $contentSync.Status) {
                $ui.TxtContentInfo.Text = (TF "ContentCopying" $contentSync.Status) + $(if ($contentSync.Progress -ge 0) { "  " + $contentSync.Progress + " %" } else { "" })
            }
        }
        if ($script:FwWorker) {
            if ($fwSync.Done) { Complete-FwWorker }
            elseif ($fwSync.Total) { $ui.TxtFwSub.Text = TF "FwInstalling" $fwSync.Cur $fwSync.Total }
        }
        if ($script:SavesWorker -and $savesSync.Done) { Complete-SavesWorker }
        if ($script:CurrentPage -eq "content" -or $script:CurrentPage -eq "firmware" -or $script:CurrentPage -eq "saves") { Update-SysBanners }
        if ($script:SelfPrompt -and -not $script:Busy -and -not $script:MsgWin -and -not $script:ThemeWin) {
            $script:SelfPrompt = $false
            Ask-SelfUpdate
        }
        if ($script:SelfCleanAt -and [DateTime]::Now -gt $script:SelfCleanAt) { $script:SelfCleanAt = $null; Remove-SelfOld }
        if ($script:SelfPendingFile -and -not (Test-AnyBusy) -and -not $script:MsgWin -and -not $script:ThemeWin) {
            $f = $script:SelfPendingFile; $script:SelfPendingFile = $null
            Install-SelfUpdate $f
        }
    } catch {}
})

# --- Fenstergroesse und -position merken ---
# Beim Start wiederherstellen; liegt die gemerkte Position ausserhalb aller Bildschirme
# (z.B. Monitor abgesteckt), wird nur die Groesse uebernommen und das Fenster zentriert.
function Restore-WindowPlacement {
    try {
        $st = $script:Settings
        $w = [double]$st.WinWidth; $h = [double]$st.WinHeight
        if ($w -lt $window.MinWidth -or $h -lt $window.MinHeight) { return }
        $SP = [System.Windows.SystemParameters]
        $vl = $SP::VirtualScreenLeft; $vt = $SP::VirtualScreenTop; $vw = $SP::VirtualScreenWidth; $vh = $SP::VirtualScreenHeight
        $w = [Math]::Min($w, $vw); $h = [Math]::Min($h, $vh)
        $l = [double]$st.WinLeft; $t = [double]$st.WinTop
        $visible = ($l + $w -ge $vl + 160) -and ($l -le $vl + $vw - 160) -and ($t -ge $vt - 8) -and ($t -le $vt + $vh - 100)
        $window.Width = $w; $window.Height = $h
        if ($visible) {
            $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
            $window.Left = $l; $window.Top = $t
        }
        if ([bool]$st.WinMax) { $window.WindowState = [System.Windows.WindowState]::Maximized }
    } catch {}
}

$script:WinWasMax = $false
function Save-WindowPlacement {
    try {
        # nur wenn schon Einstellungen existieren (nicht beim abgebrochenen ersten Start)
        if ($script:Snapshot -or -not $script:SettingsFile -or -not (Test-Path -LiteralPath $script:SettingsFile)) { return }
        $state = $window.WindowState
        $max = ($state -eq [System.Windows.WindowState]::Maximized) -or (($state -eq [System.Windows.WindowState]::Minimized) -and $script:WinWasMax)
        $b = if ($state -eq [System.Windows.WindowState]::Normal) { [System.Windows.Rect]::new($window.Left, $window.Top, $window.ActualWidth, $window.ActualHeight) } else { $window.RestoreBounds }
        if ($b.IsEmpty -or [double]::IsNaN($b.Left) -or [double]::IsInfinity($b.Width) -or $b.Width -lt 100) { return }
        $st = $script:Settings
        $new = @{ WinLeft = [int][Math]::Round($b.Left); WinTop = [int][Math]::Round($b.Top); WinWidth = [int][Math]::Round($b.Width); WinHeight = [int][Math]::Round($b.Height); WinMax = [bool]$max }
        $changed = $false
        foreach ($k in $new.Keys) { if ([string]$st[$k] -ne [string]$new[$k]) { $st[$k] = $new[$k]; $changed = $true } }
        if ($changed) { Save-Settings }
    } catch {}
}

# ================= Eigene Titelleiste =================
# Das Fenster hat keine Windows-Titelleiste mehr (WindowChrome im XAML); Ziehen, Doppelklick,
# Andocken und Groessenaenderung uebernimmt weiterhin Windows. Hier nur die drei Knoepfe.
function Update-WindowChromeState {
    $max = ($window.WindowState -eq [System.Windows.WindowState]::Maximized)
    if ($window.WindowState -ne [System.Windows.WindowState]::Minimized) { $script:WinWasMax = $max }
    # Maximiert ragt ein Fenster ohne eigene Titelleiste um den Rahmen ueber den Bildschirm hinaus -> Rand ausgleichen
    $ui.RootGrid.Margin = if ($max) { [System.Windows.Thickness]::new(8) } else { [System.Windows.Thickness]::new(0) }
    $ui.BtnWinMax.Tag = [string][char]$(if ($max) { 0xE923 } else { 0xE922 })
}
$ui.BtnWinMin.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized })
$ui.BtnWinMax.Add_Click({
    $window.WindowState = if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) { [System.Windows.WindowState]::Normal } else { [System.Windows.WindowState]::Maximized }
})
$ui.BtnWinClose.Add_Click({ $window.Close() })
$window.Add_StateChanged({ try { Update-WindowChromeState } catch {} })

# --- Installation darf nicht mittendrin durch Schliessen unterbrochen werden
$window.Add_Closing({
    param($s, $e)
    if ($script:Busy -and ($script:BusyKind -eq "install" -or $script:BusyKind -eq "restore")) {
        $e.Cancel = $true
        Show-Msg (T "MsgBusyClose") "Information"
    } elseif ($script:FwWorker -or ($script:ContentWorker -and $contentSync.Args.Mode -eq "add") -or ($script:SavesWorker -and $savesSync.Args.Mode -eq "restore")) {
        $e.Cancel = $true
        Show-Msg (T "MsgBusyClose") "Information"
    }
    if (-not $e.Cancel) { Save-WindowPlacement }
})

# Erster Start: Eden-Ordner abfragen (Vorschlag: Ordner des Updaters)
function Invoke-FirstRun {
    $dir = [string]$ScriptDir
    $ans = Show-Dialog (TF "FirstRunAsk" $dir) "YesNo" "Question"
    if ($ans -ne "Yes") {
        try {
            $sel = Show-FolderDialog (T "SetBrowseTitle") $dir
            if ($sel) { $dir = $sel }
        } catch {}
    }
    $script:Settings.EdenPath = $dir
    Save-Settings
    Set-SettingsControls
    Update-Ui
    Add-UiLog (TF "SetStoredAt" (Get-SettingsPathFor $dir))
}

$window.Add_SourceInitialized({ Set-TitleBar $window })
