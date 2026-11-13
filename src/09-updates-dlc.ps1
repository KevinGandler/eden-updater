# ------------------------------------------------------------
#  Gemeinsame Helfer fuer Updates/DLC und Firmware
# ------------------------------------------------------------
function Format-Size([double]$b) {
    if ($b -ge 1GB) { return ("{0:N1} GB" -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ("{0:N1} MB" -f ($b / 1MB)) }
    return ("{0:N0} KB" -f [Math]::Max(1, $b / 1KB))
}

function Open-Dir([string]$dir) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Start-Process explorer.exe -ArgumentList ('"' + $dir + '"')
}

# Einen Wert aus Edens qt-config.ini lesen ([Abschnitt] Schluessel=Wert)
function Read-EdenIni([string]$cfg, [string]$section, [string]$key) {
    if (-not (Test-Path -LiteralPath $cfg)) { return $null }
    $in = $false
    foreach ($line in [IO.File]::ReadAllLines($cfg)) {
        $t = $line.Trim()
        if ($t.StartsWith("[")) { $in = ($t -eq "[$section]"); continue }
        if ($in -and $t.StartsWith($key + "=")) { return (ConvertFrom-QtIniValue $t.Substring($key.Length + 1)) }
    }
    return $null
}

# Ordner in [Paths] external_content_dirs eintragen (so wie Eden ihn selbst speichert).
# Rueckgabe: $true wenn neu eingetragen, $false wenn schon vorhanden.
function Register-ExternalDir([string]$cfg, [string]$dir) {
    $val  = ([IO.Path]::GetFullPath($dir).TrimEnd('\') + '\').Replace('\', '/')
    $norm = { param($x) ([string]$x).Replace('\', '/').TrimEnd('/').ToLowerInvariant() }
    $nl = "`r`n"; $bom = $false; $lines = @()
    if (Test-Path -LiteralPath $cfg) {
        $bytes = [IO.File]::ReadAllBytes($cfg)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($bom) { $text = $text.Substring(1) }
        if ($text -notmatch "`r`n") { $nl = "`n" }
        $lines = @($text -split "\r?\n")
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
    }
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($start -lt 0) { if ($t -eq "[Paths]") { $start = $i } }
        elseif ($t.StartsWith("[")) { $end = $i; break }
    }
    $found = @{}
    if ($start -ge 0) {
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i].Trim() -match '^external_content_dirs\\(\d+)\\path=(.*)$') { $found[[int]$Matches[1]] = ConvertFrom-QtIniValue $Matches[2] }
        }
    }
    $dirs = @($found.Keys | Sort-Object | ForEach-Object { $found[$_] } | Where-Object { $_ })
    foreach ($d in $dirs) { if ((& $norm $d) -eq (& $norm $val)) { return $false } }
    $dirs += $val
    $new = New-Object System.Collections.Generic.List[string]
    for ($k = 0; $k -lt $dirs.Count; $k++) { $new.Add(("external_content_dirs\{0}\path={1}" -f ($k + 1), (ConvertTo-QtIniValue $dirs[$k]))) }
    $new.Add("external_content_dirs\size=$($dirs.Count)")

    $out = New-Object System.Collections.Generic.List[string]
    if ($start -lt 0) {
        foreach ($l in $lines) { $out.Add($l) }
        while ($out.Count -gt 0 -and $out[$out.Count - 1] -eq "") { $out.RemoveAt($out.Count - 1) }
        if ($out.Count -gt 0) { $out.Add("") }
        $out.Add("[Paths]")
        foreach ($x in $new) { $out.Add($x) }
        $out.Add("")
    } else {
        for ($i = 0; $i -le $start; $i++) { $out.Add($lines[$i]) }
        $body = New-Object System.Collections.Generic.List[string]
        for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i].Trim() -notmatch '^external_content_dirs\\') { $body.Add($lines[$i]) } }
        while ($body.Count -gt 0 -and $body[$body.Count - 1].Trim() -eq "") { $body.RemoveAt($body.Count - 1) }
        foreach ($x in $body) { $out.Add($x) }
        foreach ($x in $new) { $out.Add($x) }
        if ($end -lt $lines.Count) { $out.Add("") }
        for ($i = $end; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
    }
    if (Test-Path -LiteralPath $cfg) { Copy-Item -LiteralPath $cfg -Destination ($cfg + ".eden-updater.bak") -Force }
    [IO.File]::WriteAllText($cfg, ($out -join $nl), (New-Object Text.UTF8Encoding($bom)))
    return $true
}

# Eden-Banner ("Eden laeuft") auf den neuen Seiten; nutzt die gleiche Pruefung wie der Mods-Tab
function Update-SysBanners([bool]$force = $false) {
    Update-ModsBanner $force
    $run = $script:EdenRunning
    $ui.ContentBanner.Visibility = if ($run) { "Visible" } else { "Collapsed" }
    $ui.FwBanner.Visibility      = if ($run) { "Visible" } else { "Collapsed" }
    $ui.SavesBanner.Visibility   = if ($run) { "Visible" } else { "Collapsed" }
    $savesFree = -not $run -and -not $script:SavesWorker
    $ui.BtnSaveBackup.IsEnabled   = $savesFree -and $script:SaveSelHas
    $ui.BtnShaderDelete.IsEnabled = $savesFree -and $script:ShaderSelHas
    $ui.BtnShaderAll.IsEnabled    = $savesFree -and $script:ShaderTotal -gt 0
    $ui.ListSaveBackups.IsEnabled = $savesFree
    $ui.ListContent.IsEnabled    = -not $run
    $ui.BtnContentAdd.IsEnabled  = [bool]($ui.ListContentGames.SelectedItem) -and -not $run -and -not $script:ContentWorker
    $fwFree = -not $run -and -not $script:FwWorker
    $ui.BtnFwZip.IsEnabled    = $fwFree
    $ui.BtnFwDir.IsEnabled    = $fwFree
    $ui.BtnFwDelete.IsEnabled = $fwFree -and $script:FwHas
}

# ------------------------------------------------------------
#  Updates/DLC-Tab
# ------------------------------------------------------------
$script:Content         = @()
$script:ContentLoaded   = $false
$script:ContentWorker   = $null
$script:ContentGames    = @()

function Get-ManagedContentDir { return (Join-Path (Get-EdenDataDir) "external_content") }

function Start-ContentWorker([hashtable]$jobArgs) {
    if ($script:ContentWorker) { return }
    $contentSync.Args = $jobArgs; $contentSync.Done = $false; $contentSync.Result = $null
    $contentSync.Status = ""; $contentSync.Progress = -1
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $contentSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($jobContent.ToString())
    $script:ContentWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
    Update-SysBanners $true
}

function Start-ContentScan {
    $ui.TxtContentInfo.Text = T "ContentScanning"
    Start-ContentWorker @{
        Mode = "scan"; Config = (Get-EdenConfigPath); Managed = (Get-ManagedContentDir)
        NandReg = $(try { Join-Path (Get-NandDir) "user\Contents\registered" } catch { "" })
        KeysFile = $(try { Join-Path (Get-KeysDir) "prod.keys" } catch { "" })
    }
}

function Complete-ContentWorker {
    $w = $script:ContentWorker
    $script:ContentWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $contentSync.Result
    Update-SysBanners $true
    if (-not $r) { return }
    if (-not $r.Ok) {
        Add-UiLog ((T "ErrPrefix") + " " + $r.Error)
        if ($r.Mode -eq "add") { Show-Msg $r.Error "Error"; Start-ContentScan }
        if ($r.Mode -eq "scan") { $script:ContentLoaded = $true; Update-ContentGames }
        return
    }
    if ($r.Mode -eq "add") {
        foreach ($n in @($r.Added)) { Add-UiLog (TF "ContentAdded" $n) }
        foreach ($o in @($r.Other)) { if ($o) { Show-Msg (TF "ContentOtherGame" $o[0] $o[1]) "Information" } }
        foreach ($n in @($r.Skipped)) { Add-UiLog ((T "ErrPrefix") + " " + $n + " - " + (T "ContentUnknown") + "?") }
        Start-ContentScan
        return
    }
    $script:Content = @($r.Items)
    $script:ContentLoaded = $true
    if ($r.NandNoKeys) { Add-UiLog (T "ContentNandNoKeys") }
    # Liegen Dateien in unserem Ordner, der noch nicht in Eden eingetragen ist? Dann jetzt eintragen.
    if (-not $r.Registered -and @($script:Content | Where-Object { $_.Managed }).Count -and -not (Test-EdenRunning)) {
        try {
            $m = Get-ManagedContentDir
            if (Register-ExternalDir (Get-EdenConfigPath) $m) { Add-UiLog (TF "ContentRegistered" $m) }
        } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) }
    }
    Update-ContentGames
}

# Linke Liste: Spiele aus der Bibliothek + Spiele, fuer die Updates/DLCs gefunden wurden
function Update-ContentGames {
    $byTid = @{}
    foreach ($g in @($script:Games)) {
        if ($g.Tid -and -not $byTid.ContainsKey($g.Tid)) { $byTid[$g.Tid] = @{ Tid = $g.Tid; Name = $g.Name; IconImg = $g.IconImg } }
    }
    foreach ($c in @($script:Content)) {
        if (-not $byTid.ContainsKey($c.Base)) {
            $nm = if ($script:CacheNames.ContainsKey($c.Base)) { $script:CacheNames[$c.Base] } else { T "ModsUnknownGame" }
            $byTid[$c.Base] = @{ Tid = $c.Base; Name = $nm; IconImg = $null }
        }
    }
    $list = foreach ($e in $byTid.Values) {
        $cs = @($script:Content | Where-Object { $_.Base -eq $e.Tid })
        $nd = @($cs | Where-Object { $_.Kind -eq "dlc" }).Count
        [pscustomobject]@{
            Tid = $e.Tid; Name = $e.Name; IconImg = $e.IconImg; TileBrush = (Get-GameTileBrush $e.Name)
            Initial = $(if ($e.Name) { $e.Name.Substring(0, 1).ToUpper() } else { "?" })
            Count = $cs.Count
            Info = $(if ($cs.Count) { TF "ContentGameInfo" ($cs.Count - $nd) $nd } else { T "ContentNone" })
        }
    }
    # Spiele mit Updates/DLCs zuerst, dann alphabetisch
    $script:ContentGames = @($list | Sort-Object @{ Expression = { $_.Count -gt 0 }; Descending = $true }, Name)
    $selTid = if ($ui.ListContentGames.SelectedItem) { $ui.ListContentGames.SelectedItem.Tid } else { $null }
    $ui.ListContentGames.ItemsSource = $script:ContentGames
    if ($selTid) { $ui.ListContentGames.SelectedItem = ($script:ContentGames | Where-Object { $_.Tid -eq $selTid } | Select-Object -First 1) }
    if (-not $ui.ListContentGames.SelectedItem -and $script:ContentGames.Count) { $ui.ListContentGames.SelectedIndex = 0 }
    $allD = @($script:Content | Where-Object { $_.Kind -eq "dlc" }).Count
    if (-not $script:ContentWorker) { $ui.TxtContentInfo.Text = TF "ContentInfo" (@($script:Content).Count - $allD) $allD }
    Update-ContentList
    try { Select-WantedGame "content" $ui.ListContentGames $script:ContentGames } catch {}
}

# Rechte Liste: Updates/DLCs des gewaehlten Spiels
function Update-ContentList {
    $g = $ui.ListContentGames.SelectedItem
    Update-SysBanners
    if (-not $g) {
        $ui.TxtContentGameTitle.Text = T "ModsSelectGame"; $ui.TxtContentGameSub.Text = ""
        $ui.ListContent.ItemsSource = $null
        $ui.TxtContentEmpty.Visibility = "Collapsed"
        $ui.BtnContentAdd.IsEnabled = $false; $ui.BtnContentFolder.IsEnabled = $false
        return
    }
    $ui.TxtContentGameTitle.Text = $g.Name
    $ui.TxtContentGameSub.Text = "Title-ID " + $g.Tid
    $disabled = Read-DisabledAddOns (Get-EdenConfigPath)
    $dec = ConvertTo-TidDec $g.Tid
    $off = if ($disabled.Contains($dec)) { @($disabled[$dec]) } else { @() }
    $sorted = @($script:Content | Where-Object { $_.Base -eq $g.Tid } |
                Sort-Object @{ Expression = { if ($_.Kind -eq "update") { 0 } elseif ($_.Kind -eq "dlc") { 1 } else { 2 } } },
                            @{ Expression = { [int64]$_.Version }; Descending = $true }, @{ Expression = { $_.Tid } }, @{ Expression = { $_.Name } })
    $items = foreach ($c in $sorted) {
        $kindTxt = if ($c.Kind -eq "update") { if ($null -ne $c.Version) { TF "ContentUpdate" ("v" + $c.Version) } else { T "ContentUpdateAny" } }
                   elseif ($c.Kind -eq "dlc") { TF "ContentDlc" ([Convert]::ToInt32($c.Tid.Substring(12), 16) -band 0xFFF) }
                   else { T "ContentUnknown" }
        $title = $kindTxt
        $parts = @()
        if ($c.Kind -eq "dlc" -and $c.Name -and $c.Name -ne $g.Name) { $title = $c.Name; $parts += $kindTxt }
        elseif ($c.Kind -ne "update" -and $c.Kind -ne "dlc") { $title = $c.File }
        $parts += (Format-Size $c.Size)
        if ($c.Source -eq "game") { $parts += (T "ContentFromGameDir") }
        if ($c.Source -eq "nand") { $parts += (T "ContentFromNand") }
        if ($c.Kind -eq "dlc") { $parts += (T "ContentDlcAll") }
        $en = $true
        if ($c.Kind -eq "update" -and $c.Source -eq "nand") { $en = -not (($off -contains "Update") -or ($off -contains "Update (NAND)")) }
        elseif ($c.Kind -eq "update") { $en = -not (($off -contains "Update") -or ($null -ne $c.Version -and ($off -contains ("Update@" + $c.Version)))) }
        elseif ($c.Kind -eq "dlc") { $en = -not ($off -contains "DLC") }
        [pscustomobject]@{
            Name = $title; File = $c.File; Path = $c.Path; Paths = @($c.Paths); Source = $c.Source; Base = $c.Base; Kind = $c.Kind; Version = $c.Version
            Enabled = [bool]$en; CanToggle = ($c.Kind -eq "update" -or $c.Kind -eq "dlc")
            Info = ($parts -join "  ·  ")
        }
    }
    $ui.ListContent.ItemsSource = @($items)
    $ui.TxtContentEmpty.Text = T "ContentEmptyGame"
    $ui.TxtContentEmpty.Visibility = if (@($items).Count) { "Collapsed" } else { "Visible" }
    $ui.BtnContentAdd.IsEnabled = -not $script:EdenRunning -and -not $script:ContentWorker
    $ui.BtnContentFolder.IsEnabled = $true
}

function Open-ContentTab {
    if (-not $script:GamesLoaded) { Start-GameScan }
    if (-not $script:ContentLoaded) { Start-ContentScan } else { Update-ContentGames }
    Update-SysBanners $true
}

# Schalter: Eden merkt sich deaktivierte Updates als "Update@<Version>" (alle: "Update"), DLCs nur gesamt als "DLC"
function Set-ContentEnabled($item, [bool]$on) {
    Update-SysBanners $true
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; Update-ContentList; return }
    try {
        $cfg = Get-EdenConfigPath
        $map = Read-DisabledAddOns $cfg
        $dec = ConvertTo-TidDec $item.Base
        if (-not $map.Contains($dec)) { $map[$dec] = New-Object System.Collections.Generic.List[string] }
        $list = $map[$dec]
        $key = if ($item.Kind -eq "dlc") { "DLC" } elseif ($item.Source -eq "nand") { "Update (NAND)" } elseif ($null -ne $item.Version) { "Update@" + $item.Version } else { "Update" }
        if ($on) {
            if ($item.Kind -eq "update" -and $list.Contains("Update") -and $key -ne "Update") {
                # "Update" sperrt alle Versionen: die anderen einzeln gesperrt lassen
                foreach ($c in @($script:Content | Where-Object { $_.Base -eq $item.Base -and $_.Kind -eq "update" -and ($null -ne $_.Version -or $_.Source -eq "nand") })) {
                    $k2 = if ($c.Source -eq "nand") { "Update (NAND)" } else { "Update@" + $c.Version }
                    if ($k2 -ne $key -and -not $list.Contains($k2)) { $list.Add($k2) }
                }
                [void]$list.RemoveAll([Predicate[string]]{ param($x) $x -eq "Update" })
            }
            [void]$list.RemoveAll([Predicate[string]]{ param($x) $x -eq $key })
        } elseif (-not $list.Contains($key)) {
            $list.Add($key)
        }
        Write-DisabledAddOns $cfg $map
        Add-UiLog (TF $(if ($on) { "ContentToggledOn" } else { "ContentToggledOff" }) $item.Name)
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Update-ContentGames
}

function Remove-ContentItem($item) {
    Update-SysBanners $true
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; return }
    $label = if ($item.Source -eq "nand") { $item.Name } else { $item.File }
    if ((Show-Dialog (TF "ContentAskDelete" $label) "YesNo" "Question") -ne "Yes") { return }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $del = if ($item.Source -eq "nand" -and @($item.Paths).Count) { @($item.Paths) } else { @($item.Path) }
        foreach ($d in $del) {
            if (Test-Path -LiteralPath $d -PathType Container) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($d, "OnlyErrorDialogs", "SendToRecycleBin") }
            elseif (Test-Path -LiteralPath $d) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($d, "OnlyErrorDialogs", "SendToRecycleBin") }
        }
        if ($item.Kind -eq "update" -and $item.Source -ne "nand" -and $null -ne $item.Version) {
            $cfg = Get-EdenConfigPath
            $map = Read-DisabledAddOns $cfg
            $dec = ConvertTo-TidDec $item.Base
            $k = "Update@" + $item.Version
            if ($map.Contains($dec) -and $map[$dec].Contains($k)) { [void]$map[$dec].Remove($k); Write-DisabledAddOns $cfg $map }
        }
        Add-UiLog (TF "ContentDeleted" $label)
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Start-ContentScan
}

function Add-ContentFiles {
    $g = $ui.ListContentGames.SelectedItem
    if (-not $g -or $script:ContentWorker) { return }
    Update-SysBanners $true
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; return }
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title  = T "ContentAdd"
    $dlg.Filter = "Switch (*.nsp;*.nsz;*.xci;*.xcz)|*.nsp;*.nsz;*.xci;*.xcz"
    $dlg.Multiselect = $true
    if (-not $dlg.ShowDialog($window)) { return }
    $managed = Get-ManagedContentDir
    try {
        New-Item -ItemType Directory -Path $managed -Force | Out-Null
        if (Register-ExternalDir (Get-EdenConfigPath) $managed) { Add-UiLog (TF "ContentRegistered" $managed) }
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
        return
    }
    $ui.TxtContentInfo.Text = TF "ContentCopying" ([IO.Path]::GetFileName($dlg.FileNames[0]))
    Start-ContentWorker @{ Mode = "add"; Files = @($dlg.FileNames); Managed = $managed; Base = $g.Tid }
}

function Open-ContentFolder {
    $g = $ui.ListContentGames.SelectedItem
    if (-not $g) { return }
    Open-Dir (Join-Path (Get-ManagedContentDir) $g.Tid)
}

