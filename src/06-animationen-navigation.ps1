# ------------------------------------------------------------
#  Animationen
# ------------------------------------------------------------
function Start-FadeIn($el, [double]$slide = 10, [double]$slideX = 0, [int]$ms = 300) {
    if (-not $el -or $script:Snapshot) { return }
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, 1.0, [TimeSpan]::FromMilliseconds([Math]::Max(120, $ms - 40)))
    $fade.EasingFunction = $ease
    $el.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $tt = $el.RenderTransform
    if ($tt -is [System.Windows.Media.TranslateTransform]) {
        if ($slide -ne 0) {
            $mv = [System.Windows.Media.Animation.DoubleAnimation]::new($slide, 0.0, [TimeSpan]::FromMilliseconds($ms))
            $mv.EasingFunction = $ease
            $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $mv)
        }
        if ($slideX -ne 0) {
            $mx = [System.Windows.Media.Animation.DoubleAnimation]::new($slideX, 0.0, [TimeSpan]::FromMilliseconds($ms))
            $mx.EasingFunction = $ease
            $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $mx)
        }
    }
}

# Fortschrittsbalken gleitet zum neuen Wert (snap = sofort setzen)
function Set-ProgressValue([double]$v, [bool]$snap = $false) {
    $prop = [System.Windows.Controls.Primitives.RangeBase]::ValueProperty
    if ($snap) {
        $ui.Pb.BeginAnimation($prop, $null)
        $ui.Pb.Value = $v
        return
    }
    $a = [System.Windows.Media.Animation.DoubleAnimation]::new($v, [TimeSpan]::FromMilliseconds(250))
    $ui.Pb.BeginAnimation($prop, $a)
}

$script:NavActiveBtn = $null
function Set-NavActive($btn, [bool]$active) {
    $c = [System.Windows.Controls.Control]
    if ($active) {
        $btn.SetResourceReference($c::ForegroundProperty,  "BrText")
        $btn.SetResourceReference($c::BorderBrushProperty, "BrAccentText")
        $btn.FontWeight = [System.Windows.FontWeights]::SemiBold
        $script:NavActiveBtn = $btn
    } else {
        $btn.ClearValue($c::ForegroundProperty)
        $btn.ClearValue($c::BorderBrushProperty)
        $btn.ClearValue($c::FontWeightProperty)
    }
}

# Markierung in der Seitenleiste gleitet zum aktiven Eintrag (mit leichtem Nachfedern)
function Move-NavPill([bool]$animate) {
    $btn = $script:NavActiveBtn
    if (-not $btn) { return }
    $ui.NavHost.UpdateLayout()
    if (-not $btn.IsVisible) { return }
    $y  = $btn.TranslatePoint([System.Windows.Point]::new(0, 0), $ui.NavHost).Y
    $tt = $ui.NavPill.RenderTransform
    $yp = [System.Windows.Media.TranslateTransform]::YProperty
    $ui.NavPill.Height = $btn.ActualHeight
    if ($animate -and -not $script:Snapshot -and $ui.NavPill.Opacity -gt 0) {
        $from = [double]$tt.Y
        $tt.BeginAnimation($yp, $null)
        $tt.Y = $y
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new($from, $y, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(380)))
        $ease = [System.Windows.Media.Animation.BackEase]::new()
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $dist = [Math]::Max(1.0, [Math]::Abs($y - $from))
        $ease.Amplitude  = [Math]::Min(0.5, 28.0 / $dist)      # ergibt rund 5 px ueber das Ziel hinaus
        $a.EasingFunction = $ease
        $a.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
        $tt.BeginAnimation($yp, $a)
    } else {
        $tt.BeginAnimation($yp, $null)
        $tt.Y = $y
    }
    $ui.NavPill.Opacity = 1
}

# Reihenfolge der Seiten in der Seitenleiste (bestimmt die Richtung der Seitenwechsel-Animation)
$script:PageOrder = @("versions", "notes", "games", "mods", "content", "saves", "firmware", "settings")

function Set-Page([string]$page) {
    $prev = $script:CurrentPage
    $script:CurrentPage = $page
    $ui.PanelVersions.Visibility = if ($page -eq "versions") { "Visible" } else { "Collapsed" }
    $ui.PanelNotes.Visibility    = if ($page -eq "notes")    { "Visible" } else { "Collapsed" }
    $ui.PanelSettings.Visibility = if ($page -eq "settings") { "Visible" } else { "Collapsed" }
    $ui.PanelGames.Visibility    = if ($page -eq "games")    { "Visible" } else { "Collapsed" }
    $ui.PanelMods.Visibility     = if ($page -eq "mods")     { "Visible" } else { "Collapsed" }
    $ui.PanelContent.Visibility  = if ($page -eq "content")  { "Visible" } else { "Collapsed" }
    $ui.PanelFirmware.Visibility = if ($page -eq "firmware") { "Visible" } else { "Collapsed" }
    $ui.PanelSaves.Visibility    = if ($page -eq "saves")    { "Visible" } else { "Collapsed" }
    Set-NavActive $ui.BtnNavVer   ($page -eq "versions")
    Set-NavActive $ui.BtnNavNotes ($page -eq "notes")
    Set-NavActive $ui.BtnNavGames ($page -eq "games")
    Set-NavActive $ui.BtnNavMods  ($page -eq "mods")
    Set-NavActive $ui.BtnNavContent ($page -eq "content")
    Set-NavActive $ui.BtnNavFw    ($page -eq "firmware")
    Set-NavActive $ui.BtnNavSaves ($page -eq "saves")
    Set-NavActive $ui.BtnNavSet   ($page -eq "settings")
    $titleKey = switch ($page) { "notes" { "L_NavNotes" } "games" { "L_NavGames" } "mods" { "L_NavMods" } "content" { "L_NavContent" } "firmware" { "L_NavFirmware" } "saves" { "L_NavSaves" } "settings" { "L_NavSettings" } default { "L_NavVersions" } }
    if ($page -eq "games" -and -not $script:GamesLoaded) { Start-GameScan }
    if ($page -eq "mods" -and -not $script:Snapshot) { Open-ModsTab }
    if ($page -eq "content" -and -not $script:Snapshot) { Open-ContentTab }
    if ($page -eq "firmware") { Update-FirmwarePage }
    if ($page -eq "saves" -and -not $script:Snapshot) { Open-SavesTab }
    $ui.TxtPageTitle.SetResourceReference([System.Windows.Controls.TextBlock]::TextProperty, $titleKey)
    $subKey = switch ($page) { "notes" { "L_SubNotes" } "games" { "L_SubGames" } "mods" { "L_SubMods" } "content" { "L_SubContent" } "firmware" { "L_SubFirmware" } "saves" { "L_SubSaves" } "settings" { "L_SubSettings" } default { "L_AppSubtitle" } }
    $ui.TxtPageSub.SetResourceReference([System.Windows.Controls.TextBlock]::TextProperty, $subKey)
    if ($prev -ne $page) {
        $el = switch ($page) { "versions" { $ui.PanelVersions } "notes" { $ui.PanelNotes } "games" { $ui.PanelGames } "mods" { $ui.PanelMods } "content" { $ui.PanelContent } "firmware" { $ui.PanelFirmware } "saves" { $ui.PanelSaves } "settings" { $ui.PanelSettings } }
        # weiter unten in der Leiste = Seite kommt von unten, sonst von oben
        $dir = if ([array]::IndexOf($script:PageOrder, $page) -ge [array]::IndexOf($script:PageOrder, $prev)) { 1 } else { -1 }
        Start-FadeIn $el (16 * $dir)
        Start-FadeIn $ui.HeadText (7 * $dir) 0 240
    }
    try { Move-NavPill ($prev -ne $page) } catch {}
    if (Test-NotesVisible) { try { Show-Notes } catch {} }
}

function Start-Worker([scriptblock]$Main, [hashtable]$ArgsTable, [string]$Kind) {
    $sync.Args      = $ArgsTable
    $sync.Done      = $false
    $sync.Result    = $null
    $sync.Cancel    = $false
    $sync.CanCancel = ($Kind -eq "install")
    $sync.Progress  = -1
    $sync.Status    = ""
    $sync.L         = $script:L
    $sync.Culture   = $script:LangCulture
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "MTA"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $sync)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($workerLib.ToString() + "`n" + $Main.ToString())
    $script:Worker   = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
    $script:Busy     = $true
    $script:BusyKind = $Kind
    Update-Ui
}

function Start-Load([int]$pages) {
    if ($script:Busy) { return }
    Add-UiLog (T "StSearching")
    Start-Worker $jobLoad @{ Pages = $pages; Pattern = [string]$script:Settings.AssetPattern; Variant = [string]$script:Settings.AssetVariant } "load"
}

function Start-Install($rel) {
    if ($script:Busy) { return }
    $s = $script:Settings
    Add-UiLog (TF "LogInstall" $rel.Tag)
    Start-Worker $jobInstall @{
        Tag      = $rel.Tag
        Url      = $rel.Url
        EdenPath = [string]$s.EdenPath
        Backup   = [bool]$s.Backup
        Excludes = (Get-Excludes)
        InstalledVersion = (Get-InstalledVersion)
        SaveBackup    = [bool]$s.SaveBackupOnUpdate
        SaveLib       = $saveLib.ToString()
        SaveRoot      = $(try { Get-SaveRoot } catch { "" })
        SaveBackupDir = $(try { Get-SaveBackupDir } catch { "" })
        SaveKeep      = $(if ([int]$s.SaveBackupKeep -gt 0) { [int]$s.SaveBackupKeep } else { 10 })
    } "install"
}

function Start-Restore {
    if ($script:Busy) { return }
    Add-UiLog (T "LogRestore")
    Start-Worker $jobRestore @{
        EdenPath      = [string]$script:Settings.EdenPath
        Excludes      = (Get-Excludes)
        BackupVersion = (Get-BackupVersion)
    } "restore"
}

