# ------------------------------------------------------------
#  Firmware & Schluessel
# ------------------------------------------------------------
# Master-Key-Generation -> erste Firmware, die sie braucht (Index = Generation)
$KeyGenFirmware = @("1.0.0", "3.0.0", "3.0.1", "4.0.0", "5.0.0", "6.0.0", "6.2.0", "7.0.0", "8.1.0", "9.0.0", "9.1.0",
                    "12.1.0", "13.0.0", "14.0.0", "15.0.0", "16.0.0", "17.0.0", "18.0.0", "19.0.0", "20.0.0", "21.0.0")
$script:FwWorker = $null
$script:FwHas    = $false
$script:FwPendingVersion = ""

# NAND-Ordner: Edens Einstellung [Data Storage] nand_directory, sonst <Eden-Daten>\nand
function Get-NandDir {
    $v = Read-EdenIni (Get-EdenConfigPath) "Data%20Storage" "nand_directory"
    if ($v) { return $v.Replace('/', '\').TrimEnd('\') }
    return (Join-Path (Get-EdenDataDir) "nand")
}
function Get-FirmwareDir { return (Join-Path (Get-NandDir) "system\Contents\registered") }
function Get-KeysDir { return (Join-Path (Get-EdenDataDir) "keys") }

function Get-FirmwareInfo {
    $dir = Get-FirmwareDir
    $r = @{ Dir = $dir; Count = 0; Size = 0L; Version = $null }
    if (-not (Test-Path -LiteralPath $dir)) { return $r }
    foreach ($e in Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue) {
        if ($e.Name -notmatch '(?i)\.nca$') { continue }
        $r.Count++
        if ($e.PSIsContainer) { foreach ($f in Get-ChildItem -LiteralPath $e.FullName -File -Recurse -Force -ErrorAction SilentlyContinue) { $r.Size += $f.Length } }
        else { $r.Size += $e.Length }
    }
    if ($r.Count -eq 0) { return $r }
    # Version: Eden schreibt beim Start "Installed firmware: x.y.z" ins Log. Gilt nur, wenn das Log neuer ist als die Firmware.
    $log = Join-Path (Get-EdenDataDir) "log\eden_log.txt"
    try {
        if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).LastWriteTime -gt (Get-Item -LiteralPath $dir).LastWriteTime) {
            $fs = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
            try { $txt = (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Close() }
            $m = [regex]::Matches($txt, 'Installed firmware: (\d+\.\d+\.\d+)')
            if ($m.Count) { $r.Version = $m[$m.Count - 1].Groups[1].Value }
        }
    } catch {}
    if (-not $r.Version -and $script:Settings.FirmwareVersion) { $r.Version = [string]$script:Settings.FirmwareVersion }
    return $r
}

function Get-KeysInfo {
    $d = Get-KeysDir
    $r = @{ Dir = $d; Prod = $false; Count = 0; Gen = -1; Title = -1 }
    $p = Join-Path $d "prod.keys"
    if (Test-Path -LiteralPath $p) {
        $r.Prod = $true
        foreach ($line in [IO.File]::ReadAllLines($p)) {
            if ($line -notmatch '^\s*([A-Za-z0-9_]+)\s*=\s*[0-9A-Fa-f]+') { continue }
            $name = $Matches[1]
            $r.Count++
            if ($name -match '^master_key_([0-9a-fA-F]{2})$') { $g = [Convert]::ToInt32($Matches[1], 16); if ($g -gt $r.Gen) { $r.Gen = $g } }
        }
    }
    $t = Join-Path $d "title.keys"
    if (Test-Path -LiteralPath $t) { $r.Title = @([IO.File]::ReadAllLines($t) | Where-Object { $_ -match '^\s*[0-9A-Fa-f]{32}\s*=' }).Count }
    return $r
}

# Mindestens benoetigte Master-Key-Generation fuer eine Firmware-Version
function Get-FwRequiredGen([string]$ver) {
    try { $v = [version]$ver } catch { return -1 }
    $g = -1
    for ($i = 0; $i -lt $KeyGenFirmware.Count; $i++) { if ([version]$KeyGenFirmware[$i] -le $v) { $g = $i } }
    return $g
}

function Update-FirmwarePage {
    $fw = Get-FirmwareInfo
    $k  = Get-KeysInfo
    $script:FwHas = ($fw.Count -gt 0)
    if (-not $script:FwWorker) {
        if ($fw.Count) {
            $ui.TxtFwState.Text = if ($fw.Version) { TF "FwVersion" $fw.Version } else { T "FwVersionUnknown" }
            $ui.TxtFwSub.Text   = TF "FwFiles" $fw.Count (Format-Size $fw.Size)
        } else {
            $ui.TxtFwState.Text = T "FwNone"
            $ui.TxtFwSub.Text   = $fw.Dir
        }
    }
    if ($k.Prod) {
        $ui.TxtKeysState.Text = TF "KeysInstalled" $k.Count
        $parts = @()
        if ($k.Gen -ge 0) {
            $gx = "0x{0:X2}" -f $k.Gen
            $parts += $(if ($k.Gen -lt $KeyGenFirmware.Count) { TF "KeysGen" $gx $KeyGenFirmware[$k.Gen] } else { TF "KeysGenRaw" $gx })
        }
        if ($k.Title -ge 0) { $parts += (TF "KeysTitleKeys" $k.Title) }
        $ui.TxtKeysSub.Text = ($parts -join "  ·  ")
    } else {
        $ui.TxtKeysState.Text = T "KeysNone"
        $ui.TxtKeysSub.Text   = $k.Dir
    }
    $ui.BtnKeysDelete.IsEnabled = $k.Prod
    # Warnung: Firmware ohne Keys oder Keys aelter als die Firmware
    $warn = $null
    if ($fw.Count -and -not $k.Prod) { $warn = T "KeysMissingForFw" }
    elseif ($fw.Count -and $fw.Version -and $k.Gen -ge 0 -and $k.Gen -lt $KeyGenFirmware.Count) {
        if ((Get-FwRequiredGen $fw.Version) -gt $k.Gen) { $warn = TF "FwKeysTooOld" $KeyGenFirmware[$k.Gen] }
    }
    $ui.TxtFwWarn.Text = [string]$warn
    $ui.FwWarn.Visibility = if ($warn) { "Visible" } else { "Collapsed" }
    Update-SysBanners $true
}

function Start-FwWorker([hashtable]$jobArgs) {
    if ($script:FwWorker) { return }
    $fwSync.Args = $jobArgs; $fwSync.Done = $false; $fwSync.Result = $null; $fwSync.Cur = 0; $fwSync.Total = 0
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $fwSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($jobFirmware.ToString())
    $script:FwWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
    $ui.TxtFwSub.Text = T "FwPreparing"
    Update-SysBanners $true
}

function Complete-FwWorker {
    $w = $script:FwWorker
    $script:FwWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $fwSync.Result
    if ($r -and $r.Ok) {
        if ($r.Mode -eq "install") {
            $script:Settings.FirmwareVersion = $script:FwPendingVersion
            Add-UiLog (TF "FwDone" $r.Count)
        } else {
            $script:Settings.FirmwareVersion = ""
            Add-UiLog (T "FwDeleted")
        }
        try { Save-Settings } catch {}
    } elseif ($r) {
        if ($r.Error -eq "nonca") { Show-Msg (T "FwNoNca") "Warning" }
        else { Add-UiLog ((T "ErrPrefix") + " " + $r.Error); Show-Msg ((T "ErrPrefix") + " " + $r.Error) "Error" }
    }
    Update-FirmwarePage
}

function Install-Firmware([bool]$fromZip) {
    if ($script:FwWorker) { return }
    Update-SysBanners $true
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; return }
    $src = $null
    if ($fromZip) {
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title  = T "FwInstallZip"
        $dlg.Filter = "ZIP (*.zip)|*.zip"
        if (-not $dlg.ShowDialog($window)) { return }
        $src = $dlg.FileName
    } else {
        $src = Show-FolderDialog (T "FwInstallDir") ""
        if (-not $src) { return }
    }
    $fw = Get-FirmwareInfo
    if ($fw.Count) {
        $v = if ($fw.Version) { $fw.Version } else { "?" }
        if ((Show-Dialog (TF "FwAskReplace" $v) "YesNo" "Question") -ne "Yes") { return }
    }
    # Version aus dem Namen merken (z.B. "Firmware 20.1.0.zip")
    $m = [regex]::Match([IO.Path]::GetFileName($src.TrimEnd('\')), '(?<![\d.])(\d{1,2}\.\d{1,2}\.\d{1,2})(?![\d.])')
    $script:FwPendingVersion = if ($m.Success) { $m.Groups[1].Value } else { "" }
    Start-FwWorker @{ Mode = "install"; Source = $src; Zip = $fromZip; Target = $fw.Dir }
}

function Remove-Firmware {
    if ($script:FwWorker) { return }
    Update-SysBanners $true
    if ($script:EdenRunning) { Show-Msg (T "SysEdenRunning") "Warning"; return }
    if ((Show-Dialog (T "FwAskDelete") "YesNo" "Warning") -ne "Yes") { return }
    Start-FwWorker @{ Mode = "delete"; Target = (Get-FirmwareDir) }
}

# Wie Eden: prod.keys + (falls vorhanden) title.keys und key_retail.bin aus demselben Ordner kopieren
function Install-Keys {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title  = T "KeysInstall"
    $dlg.Filter = "prod.keys (*.keys)|*.keys|* (*.*)|*.*"
    if (-not $dlg.ShowDialog($window)) { return }
    $src = $dlg.FileName
    try {
        $txt = [IO.File]::ReadAllText($src)
        if ($txt -notmatch '(?m)^\s*(header_key|master_key_[0-9a-fA-F]{2}|key_area_key_application_[0-9a-fA-F]{2})\s*=\s*[0-9A-Fa-f]{32}') {
            Show-Msg (T "KeysInvalid") "Warning"; return
        }
        $d = Get-KeysDir
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        $same = { param($x, $y) [IO.Path]::GetFullPath($x).TrimEnd('\') -ieq [IO.Path]::GetFullPath($y).TrimEnd('\') }
        $dst = Join-Path $d "prod.keys"
        if (-not (& $same $src $dst)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        $srcDir = Split-Path -Parent $src
        if (-not (& $same $srcDir $d)) {
            foreach ($n in @("title.keys", "key_retail.bin")) {
                $f = Join-Path $srcDir $n
                if (Test-Path -LiteralPath $f) { Copy-Item -LiteralPath $f -Destination (Join-Path $d $n) -Force }
            }
        }
        Add-UiLog (T "KeysDone")
        Reset-ContentAfterKeys
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Update-FirmwarePage
}

# Ueber Eden installierte Updates/DLCs werden mit den Keys erkannt: nach einer Aenderung neu einlesen
function Reset-ContentAfterKeys {
    if ($script:ContentWorker) { return }
    $script:ContentLoaded = $false
}

function Remove-Keys {
    if ((Show-Dialog (T "KeysAskDelete") "YesNo" "Warning") -ne "Yes") { return }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        foreach ($n in @("prod.keys", "title.keys")) {
            $f = Join-Path (Get-KeysDir) $n
            if (Test-Path -LiteralPath $f) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($f, "OnlyErrorDialogs", "SendToRecycleBin") }
        }
        Add-UiLog (T "KeysDeleted")
        Reset-ContentAfterKeys
    } catch {
        Show-Msg ((T "ErrPrefix") + " " + $_.Exception.Message) "Error"
    }
    Update-FirmwarePage
}

