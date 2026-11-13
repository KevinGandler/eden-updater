# ------------------------------------------------------------
#  Spieldaten: Spielstaende sichern/wiederherstellen, Shader-Cache
# ------------------------------------------------------------
$script:SaveData     = $null
$script:SavesLoaded  = $false
$script:SavesWorker  = $null
$script:SaveGames    = @()
$script:SaveSelHas   = $false
$script:ShaderSelHas = $false
$script:ShaderTotal  = 0L
$script:SavesPendingMsg = ""

function Get-SaveRoot { return (Join-Path (Get-NandDir) "user\save") }
function Get-ShaderRoot { return (Join-Path (Get-EdenDataDir) "cache\shader") }
function Get-SaveBackupDir { return (Join-Path (Get-EdenDataDir) "save-backups") }

function Start-SavesWorker([hashtable]$jobArgs) {
    if ($script:SavesWorker) { return }
    $savesSync.Args = $jobArgs; $savesSync.Done = $false; $savesSync.Result = $null
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $savesSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($saveLib.ToString() + "`n" + $jobSaves.ToString())
    $script:SavesWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
    if ($jobArgs.Mode -ne "scan") { $ui.TxtSavesInfo.Text = T "SavesWorking" }
    Update-SysBanners $true
}

function Start-SavesScan {
    $ui.TxtSavesInfo.Text = T "SavesScanning"
    Start-SavesWorker @{ Mode = "scan"; Root = (Get-SaveRoot); ShaderRoot = (Get-ShaderRoot); BackupDir = (Get-SaveBackupDir) }
}

function Complete-SavesWorker {
    $w = $script:SavesWorker
    $script:SavesWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $savesSync.Result
    if (-not $r) { Update-SysBanners $true; return }
    if (-not $r.Ok) {
        Add-UiLog ((T "ErrPrefix") + " " + $r.Error)
        if ($r.Mode -ne "scan") { Show-Msg ((T "ErrPrefix") + " " + $r.Error) "Error"; Start-SavesScan }
        else { $script:SavesLoaded = $true; Update-SaveGames }
        return
    }
    if ($r.Mode -ne "scan") {
        if ($r.Mode -eq "backup" -and -not $r.Path) { Show-Msg (T "SavesNothing") "Information" }
        elseif ($script:SavesPendingMsg) { Add-UiLog $script:SavesPendingMsg }
        $script:SavesPendingMsg = ""
        Start-SavesScan
        return
    }
    $script:SaveData = @{ Saves = @($r.Saves); Shaders = $r.Shaders; Backups = @($r.Backups) }
    $script:SavesLoaded = $true
    Update-SaveGames
}

function Get-SaveGameName([string]$tid) {
    foreach ($g in @($script:Games)) { if ($g.Tid -eq $tid) { return $g.Name } }
    if ($script:CacheNames.ContainsKey($tid)) { return $script:CacheNames[$tid] }
    return (T "ModsUnknownGame")
}

function Update-SaveGames {
    $d = $script:SaveData
    if (-not $d) { $d = @{ Saves = @(); Shaders = @{}; Backups = @() } }
    $tids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($g in @($script:Games)) { if ($g.Tid) { [void]$tids.Add($g.Tid) } }
    foreach ($x in @($d.Saves)) { [void]$tids.Add($x.Tid) }
    foreach ($k in @($d.Shaders.Keys)) { [void]$tids.Add($k) }
    foreach ($x in @($d.Backups)) { [void]$tids.Add($x.Tid) }
    $icons = @{}
    foreach ($g in @($script:Games)) { if ($g.Tid -and -not $icons.ContainsKey($g.Tid)) { $icons[$g.Tid] = $g.IconImg } }
    $list = foreach ($tid in $tids) {
        $sv = @($d.Saves | Where-Object { $_.Tid -eq $tid -and $_.Files }) | Select-Object -First 1
        $sh = $d.Shaders[$tid]
        $nb = @($d.Backups | Where-Object { $_.Tid -eq $tid }).Count
        $name = Get-SaveGameName $tid
        $parts = @()
        $parts += $(if ($sv) { TF "SavesGameSave" (Format-Size $sv.Size) } else { T "SavesGameNoSave" })
        if ($sh -and $sh.Size) { $parts += (TF "SavesGameShader" (Format-Size $sh.Size)) }
        if ($nb) { $parts += (TF "SavesGameBackups" $nb) }
        [pscustomobject]@{
            Tid = $tid; Name = $name; IconImg = $icons[$tid]; TileBrush = (Get-GameTileBrush $name)
            Initial = $(if ($name) { $name.Substring(0, 1).ToUpper() } else { "?" })
            HasSave = [bool]$sv
            Info = ($parts -join " · ")
        }
    }
    $script:SaveGames = @($list | Sort-Object @{ Expression = { $_.HasSave }; Descending = $true }, Name)
    $selTid = if ($ui.ListSaveGames.SelectedItem) { $ui.ListSaveGames.SelectedItem.Tid } else { $null }
    $ui.ListSaveGames.ItemsSource = $script:SaveGames
    if ($selTid) { $ui.ListSaveGames.SelectedItem = ($script:SaveGames | Where-Object { $_.Tid -eq $selTid } | Select-Object -First 1) }
    if (-not $ui.ListSaveGames.SelectedItem -and $script:SaveGames.Count) { $ui.ListSaveGames.SelectedIndex = 0 }
    $script:ShaderTotal = 0L
    foreach ($k in @($d.Shaders.Keys)) { $script:ShaderTotal += [int64]$d.Shaders[$k].Size }
    if (-not $script:SavesWorker) {
        $ui.TxtSavesInfo.Text = TF "SavesInfo" (@($d.Saves | Where-Object { $_.Files }).Count) (@($d.Backups).Count) (Format-Size $script:ShaderTotal)
    }
    Update-SaveDetail
    try { Select-WantedGame "saves" $ui.ListSaveGames $script:SaveGames } catch {}
}

function Get-SelectedSaveInfo {
    $g = $ui.ListSaveGames.SelectedItem
    if (-not $g -or -not $script:SaveData) { return $null }
    return @{
        Game    = $g
        Save    = (@($script:SaveData.Saves | Where-Object { $_.Tid -eq $g.Tid }) | Select-Object -First 1)
        Shader  = $script:SaveData.Shaders[$g.Tid]
        Backups = @($script:SaveData.Backups | Where-Object { $_.Tid -eq $g.Tid } | Sort-Object { $_.Time } -Descending)
    }
}

function Update-SaveDetail {
    $i = Get-SelectedSaveInfo
    if (-not $i) {
        $ui.TxtSaveGameTitle.Text = T "ModsSelectGame"; $ui.TxtSaveGameSub.Text = ""
        $ui.TxtSaveState.Text = ""; $ui.TxtShaderState.Text = ""
        $ui.ListSaveBackups.ItemsSource = $null
        $ui.TxtSaveBackupsEmpty.Visibility = "Collapsed"
        $script:SaveSelHas = $false; $script:ShaderSelHas = $false
        $ui.BtnSaveFolder.IsEnabled = $false
        Update-SysBanners
        return
    }
    $ui.TxtSaveGameTitle.Text = $i.Game.Name
    $ui.TxtSaveGameSub.Text = "Title-ID " + $i.Game.Tid
    $script:SaveSelHas = [bool]($i.Save -and $i.Save.Files)
    $ui.TxtSaveState.Text = (T "SavesSaveTitle") + "  ·  " + $(if ($script:SaveSelHas) {
        TF "SavesSaveInfo" (Format-Size $i.Save.Size) ($i.Save.Newest.ToLocalTime().ToString("g", $script:CI))
    } else { T "SavesSaveNone" })
    $ui.TxtSaveState.ToolTip = $ui.TxtSaveState.Text
    $ui.BtnSaveFolder.IsEnabled = [bool]($i.Save -and @($i.Save.Dirs).Count)
    $script:ShaderSelHas = [bool]($i.Shader -and $i.Shader.Size)
    $ui.TxtShaderState.Text = if ($script:ShaderSelHas) { (T "SavesShaderTitle") + "  ·  " + (Format-Size $i.Shader.Size) } else { T "SavesShaderNone" }
    $reasons = @{ manual = (T "SavesReasonManual"); auto = (T "SavesReasonAuto"); restore = (T "SavesReasonRestore") }
    $items = foreach ($b in $i.Backups) {
        [pscustomobject]@{
            Name = $b.Time.ToString("g", $script:CI)
            Info = $reasons[[string]$b.Reason] + "  ·  " + (Format-Size $b.Size)
            Path = $b.Path; File = $b.File; Tid = $b.Tid
        }
    }
    $ui.ListSaveBackups.ItemsSource = @($items)
    $ui.TxtSaveBackupsEmpty.Text = T "SavesBackupsEmpty"
    $ui.TxtSaveBackupsEmpty.Visibility = if (@($items).Count) { "Collapsed" } else { "Visible" }
    Update-SysBanners
}

function Open-SavesTab {
    if (-not $script:GamesLoaded) { Start-GameScan }
    if (-not $script:SavesLoaded) { Start-SavesScan } else { Update-SaveGames }
    Update-SysBanners $true
}

function Test-SavesBlocked {
    Update-SysBanners $true
    if ($script:SavesWorker) { return $true }
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; return $true }
    return $false
}

function Invoke-SaveBackup {
    $i = Get-SelectedSaveInfo
    if (-not $i -or (Test-SavesBlocked)) { return }
    if (-not $i.Save -or -not $i.Save.Files) { Show-Msg (T "SavesNothing") "Information"; return }
    $script:SavesPendingMsg = TF "SavesBackupDone" $i.Game.Name
    Start-SavesWorker @{ Mode = "backup"; Root = (Get-SaveRoot); Tid = $i.Game.Tid; Dirs = @($i.Save.Dirs); BackupDir = (Get-SaveBackupDir) }
}

function Invoke-SaveRestore($item) {
    $i = Get-SelectedSaveInfo
    if (-not $i -or (Test-SavesBlocked)) { return }
    if ((Show-Dialog (TF "SavesAskRestore" $item.Name) "YesNo" "Question") -ne "Yes") { return }
    $dirs = if ($i.Save) { @($i.Save.Dirs) } else { @() }
    $script:SavesPendingMsg = TF "SavesRestored" ($i.Game.Name + " (" + $item.Name + ")")
    Start-SavesWorker @{ Mode = "restore"; Root = (Get-SaveRoot); Tid = $item.Tid; Zip = $item.Path; Dirs = $dirs; BackupDir = (Get-SaveBackupDir) }
}

function Remove-SaveBackupItem($item) {
    if ($script:SavesWorker) { return }
    if ((Show-Dialog (TF "SavesAskDelete" $item.Name) "YesNo" "Question") -ne "Yes") { return }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.Path, "OnlyErrorDialogs", "SendToRecycleBin")
        Add-UiLog (TF "SavesDeleted" $item.Name)
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Start-SavesScan
}

function Remove-ShaderCache([bool]$all) {
    if (Test-SavesBlocked) { return }
    if ($all) {
        if ($script:ShaderTotal -le 0) { return }
        if ((Show-Dialog (TF "SavesAskShaderAll" (Format-Size $script:ShaderTotal)) "YesNo" "Question") -ne "Yes") { return }
        $dirs = @(foreach ($k in @($script:SaveData.Shaders.Keys)) { $script:SaveData.Shaders[$k].Path })
        $script:SavesPendingMsg = TF "SavesShaderDeleted" (Format-Size $script:ShaderTotal)
    } else {
        $i = Get-SelectedSaveInfo
        if (-not $i -or -not $i.Shader) { return }
        if ((Show-Dialog (TF "SavesAskShader" $i.Game.Name (Format-Size $i.Shader.Size)) "YesNo" "Question") -ne "Yes") { return }
        $dirs = @($i.Shader.Path)
        $script:SavesPendingMsg = TF "SavesShaderDeleted" $i.Game.Name
    }
    Start-SavesWorker @{ Mode = "shader"; Dirs = $dirs }
}

function Open-SaveFolder {
    $i = Get-SelectedSaveInfo
    if ($i -and $i.Save -and @($i.Save.Dirs).Count) { Open-Dir ([string]@($i.Save.Dirs)[0]) }
}

