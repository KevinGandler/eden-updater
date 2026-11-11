# ============================================================
#  Eden Updater  -  GUI (WPF)
#  Quelle: https://git.eden-emu.dev/eden-ci/nightly
#  Funktionen: auf neueste Nightly aktualisieren, aeltere Versionen
#  installieren, Einstellungen im UI, mehrsprachig (13 Sprachen).
#  Einstellungen liegen im Eden-Installationsordner.
# ============================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$SettingsName = "eden-updater-settings.json"
# Merkt sich nur, wo der Eden-Ordner liegt (falls der Updater woanders liegt)
$PointerFile  = Join-Path $env:LOCALAPPDATA "EdenUpdater\location.txt"
$script:SettingsFile = $null

# ------------------------------------------------------------
#  Einstellungen
# ------------------------------------------------------------
$Defaults = [ordered]@{
    EdenPath     = $ScriptDir      # Standard: Ordner, in dem der Updater liegt
    AssetVariant = ""
    NotesLayout  = "page"
    AssetPattern = "Windows.*amd64.*pgo"
    Pages        = 2
    Backup       = $true
    StartAfter   = $true
    CloseAfterStart = $false
    ThemePreset  = "dark-cyan"
    AutoCheck    = $true
    AutoInstall  = $false
    SelfUpdateCheck = $true   # beim Start nach neuer Updater-Version suchen
    GamesFullscreen = $false  # Spiele im Vollbild starten (eden.exe -f)
    GamesCloseOnStart = $false # beim Spielstart schliessen statt in die Taskleiste minimieren
    GamesSort    = "name"     # Reihenfolge im Spiele-Tab: "name" oder "recent" (zuletzt gespielt zuerst)
    WinLeft      = 0          # Fenster: Position und Groesse beim letzten Schliessen (WinWidth 0 = noch nichts gemerkt)
    WinTop       = 0
    WinWidth     = 0
    WinHeight    = 0
    WinMax       = $false     # war maximiert
    FavoriteGames = @()       # Favoriten (Title-ID, sonst Dateipfad) - stehen oben in der Spieleliste
    FirmwareVersion = ""      # zuletzt ueber den Updater installierte Firmware (aus dem Datei-/Ordnernamen)
    SaveBackupOnUpdate = $true # Spielstaende vor jedem Eden-Update sichern (nur Spiele mit Aenderungen)
    SaveBackupKeep = 10       # so viele automatische Backups pro Spiel behalten
    CustomTheme  = $null      # eigenes Theme: @{ Bg; Panel; Text; Accent }
    Language     = "auto"
}

function Read-SettingsFile([string]$f) {
    try { return (Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Get-SettingsPathFor([string]$edenPath) { return (Join-Path $edenPath $SettingsName) }

# Reihenfolge: Updater liegt im Eden-Ordner -> gemerkter Eden-Ordner -> alte Datei neben dem Updater -> Standard
function Get-Settings {
    $s = @{}
    foreach ($k in $Defaults.Keys) { $s[$k] = $Defaults[$k] }
    $local = Join-Path $ScriptDir $SettingsName
    $eden  = $null
    $src   = $null

    if (Test-Path (Join-Path $ScriptDir "eden.exe")) { $eden = $ScriptDir }
    if (-not $eden -and (Test-Path $PointerFile)) {
        try {
            $ptr = ([string](Get-Content -LiteralPath $PointerFile -TotalCount 1)).Trim()
            if ($ptr -and (Test-Path (Get-SettingsPathFor $ptr))) { $eden = $ptr }
        } catch {}
    }
    if (-not $eden -and (Test-Path $local)) {
        $j = Read-SettingsFile $local
        if ($j -and $j.EdenPath) { $eden = [string]$j.EdenPath }
    }
    if (-not $eden) { $eden = [string]$Defaults.EdenPath }

    $target = Get-SettingsPathFor $eden
    if (Test-Path $target)    { $src = $target }
    elseif (Test-Path $local) { $src = $local }

    if ($src) {
        $j = Read-SettingsFile $src
        if ($j) { foreach ($k in @($s.Keys)) { if ($null -ne $j.$k) { $s[$k] = $j.$k } } }
    }
    if ($src -eq $target -or -not $s.EdenPath) { $s.EdenPath = $eden }
    $script:SettingsFile = $src
    # Erster Start: keine Einstellungen gefunden und kein Eden neben dem Updater
    $script:FirstRun = (-not $src) -and (-not (Test-Path (Join-Path $ScriptDir "eden.exe")))
    return $s
}

function Save-Pointer([string]$dir) {
    try {
        $pd = Split-Path -Parent $PointerFile
        if (-not (Test-Path $pd)) { New-Item -ItemType Directory -Path $pd -Force | Out-Null }
        Set-Content -LiteralPath $PointerFile -Value $dir -Encoding UTF8
    } catch {}
}

# Speichert immer in <Eden-Ordner>\eden-updater-settings.json und raeumt die alte Datei weg
function Save-Settings {
    $dir = [string]$script:Settings.EdenPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $file = Get-SettingsPathFor $dir
    $script:Settings | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8
    $old = $script:SettingsFile
    $script:SettingsFile = $file
    Save-Pointer $dir
    if ($old -and (Test-Path $old) -and ([IO.Path]::GetFullPath($old) -ne [IO.Path]::GetFullPath($file))) {
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
    }
}

# Dateien/Ordner, die beim Update NICHT angefasst werden
function Get-Excludes {
    @("version.txt", "changelog.txt", "Backup", "user",
      "eden-nightly-updater.ps1", "Eden-Updater.bat", "Eden-Updater.vbs",
      "EdenUpdater.ps1", "EdenUpdater.exe", "eden-updater-settings.json",
      "EdenUpdater.ico", "Build-Exe.ps1", "Build-Exe.bat",
      "EdenUpdater.exe.new", "EdenUpdater*.old")
}

$script:FirstRun       = $false
$script:Settings       = Get-Settings
# Screenshot-Modus (nur fuer automatische Tests): EDEN_UPDATER_SNAPSHOT=<Zielordner>
$script:Snapshot = [string]$env:EDEN_UPDATER_SNAPSHOT
if ($script:Snapshot) {
    $script:Settings.Language    = $(if ($env:EDEN_UPDATER_SNAPSHOT_LANG) { $env:EDEN_UPDATER_SNAPSHOT_LANG } else { "de" })
    $script:Settings.AutoCheck   = $false
    $script:Settings.NotesLayout = "page"
}
# Alte Einstellungen (neben dem Updater) automatisch in den Eden-Ordner umziehen
try {
    $want = Get-SettingsPathFor ([string]$script:Settings.EdenPath)
    if ((Test-Path ([string]$script:Settings.EdenPath)) -and ($script:SettingsFile -ne $want)) { Save-Settings }
} catch {}
$script:Releases       = @()
$script:LoadedPages    = 0
$script:Busy           = $false
$script:BusyKind       = ""
$script:Worker         = $null
$script:UpdateAvailable = $false
$script:StartupCheck   = $true
$script:Variants       = @()
$script:NotesCache     = @{}
$script:CurrentPage    = "versions"
$script:NotesWorker    = $null
$script:NotesWanted    = $null
$script:SuppressVariantEvent = $false
$script:ChipPulse = $null

