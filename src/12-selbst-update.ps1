# ------------------------------------------------------------
#  Selbst-Update des Updaters (nur in der EXE)
# ------------------------------------------------------------
$SelfRepo = "KevinGandler/eden-updater"
$script:SelfExe     = $null
$script:SelfVersion = $null
try {
    $mm = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ([IO.Path]::GetFileName($mm) -notmatch '^(powershell|pwsh|powershell_ise)(\.exe)?$') {
        $script:SelfExe = $mm
        $fv = [Diagnostics.FileVersionInfo]::GetVersionInfo($mm)
        $script:SelfVersion = [version]::new($fv.FileMajorPart, $fv.FileMinorPart, $fv.FileBuildPart)
    }
} catch {}
$script:SelfState   = "idle"     # idle | checking | latest | found | downloading | error
$script:SelfInfo    = $null
$script:SelfError   = ""
$script:SelfAuto    = $false
$script:SelfPrompt  = $false
$script:SelfWorker  = $null
$script:SelfCleanAt = $null
$script:SelfReleases = @()       # @{ Tag; Version; Notes } der letzten Releases, neueste zuerst

# Patchnotes fuer die Anzeige: bei einem verfuegbaren Update alle Versionen, die neuer sind als die
# installierte (neueste zuerst), sonst die der installierten Version. Liefert @{ Title; Text } oder $null.
function Get-SelfNotesInfo {
    $rels = @($script:SelfReleases)
    if (-not $rels.Count -or -not $script:SelfVersion) { return $null }
    $found = ($script:SelfState -eq "found" -or $script:SelfState -eq "downloading") -and $script:SelfInfo
    if ($found) {
        $new = @($rels | Where-Object { $_.Version -and $_.Version -gt $script:SelfVersion -and $_.Notes })
        if (-not $new.Count) { return $null }
        $parts = foreach ($r in $new) {
            if ($new.Count -gt 1) { ("{0}`r`n{1}" -f (Format-Ver $r.Version), $r.Notes) } else { $r.Notes }
        }
        return @{ Title = (TF "SelfNotesNew" (Format-Ver $script:SelfInfo.Version)); Text = ($parts -join "`r`n`r`n") }
    }
    $cur = @($rels | Where-Object { $_.Version -and $_.Version -eq $script:SelfVersion -and $_.Notes }) | Select-Object -First 1
    if (-not $cur) { return $null }
    return @{ Title = (TF "SelfNotesThis" (Format-Ver $script:SelfVersion)); Text = [string]$cur.Notes }
}

function Format-Ver($v) { if ($v) { return ("{0}.{1}.{2}" -f $v.Major, $v.Minor, [Math]::Max(0, $v.Build)) } else { return "-" } }

function ConvertTo-Ver([string]$tag) {
    $t = $tag.Trim().TrimStart('v', 'V')
    $m = [regex]::Match($t, '^(\d+)\.(\d+)(?:\.(\d+))?')
    if (-not $m.Success) { return $null }
    $b = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { 0 }
    return [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, $b)
}

# Reste vom letzten Selbst-Update wegraeumen
function Remove-SelfOld {
    if (-not $script:SelfExe) { return }
    $dir = Split-Path -Parent $script:SelfExe
    Get-ChildItem -LiteralPath $dir -Filter "EdenUpdater*.old" -Force -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}

function Start-SelfWorker([hashtable]$jobArgs) {
    $selfSync.Args   = $jobArgs
    $selfSync.Done   = $false
    $selfSync.Result = $null
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $selfSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($workerLib.ToString() + "`n" + $jobSelf.ToString())   # workerLib liefert Format-Notes
    $script:SelfWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

function Start-SelfCheck([bool]$auto) {
    if (-not $script:SelfExe -or $script:SelfWorker) { return }
    $script:SelfAuto  = $auto
    $script:SelfState = "checking"
    Update-SelfCard
    Start-SelfWorker @{ Mode = "check"; Repo = $SelfRepo; Lang = [string]$script:LangCode }
}

function Start-SelfDownload {
    if (-not $script:SelfExe -or $script:SelfWorker -or -not $script:SelfInfo) { return }
    $script:SelfState = "downloading"
    Update-SelfCard
    Add-UiLog (TF "SelfDownloading" $script:SelfInfo.Tag)
    Start-SelfWorker @{ Mode = "download"; Url = $script:SelfInfo.Url; Size = $script:SelfInfo.Size; Target = ($script:SelfExe + ".new") }
}

function Complete-Self {
    $w = $script:SelfWorker
    $script:SelfWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    $r = $selfSync.Result
    if (-not $r) { $r = @{ Ok = $false; Mode = "check"; Error = "?" } }

    if ($r.Mode -eq "check") {
        if (-not $r.Ok) {
            $script:SelfState = "error"; $script:SelfError = [string]$r.Error
            Add-UiLog (TF "SelfStateError" $r.Error)   # ohne Fehler-Praefix: klappt das Log nicht auf
        } else {
            $script:SelfReleases = @(foreach ($x in @($r.Releases)) { if ($x -and $x.Tag) { @{ Tag = [string]$x.Tag; Version = (ConvertTo-Ver ([string]$x.Tag)); Notes = [string]$x.Notes } } })
            $nv = if ($r.Tag) { ConvertTo-Ver $r.Tag } else { $null }
            if ($nv -and $r.Url -and $script:SelfVersion -and $nv -gt $script:SelfVersion) {
                $script:SelfInfo  = @{ Tag = [string]$r.Tag; Version = $nv; Url = [string]$r.Url; Size = [long]$r.Size; Page = [string]$r.Page }
                $script:SelfState = "found"
                if ($script:SelfAuto) { $script:SelfPrompt = $true }   # Frage kommt, sobald nichts anderes laeuft
            } else {
                $script:SelfState = "latest"
            }
        }
    } else {
        if ($r.Ok) {
            if (Test-AnyBusy) {
                # sonst bricht das Schliessen ab und es laufen zwei Updater
                $script:SelfPendingFile = [string]$r.File
                Add-UiLog (T "SelfWaiting")
                Update-SelfCard
                return
            }
            Install-SelfUpdate ([string]$r.File)
            return
        }
        $script:SelfState = "error"; $script:SelfError = [string]$r.Error
        Show-Msg (TF "SelfStateError" $r.Error) "Error"
    }
    Update-SelfCard
}

$script:SelfPendingFile = $null
function Test-AnyBusy {
    return [bool]($script:Busy -or $script:FwWorker -or $script:SavesWorker -or $script:ModWorker -or
                  ($script:ContentWorker -and $contentSync.Args.Mode -eq "add"))
}

function Ask-SelfUpdate {
    if ($script:SelfState -ne "found" -or -not $script:SelfInfo) { return }
    $q = TF "SelfAsk" (Format-Ver $script:SelfVersion) (Format-Ver $script:SelfInfo.Version)
    # Patchnotes gleich mit anzeigen (lange Texte scrollen im Dialog)
    $n = Get-SelfNotesInfo
    $w = 0
    if ($n -and $n.Text) {
        $txt = [string]$n.Text
        if ($txt.Length -gt 4000) { $txt = $txt.Substring(0, 4000) + "`r`n..." }
        $q = $q + "`n`n" + $n.Title + "`n" + $txt
        $w = 600
    }
    if ((Show-Dialog $q "YesNo" "Question" "" $w) -eq "Yes") { Start-SelfDownload }
}

# Laufende EXE umbenennen (das erlaubt Windows), neue EXE an ihre Stelle, neu starten
function Install-SelfUpdate([string]$newFile) {
    $exe = $script:SelfExe
    $old = $exe + ".old"
    try {
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $old) { $old = $exe + "." + [DateTime]::Now.Ticks + ".old" }
        [IO.File]::Move($exe, $old)
        try { [IO.File]::Move($newFile, $exe) }
        catch { [IO.File]::Move($old, $exe); throw }
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
        $script:SelfRestarting = $true
        $window.Close()
    } catch {
        Remove-Item -LiteralPath $newFile -Force -ErrorAction SilentlyContinue
        $script:SelfState = "error"; $script:SelfError = $_.Exception.Message
        Update-SelfCard
        Show-Msg (TF "SelfStateError" $_.Exception.Message) "Error"
    }
}

function Update-SelfCard {
    $vis = [System.Windows.Visibility]
    if (-not $script:SelfExe) {
        $ui.TxtSelfVersion.Text = "Eden Updater"
        $ui.TxtSelfState.Text   = T "SelfStateScript"
        $ui.BtnSelfCheck.IsEnabled  = $false
        $ui.BtnSelfInstall.Visibility = $vis::Collapsed
        $ui.BtnSelfNotes.Visibility   = $vis::Collapsed
        $ui.ChkSelfUpdate.IsEnabled = $false
        $ui.SelfNotesBox.Visibility = $vis::Collapsed
        return
    }
    $ui.TxtSelfVersion.Text = TF "SelfVersion" (Format-Ver $script:SelfVersion)
    $tag = if ($script:SelfInfo) { [string]$script:SelfInfo.Tag } else { "" }
    $ui.TxtSelfState.Text = switch ($script:SelfState) {
        "checking"    { T "SelfStateChecking" }
        "latest"      { T "SelfStateLatest" }
        "found"       { TF "SelfStateFound" $tag }
        "downloading" { TF "SelfDownloading" $tag }
        "error"       { TF "SelfStateError" $script:SelfError }
        default       { T "SelfStateIdle" }
    }
    $working = ($script:SelfState -eq "checking" -or $script:SelfState -eq "downloading")
    $ui.BtnSelfCheck.IsEnabled = -not $working
    $found = ($script:SelfState -eq "found")
    $ui.BtnSelfInstall.Visibility = if ($found) { $vis::Visible } else { $vis::Collapsed }
    $ui.BtnSelfInstall.IsEnabled  = $found -and -not $script:Busy
    $ui.BtnSelfNotes.Visibility   = if (($found -or $script:SelfState -eq "downloading") -and $script:SelfInfo -and $script:SelfInfo.Page) { $vis::Visible } else { $vis::Collapsed }
    # Patchnotes direkt in der Karte: was das Update bringt bzw. was die installierte Version gebracht hat
    $n = Get-SelfNotesInfo
    if ($n -and $n.Text) {
        $ui.TxtSelfNotesTitle.Text = [string]$n.Title
        if ($ui.TxtSelfNotes.Text -ne [string]$n.Text) { $ui.TxtSelfNotes.Text = [string]$n.Text }
        $ui.SelfNotesBox.Visibility = $vis::Visible
    } else {
        $ui.SelfNotesBox.Visibility = $vis::Collapsed
    }
}

function Start-NotesWorker([string]$tag) {
    $notesSync.Args   = @{ Tag = $tag }
    $notesSync.Done   = $false
    $notesSync.Result = $null
    $notesSync.L      = $script:L
    $notesSync.Culture = $script:LangCulture
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $notesSync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($workerLib.ToString() + "`n" + $jobNotes.ToString())
    $script:NotesWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

function Show-Notes {
    if ($script:Snapshot) { return }
    $sel = $ui.List.SelectedItem
    if (-not $sel) {
        $ui.TxtNotesTitle.Text = ""
        $ui.TxtNotes.Text      = T "NotesSelect"
        $ui.BtnNotesWeb.IsEnabled = $false
        return
    }
    $tag = [string]$sel.Tag
    $ui.TxtNotesTitle.Text    = $tag
    $ui.BtnNotesWeb.IsEnabled = $true
    if ($script:NotesCache.ContainsKey($tag)) {
        $ui.TxtNotes.Text = $script:NotesCache[$tag]
        return
    }
    $ui.TxtNotes.Text = T "NotesLoading"
    if (-not (Test-NotesVisible)) { return }
    $script:NotesWanted = $tag
    if (-not $script:NotesWorker) { Start-NotesWorker $tag }
}

function Complete-Notes {
    $w = $script:NotesWorker
    $script:NotesWorker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}

    $r = $notesSync.Result
    if ($r) {
        if ($r.Ok) { $script:NotesCache[[string]$r.Tag] = [string]$r.Text }
        $sel = $ui.List.SelectedItem
        if ($sel -and $sel.Tag -eq $r.Tag) {
            if ($r.Ok) { $ui.TxtNotes.Text = [string]$r.Text }
            elseif ($r.Error) { $ui.TxtNotes.Text = (T "NotesError") + "`r`n" + $r.Error }
            else { $ui.TxtNotes.Text = T "NotesNone" }
        }
    }
    # Hat sich die Auswahl waehrenddessen geaendert?
    $wanted = $script:NotesWanted
    if ($wanted -and $r -and $wanted -ne $r.Tag -and -not $script:NotesCache.ContainsKey($wanted)) {
        $sel = $ui.List.SelectedItem
        if ($sel -and $sel.Tag -eq $wanted) { Start-NotesWorker $wanted }
    }
}

function Start-Eden {
    $exe = Join-Path $script:Settings.EdenPath "eden.exe"
    if (Test-Path $exe) {
        Start-Process -FilePath $exe -WorkingDirectory $script:Settings.EdenPath
        Add-UiLog (T "LogEdenStarted")
        if ($script:Settings.CloseAfterStart) { $window.Close() }
    }
    else { Show-Msg ((T "ErrNoExe") + "`n" + $exe) }
}

function Complete-Worker {
    $w = $script:Worker
    $script:Worker = $null
    try { [void]$w.PS.EndInvoke($w.Handle) } catch {}
    try { $w.PS.Dispose(); $w.RS.Close(); $w.RS.Dispose() } catch {}
    Flush-Log

    $r = $sync.Result
    $script:Busy = $false
    $ui.Pb.IsIndeterminate = $false
    if ($r -and $r.Kind -eq "load" -and @($r.Variants).Count -gt 0) {
        $script:Variants = @($r.Variants)
        Update-VariantCombo
    }
    if ($r -and $r.Ok -and $r.Kind -eq "load") {
        $script:Releases    = @($r.Items)
        $script:LoadedPages = [int]$sync.Args.Pages
        $ui.TxtStatus.Text  = T "StReady"
        Set-ProgressValue 0 $true
        Update-List
    } elseif ($r -and $r.Kind -eq "load") {
        Set-ProgressValue 0 $true
        if (@($r.Variants).Count -gt 0) { $script:Releases = @(); Update-List }
    } elseif ($r -and $r.Ok -and $r.Kind -eq "install") {
        Update-List
    } elseif ($r -and $r.Kind -eq "install") {
        Set-ProgressValue 0 $true
        if (-not $r.Cancelled) { Show-Msg $r.Error }
    } elseif ($r -and $r.Ok -and $r.Kind -eq "restore") {
        Update-List
    } elseif ($r -and $r.Kind -eq "restore") {
        Set-ProgressValue 0 $true
        Show-Msg $r.Error
    }
    Update-Ui

    if ($r -and $r.Ok -and $r.Kind -eq "install" -and $script:Settings.StartAfter) { Start-Eden }

    if ($r -and $r.Ok -and $r.Kind -eq "load" -and $script:StartupCheck) {
        $script:StartupCheck = $false
        if ($script:Settings.AutoInstall -and $script:UpdateAvailable) { Start-Install $script:Releases[0] }
    }
}

