# ------------------------------------------------------------
#  Mods-Tab
# ------------------------------------------------------------
$script:Mods         = @()
$script:ModsLoaded   = $false
$script:ModWorker    = $null
$script:CacheNames   = @{}
$script:ModGames     = @()
$script:EdenRunning  = $false
$script:EdenCheckAt  = [DateTime]::MinValue

# Eden-Datenordner: portabel (<Eden>\user) oder %APPDATA%\eden
function Get-EdenDataDir {
    $u = Join-Path $script:Settings.EdenPath "user"
    if (Test-Path -LiteralPath $u) { return $u }
    if ($env:APPDATA) { return (Join-Path $env:APPDATA "eden") }
    return $u
}
function Get-EdenConfigPath { return (Join-Path (Get-EdenDataDir) "config\qt-config.ini") }

function Test-EdenRunning {
    try { return [bool](Get-Process -Name "eden" -ErrorAction SilentlyContinue) } catch { return $false }
}

# Werte in Edens qt-config.ini sind im QSettings-Format: Texte mit , ; = oder Leerzeichen am Rand stehen in
# Anfuehrungszeichen, \ und " sind mit \ maskiert. Ohne das gehen z.B. Mod-Namen mit Komma kaputt.
function ConvertFrom-QtIniValue([string]$v) {
    if ($null -eq $v) { return "" }
    $v = $v.Trim()
    if ($v.IndexOf('"') -lt 0 -and $v.IndexOf('\') -lt 0) { return $v }
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $v.Length; $i++) {
        $c = $v[$i]
        if ($c -eq '"') { continue }
        if ($c -eq '\' -and $i + 1 -lt $v.Length) {
            $i++
            $n = [string]$v[$i]
            if ($n -ceq 'n') { [void]$sb.Append("`n") }
            elseif ($n -ceq 't') { [void]$sb.Append("`t") }
            elseif ($n -ceq 'r') { [void]$sb.Append("`r") }
            elseif ($n -ceq '0') { [void]$sb.Append([char]0) }
            elseif ($n -ceq 'x') {
                $hex = ""
                while ($i + 1 -lt $v.Length -and $hex.Length -lt 4 -and [string]$v[$i + 1] -match '^[0-9a-fA-F]$') { $i++; $hex += $v[$i] }
                if ($hex) { [void]$sb.Append([char][Convert]::ToInt32($hex, 16)) }
            }
            else { [void]$sb.Append($n) }
            continue
        }
        [void]$sb.Append($c)
    }
    return $sb.ToString()
}

function ConvertTo-QtIniValue([string]$v) {
    $sb = New-Object System.Text.StringBuilder
    $quote = $false
    foreach ($c in $v.ToCharArray()) {
        if ($c -eq ';' -or $c -eq ',' -or $c -eq '=') { $quote = $true }
        if ($c -eq '\' -or $c -eq '"') { [void]$sb.Append('\').Append($c) }
        elseif ([int]$c -lt 0x20) { [void]$sb.Append(("\x{0:x}" -f [int]$c)) }
        else { [void]$sb.Append($c) }
    }
    $r = $sb.ToString()
    if ($quote -or $r.StartsWith(' ') -or $r.EndsWith(' ')) { $r = '"' + $r + '"' }
    return $r
}

# [DisabledAddOns] aus Edens qt-config.ini lesen: TitleID (dezimal) -> Liste deaktivierter Namen
function Read-DisabledAddOns([string]$cfg) {
    $map = [ordered]@{}
    if (-not (Test-Path -LiteralPath $cfg)) { return $map }
    $in = $false; $tids = @{}; $lists = @{}
    foreach ($line in [IO.File]::ReadAllLines($cfg)) {
        $t = $line.Trim()
        if ($t.StartsWith("[")) { $in = ($t -eq "[DisabledAddOns]"); continue }
        if (-not $in) { continue }
        if ($t -match '^(\d+)\\title_id=(\d+)$') { $tids[$Matches[1]] = $Matches[2]; continue }
        if ($t -match '^(\d+)\\disabled\\(\d+)\\d=(.*)$') {
            if (-not $lists.ContainsKey($Matches[1])) { $lists[$Matches[1]] = New-Object System.Collections.Generic.List[string] }
            $lists[$Matches[1]].Add((ConvertFrom-QtIniValue $Matches[3]))
        }
    }
    foreach ($i in ($tids.Keys | Sort-Object { [int]$_ })) {
        # gleiche Title-ID mehrfach (kommt vor): Listen zusammenfuehren
        if ($map.Contains($tids[$i])) { $l = $map[$tids[$i]] } else { $l = New-Object System.Collections.Generic.List[string] }
        if ($lists.ContainsKey($i)) { foreach ($x in $lists[$i]) { if ($x -and -not $l.Contains($x)) { $l.Add($x) } } }
        $map[$tids[$i]] = $l
    }
    return $map
}

# [DisabledAddOns] im gleichen Format wie Eden zurueckschreiben (Rest der Datei bleibt unveraendert)
function Write-DisabledAddOns([string]$cfg, $map) {
    $sec = New-Object System.Collections.Generic.List[string]
    $sec.Add("[DisabledAddOns]")
    $i = 0
    foreach ($tid in $map.Keys) {
        $list = $map[$tid]
        if (-not $list -or $list.Count -eq 0) { continue }
        $i++
        $sec.Add("$i\title_id\default=false")
        $sec.Add("$i\title_id=$tid")
        $j = 0
        foreach ($d in $list) {
            $j++
            $sec.Add("$i\disabled\$j\d\default=false")
            $sec.Add("$i\disabled\$j\d=" + (ConvertTo-QtIniValue ($d.Replace('\', '/'))))
        }
        $sec.Add("$i\disabled\size=$j")
    }
    $sec.Add("size=$i")

    $nl = "`r`n"; $bom = $false; $lines = @()
    if (Test-Path -LiteralPath $cfg) {
        $bytes = [IO.File]::ReadAllBytes($cfg)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($bom) { $text = $text.Substring(1) }
        if ($text -notmatch "`r`n") { $nl = "`n" }
        $lines = $text -split "\r?\n"
        Copy-Item -LiteralPath $cfg -Destination ($cfg + ".eden-updater.bak") -Force   # Sicherung vor dem Schreiben
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
    }
    $out = New-Object System.Collections.Generic.List[string]
    $skip = $false; $done = $false
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t.StartsWith("[")) {
            if ($t -eq "[DisabledAddOns]") { foreach ($x in $sec) { $out.Add($x) }; $out.Add(""); $skip = $true; $done = $true; continue }
            $skip = $false
        }
        if (-not $skip) { $out.Add($line) }
    }
    if (-not $done) {
        while ($out.Count -gt 0 -and $out[$out.Count - 1] -eq "") { $out.RemoveAt($out.Count - 1) }
        if ($out.Count -gt 0) { $out.Add("") }
        foreach ($x in $sec) { $out.Add($x) }
        $out.Add("")
    }
    $enc = New-Object Text.UTF8Encoding($bom)
    [IO.File]::WriteAllText($cfg, ($out -join $nl), $enc)
}

function ConvertTo-TidDec([string]$hex) { return ([Convert]::ToUInt64($hex, 16)).ToString() }

function Start-ModWorker([hashtable]$jobArgs) {
    if ($script:ModWorker) { return }
    $modSync.Args = $jobArgs; $modSync.Done = $false; $modSync.Result = $null
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $modSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($jobMods.ToString())
    $script:ModWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

function Start-ModScan {
    $ui.TxtModsInfo.Text = T "ModsScanning"
    Start-ModWorker @{ Mode = "scan"; LoadDir = (Join-Path (Get-EdenDataDir) "load") }
}

function Complete-ModWorker {
    $w = $script:ModWorker
    $script:ModWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $modSync.Result
    if (-not $r) { return }
    if (-not $r.Ok) {
        Add-UiLog ((T "ErrPrefix") + " " + $r.Error)
        if ($r.Mode -eq "add") { Show-Msg $r.Error "Error" }
        if ($r.Mode -eq "scan") { $script:ModsLoaded = $true; Update-ModGames }
        return
    }
    if ($r.Mode -eq "add") {
        foreach ($n in @($r.Added)) { Add-UiLog (TF "ModsAdded" $n) }
        Start-ModScan
        return
    }
    $script:Mods = @($r.Mods)
    $script:ModsLoaded = $true
    Update-ModGames
}

# Linke Liste: alle Spiele aus der Bibliothek (mit Title-ID) + Spiele, fuer die Mods vorhanden sind
function Update-ModGames {
    $byTid = @{}
    foreach ($g in @($script:Games)) {
        if ($g.Tid -and -not $byTid.ContainsKey($g.Tid)) { $byTid[$g.Tid] = @{ Tid = $g.Tid; Name = $g.Name; IconImg = $g.IconImg } }
    }
    foreach ($m in @($script:Mods)) {
        if (-not $byTid.ContainsKey($m.Tid)) {
            $nm = if ($script:CacheNames.ContainsKey($m.Tid)) { $script:CacheNames[$m.Tid] } else { T "ModsUnknownGame" }
            $byTid[$m.Tid] = @{ Tid = $m.Tid; Name = $nm; IconImg = $null }
        }
    }
    $disabled = Read-DisabledAddOns (Get-EdenConfigPath)
    $list = foreach ($e in $byTid.Values) {
        $ms = @($script:Mods | Where-Object { $_.Tid -eq $e.Tid })
        $dec = ConvertTo-TidDec $e.Tid
        $off = if ($disabled.Contains($dec)) { @($disabled[$dec]) } else { @() }
        $on = @($ms | Where-Object { $off -notcontains $_.Name }).Count
        [pscustomobject]@{
            Tid = $e.Tid; Name = $e.Name; IconImg = $e.IconImg; TileBrush = (Get-GameTileBrush $e.Name)
            Initial = $(if ($e.Name) { $e.Name.Substring(0, 1).ToUpper() } else { "?" })
            Count = $ms.Count
            Info = $(if ($ms.Count) { TF "ModsGameInfo" $ms.Count $on } else { T "ModsNoMods" })
        }
    }
    # Spiele mit Mods zuerst, dann alphabetisch
    $script:ModGames = @($list | Sort-Object @{ Expression = { $_.Count -gt 0 }; Descending = $true }, Name)
    $selTid = if ($ui.ListModGames.SelectedItem) { $ui.ListModGames.SelectedItem.Tid } else { $null }
    $ui.ListModGames.ItemsSource = $script:ModGames
    if ($selTid) { $ui.ListModGames.SelectedItem = ($script:ModGames | Where-Object { $_.Tid -eq $selTid } | Select-Object -First 1) }
    if (-not $ui.ListModGames.SelectedItem -and $script:ModGames.Count) { $ui.ListModGames.SelectedIndex = 0 }
    $withMods = @($script:ModGames | Where-Object { $_.Count -gt 0 }).Count
    $ui.TxtModsInfo.Text = TF "ModsInfo" $script:Mods.Count $withMods
    Update-ModList
}

# Rechte Liste: Mods des gewaehlten Spiels
function Update-ModList {
    $g = $ui.ListModGames.SelectedItem
    Update-ModsBanner
    if (-not $g) {
        $ui.TxtModGameTitle.Text = T "ModsSelectGame"; $ui.TxtModGameSub.Text = ""
        $ui.ListMods.ItemsSource = $null
        $ui.TxtModsEmpty.Visibility = "Collapsed"
        $ui.BtnModAdd.IsEnabled = $false; $ui.BtnModFolder.IsEnabled = $false
        return
    }
    $ui.TxtModGameTitle.Text = $g.Name
    $ui.TxtModGameSub.Text = "Title-ID " + $g.Tid
    $disabled = Read-DisabledAddOns (Get-EdenConfigPath)
    $dec = ConvertTo-TidDec $g.Tid
    $off = if ($disabled.Contains($dec)) { @($disabled[$dec]) } else { @() }
    $items = foreach ($m in @($script:Mods | Where-Object { $_.Tid -eq $g.Tid } | Sort-Object { $_.Name })) {
        $sz = if ($m.Size -ge 1GB) { "{0:N1} GB" -f ($m.Size / 1GB) } elseif ($m.Size -ge 1MB) { "{0:N1} MB" -f ($m.Size / 1MB) } else { "{0:N0} KB" -f [Math]::Max(1, $m.Size / 1KB) }
        [pscustomobject]@{
            Name = $m.Name; Path = $m.Path; Tid = $m.Tid
            Enabled = ($off -notcontains $m.Name)
            Info = $(if ($m.Parts) { $sz + "  ·  " + $m.Parts } else { $sz })
        }
    }
    $ui.ListMods.ItemsSource = @($items)
    $ui.TxtModsEmpty.Text = T "ModsEmptyGame"
    $ui.TxtModsEmpty.Visibility = if (@($items).Count) { "Collapsed" } else { "Visible" }
    $ui.BtnModAdd.IsEnabled = -not $script:EdenRunning
    $ui.BtnModFolder.IsEnabled = $true
}

function Update-ModsBanner([bool]$force = $false) {
    if ($force -or ([DateTime]::Now - $script:EdenCheckAt).TotalSeconds -gt 2) {
        $script:EdenCheckAt = [DateTime]::Now
        $was = $script:EdenRunning
        $script:EdenRunning = Test-EdenRunning
        $ui.ModsBanner.Visibility = if ($script:EdenRunning) { "Visible" } else { "Collapsed" }
        $ui.ListMods.IsEnabled = -not $script:EdenRunning
        if ($ui.ListModGames.SelectedItem) { $ui.BtnModAdd.IsEnabled = -not $script:EdenRunning }
    }
}

function Open-ModsTab {
    if (-not $script:GamesLoaded) { Start-GameScan }
    if (-not $script:ModsLoaded) { Start-ModScan } else { Update-ModGames }
    Update-ModsBanner $true
}

function Set-ModEnabled($mod, [bool]$on) {
    Update-ModsBanner $true
    if ($script:EdenRunning) { Show-Msg (T "ModsEdenRunning") "Warning"; Update-ModList; return }
    try {
        $cfg = Get-EdenConfigPath
        $map = Read-DisabledAddOns $cfg
        $dec = ConvertTo-TidDec $mod.Tid
        if (-not $map.Contains($dec)) { $map[$dec] = New-Object System.Collections.Generic.List[string] }
        $list = $map[$dec]
        if ($on) { [void]$list.RemoveAll([Predicate[string]]{ param($x) $x -eq $mod.Name }) }
        elseif (-not $list.Contains($mod.Name)) { $list.Add($mod.Name) }
        Write-DisabledAddOns $cfg $map
        Add-UiLog (TF $(if ($on) { "ModsToggledOn" } else { "ModsToggledOff" }) $mod.Name)
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Update-ModGames
}

function Remove-Mod($mod) {
    Update-ModsBanner $true
    if ($script:EdenRunning) { Show-Msg (T "ModsEdenRunning") "Warning"; return }
    if ((Show-Dialog (TF "ModsAskDelete" $mod.Name) "YesNo" "Question") -ne "Yes") { return }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($mod.Path, "OnlyErrorDialogs", "SendToRecycleBin")
        # auch aus Edens Liste der deaktivierten Mods entfernen
        $cfg = Get-EdenConfigPath
        $map = Read-DisabledAddOns $cfg
        $dec = ConvertTo-TidDec $mod.Tid
        if ($map.Contains($dec) -and $map[$dec].Contains($mod.Name)) {
            [void]$map[$dec].Remove($mod.Name)
            Write-DisabledAddOns $cfg $map
        }
        Add-UiLog (TF "ModsDeleted" $mod.Name)
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Start-ModScan
}

function Add-ModFromZip {
    $g = $ui.ListModGames.SelectedItem
    if (-not $g) { return }
    Update-ModsBanner $true
    if ($script:EdenRunning) { Show-Msg (T "ModsEdenRunning") "Warning"; return }
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title  = T "ModsAdd"
    $dlg.Filter = "ZIP (*.zip)|*.zip"
    $dlg.Multiselect = $false
    if (-not $dlg.ShowDialog($window)) { return }
    $ui.TxtModsInfo.Text = T "ModsInstalling"
    Start-ModWorker @{ Mode = "add"; LoadDir = (Join-Path (Get-EdenDataDir) "load"); Tid = $g.Tid; Zip = $dlg.FileName }
}

function Open-ModFolder {
    $g = $ui.ListModGames.SelectedItem
    if (-not $g) { return }
    $dir = Join-Path (Join-Path (Get-EdenDataDir) "load") $g.Tid
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Start-Process explorer.exe -ArgumentList ('"' + $dir + '"')
}

