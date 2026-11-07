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

# ------------------------------------------------------------
#  Sprachen
#  Format pro Zeile: Schluessel=Text   (\n = Zeilenumbruch)
#  Fehlt ein Schluessel, wird Englisch und dann Deutsch verwendet.
# ------------------------------------------------------------
$LangOrder = @("de", "en", "es", "fr", "it", "pt", "nl", "pl", "tr", "ru", "ja", "zh", "ko")

$LangData = @{
de = @'
Name=Deutsch
Culture=de-DE
AppSubtitle=Nightly-Builds aktualisieren oder ältere Versionen installieren
NavVersions=Versionen
NavNotes=Patchnotes
NavSettings=Einstellungen
CardInstalled=INSTALLIERT
CardLatest=NEUESTE
BtnUpdate=Auf neueste aktualisieren
BtnUpToDate=Aktuell
BtnLaunch=Eden starten
BtnInstallSel=Diese Version installieren
BtnReinstall=Neu installieren
BtnMore=Mehr laden
BtnReload=Neu laden
BtnRestore=Backup wiederherstellen
BtnRestoreTo=Zurück auf {0}
ListInfo={0} Versionen geladen
NotInstalled=nicht installiert
NotesHeader=PATCHNOTES
NotesHintPage=Für die Version, die auf der Seite Versionen ausgewählt ist.
NotesHintSide=Für die ausgewählte Version.
NotesWeb=Im Browser öffnen
NotesSelect=Wähle in der Versionsliste eine Version aus.
NotesLoading=Lade Patchnotes...
NotesError=Patchnotes konnten nicht geladen werden:
NotesNone=Für diese Version gibt es keine Patchnotes.
SetPath=Installationsordner
SetBrowse=Durchsuchen...
SetBrowseTitle=Eden-Installationsordner wählen
SetVariant=Build-Variante
SetVariantHint=Die Liste wird aus den geladenen Releases ermittelt (nur Windows-kompatible Builds).
VarRecommended=Empfohlen: PGO (Windows, amd64)
VarCount={0}   ({1} Releases)
VarCustom=Eigener Filter (Regex)...
SetPattern=Eigener Filter (Regex auf den Download-Link)
SetPages=Releases laden (Seiten, 1 bis 10)
SetNotes=Patchnotes-Anzeige
NotesOptPage=Eigene Seite (Button 'Patchnotes' oben)
NotesOptSide=Neben der Versionsliste
SetTheme=Farbschema
SetThemePick=Theme auswählen...
SetLanguage=Sprache
LangAuto=Automatisch ({0})
SetLanguageHint=Automatisch übernimmt die Sprache von Windows. Wird sie nicht unterstützt, bleibt Deutsch aktiv.
ChkBackup=Vor dem Update ein Backup der alten Version erstellen
ChkStart=Eden nach Update/Installation automatisch starten
ChkClose=Updater nach dem Start von Eden automatisch schließen
ChkAuto=Beim Programmstart nach Updates suchen
ChkAutoInstall=Gefundene Updates automatisch installieren (nur beim Programmstart)
Save=Speichern
Cancel=Abbrechen
Apply=Übernehmen
Yes=Ja
No=Nein
OK=OK
DlgWarning=Hinweis
DlgError=Fehler
DlgQuestion=Bestätigen
DlgInfo=Info
ThemeTag=THEME
ThemeTitle=Theme auswählen
ThemeHint=Ein Klick zeigt das Theme sofort als Vorschau.
StReady=Bereit
StSearching=Suche nach Releases...
StLoadError=Fehler beim Laden
StError=Fehler
LogInstall=>> Installiere {0}
LogRestore=>> Stelle Backup wieder her
LogEdenStarted=Eden gestartet.
LogThemeSaved=Theme gespeichert: {0}
LogSettingsSaved=Einstellungen gespeichert.
LogCancelReq=Abbruch angefordert...
LogAutoOff=Automatische Suche ist aus. Klicke auf '{0}'.
ErrPrefix=FEHLER:
ErrNoExe=eden.exe nicht gefunden:
ErrNoPath=Installationsordner fehlt.
ErrNoFilter=Filter fehlt.
ErrPages=Die Seitenanzahl muss zwischen 1 und 10 liegen.
MsgBusyClose=Der Vorgang läuft noch. Bitte warten, bis er fertig ist.
AskInstallBackup=Version {0} installieren?\n\nDie aktuelle Installation wird dabei ersetzt (Backup wird erstellt).
AskInstallNoBackup=Version {0} installieren?\n\nDie aktuelle Installation wird dabei ersetzt (ohne Backup).
AskRestoreVer=Version {0} wiederherstellen?\n\nDie aktuell installierte Version wird dabei ersetzt. Das Backup bleibt erhalten.
AskRestore=Das Backup wiederherstellen?\n\nDie aktuell installierte Version wird dabei ersetzt. Das Backup bleibt erhalten.
WLoadPage=Lade Release-Liste (Seite {0})...
WUnreachable=git.eden-emu.dev nicht erreichbar (HTTP {0}).
WNoReleases=Keine passenden Releases für diese Build-Variante gefunden.
WFound={0} Versionen gefunden.
WEdenRunning=Eden läuft noch. Bitte zuerst beenden und dann erneut versuchen.
WDownloading=Lade {0} herunter...
WDlProgress=Download   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Download   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Abgebrochen.
WDlFailed=Download fehlgeschlagen (curl Exit {0}).
WDlDone=Download fertig ({0:N1} MB in {1:N0}s).
WBackupMaking=Erstelle Backup...
WBackupDone=Backup erstellt.
WRemoveOld=Entferne alte Version...
WRemovedOld=Alte Dateien entfernt.
WExtracting=Entpacke   {0} / {1} Dateien
WExtracted=Entpackt.
WInstalledSt=Fertig: {0} installiert
WInstalledLog=Eden {0} installiert.
WBackupAt=Das Backup liegt unter: {0}
WNoBackup=Kein Backup gefunden.
WBackupEmpty=Das Backup ist leer.
WRemoveCur=Entferne aktuelle Version...
WRemovedCur=Aktuelle Version entfernt.
WRestoring=Stelle wieder her   {0} / {1}
WUnknownVer=unbekannt (Backup)
WRestoredSt=Fertig: {0} wiederhergestellt
WRestoredLog=Backup wiederhergestellt: {0}
ChipUpdate=Update verfügbar
GrpInstall=Installation
GrpLook=Darstellung
GrpBehavior=Verhalten
LogTitle=Aktivität
SetStoredAt=Einstellungen werden im Installationsordner gespeichert: {0}
FirstRunAsk=Noch keine Eden-Installation gefunden.\n\nSoll Eden in diesen Ordner installiert werden?\n{0}\n\nMit Nein wählst du einen anderen Ordner.
GrpUpdater=Eden Updater
SelfVersion=Installierte Version: {0}
SelfStateIdle=Noch nicht nach Updates gesucht.
SelfStateChecking=Suche nach Updates für den Updater...
SelfStateLatest=Der Updater ist aktuell.
SelfStateFound=Neue Version verfügbar: {0}
SelfStateError=Suche fehlgeschlagen: {0}
SelfStateScript=Selbst-Update gibt es nur in der EXE-Version.
SelfBtnCheck=Nach Updates suchen
SelfBtnInstall=Jetzt installieren
SelfBtnNotes=Was ist neu?
SelfChkStart=Beim Start nach Updates für den Updater suchen
SelfAsk=Eine neue Version des Eden Updaters ist verfügbar.\n\nInstalliert: {0}\nNeu: {1}\n\nJetzt aktualisieren? Der Updater startet danach neu.
SelfDownloading=Lade Updater {0} herunter...
SelfUpdated=Updater auf Version {0} aktualisiert.
NavGames=Spiele
GamesSearch=Spiele durchsuchen...
GamesStart=Spiel starten
GamesFull=Im Vollbild starten
GamesInfo={0} Spiele aus {1} Ordnern
GamesEmpty=Keine Spiele gefunden. Füge in Eden unter Datei → Spieleordner hinzufügen einen Ordner hinzu und klicke dann hier auf Neu laden.
GamesNoEden=Eden ist noch nicht installiert.
GamesScanning=Suche nach Spielen...
LogGameStart=Starte {0}...
ThBaseDark=Dunkel
ThBaseBlack=Schwarz
ThBaseLight=Hell
ThColCyan=Cyan
ThColBlue=Blau
ThColIndigo=Indigo
ThColViolet=Violett
ThColPink=Rosa
ThColRed=Rot
ThColOrange=Orange
ThColGold=Gold
ThColGreen=Grün
ThColGrey=Grau
ThColSand=Sand
ThCustom=Eigenes Theme
ThTabPresets=Vorlagen
ThTabCustom=Eigenes
ThSlotBg=Hintergrund
ThSlotPanel=Flächen
ThSlotText=Text
ThSlotAccent=Akzent
ThCustomHint=Wähle links eine Farbe aus und passe sie rechts an. Die Vorschau siehst du sofort.
ThContrast=Lesbarkeit {0} : 1
ThContrastOk=gut
ThContrastLow=zu gering, Text wird automatisch angepasst
GamesClose=Updater beim Spielstart schließen
NavMods=Mods
ModsInfo={0} Mods für {1} Spiele
ModsScanning=Suche nach Mods...
ModsInstalling=Mod wird installiert...
ModsFolder=Mod-Ordner öffnen
ModsAdd=Mod hinzufügen...
ModsDelete=Löschen
ModsSelectGame=Wähle links ein Spiel aus.
ModsGameInfo={0} Mods · {1} aktiv
ModsNoMods=keine Mods
ModsEmptyGame=Für dieses Spiel sind keine Mods installiert. Füge mit 'Mod hinzufügen...' ein ZIP hinzu oder kopiere Mod-Ordner in den Mod-Ordner.
ModsUnknownGame=Unbekanntes Spiel
ModsEdenRunning=Eden läuft gerade. Schließe Eden, um Mods zu ändern, sonst überschreibt Eden die Änderungen beim Beenden.
ModsAskDelete=Mod '{0}' wirklich löschen?\n\nDer Ordner wird in den Papierkorb verschoben.
ModsDeleted=Mod gelöscht: {0}
ModsAdded=Mod hinzugefügt: {0}
ModsToggledOn=Mod aktiviert: {0}
ModsToggledOff=Mod deaktiviert: {0}
'@
en = @'
Name=English
Culture=en-US
AppSubtitle=Update to the latest nightly or install older versions
NavVersions=Versions
NavNotes=Patch notes
NavSettings=Settings
CardInstalled=INSTALLED
CardLatest=LATEST
BtnUpdate=Update to latest
BtnUpToDate=Up to date
BtnLaunch=Launch Eden
BtnInstallSel=Install this version
BtnReinstall=Reinstall
BtnMore=Load more
BtnReload=Reload
BtnRestore=Restore backup
BtnRestoreTo=Back to {0}
ListInfo={0} versions loaded
NotInstalled=not installed
NotesHeader=PATCH NOTES
NotesHintPage=For the version selected on the Versions page.
NotesHintSide=For the selected version.
NotesWeb=Open in browser
NotesSelect=Select a version in the version list.
NotesLoading=Loading patch notes...
NotesError=Could not load patch notes:
NotesNone=There are no patch notes for this version.
SetPath=Installation folder
SetBrowse=Browse...
SetBrowseTitle=Choose the Eden installation folder
SetVariant=Build variant
SetVariantHint=The list is built from the loaded releases (Windows-compatible builds only).
VarRecommended=Recommended: PGO (Windows, amd64)
VarCount={0}   ({1} releases)
VarCustom=Custom filter (regex)...
SetPattern=Custom filter (regex on the download link)
SetPages=Releases to load (pages, 1 to 10)
SetNotes=Patch notes display
NotesOptPage=Separate page ('Patch notes' button at the top)
NotesOptSide=Next to the version list
SetTheme=Color scheme
SetThemePick=Choose theme...
SetLanguage=Language
LangAuto=Automatic ({0})
SetLanguageHint=Automatic uses your Windows language. If it is not supported, German is used.
ChkBackup=Create a backup of the old version before updating
ChkStart=Start Eden automatically after update/installation
ChkClose=Close the updater automatically after starting Eden
ChkAuto=Check for updates when the program starts
ChkAutoInstall=Install found updates automatically (only at program start)
Save=Save
Cancel=Cancel
Apply=Apply
Yes=Yes
No=No
OK=OK
DlgWarning=Notice
DlgError=Error
DlgQuestion=Confirm
DlgInfo=Info
ThemeTag=THEME
ThemeTitle=Choose theme
ThemeHint=Click a theme to preview it instantly.
StReady=Ready
StSearching=Searching for releases...
StLoadError=Error while loading
StError=Error
LogInstall=>> Installing {0}
LogRestore=>> Restoring backup
LogEdenStarted=Eden started.
LogThemeSaved=Theme saved: {0}
LogSettingsSaved=Settings saved.
LogCancelReq=Cancellation requested...
LogAutoOff=Automatic check is off. Click '{0}'.
ErrPrefix=ERROR:
ErrNoExe=eden.exe not found:
ErrNoPath=The installation folder is missing.
ErrNoFilter=The filter is missing.
ErrPages=The number of pages must be between 1 and 10.
MsgBusyClose=The operation is still running. Please wait until it has finished.
AskInstallBackup=Install version {0}?\n\nThe current installation will be replaced (a backup will be created).
AskInstallNoBackup=Install version {0}?\n\nThe current installation will be replaced (without backup).
AskRestoreVer=Restore version {0}?\n\nThe currently installed version will be replaced. The backup is kept.
AskRestore=Restore the backup?\n\nThe currently installed version will be replaced. The backup is kept.
WLoadPage=Loading release list (page {0})...
WUnreachable=git.eden-emu.dev is not reachable (HTTP {0}).
WNoReleases=No matching releases found for this build variant.
WFound={0} versions found.
WEdenRunning=Eden is still running. Please close it first and try again.
WDownloading=Downloading {0}...
WDlProgress=Download   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Download   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Cancelled.
WDlFailed=Download failed (curl exit {0}).
WDlDone=Download finished ({0:N1} MB in {1:N0}s).
WBackupMaking=Creating backup...
WBackupDone=Backup created.
WRemoveOld=Removing old version...
WRemovedOld=Old files removed.
WExtracting=Extracting   {0} / {1} files
WExtracted=Extracted.
WInstalledSt=Done: {0} installed
WInstalledLog=Eden {0} installed.
WBackupAt=The backup is located at: {0}
WNoBackup=No backup found.
WBackupEmpty=The backup is empty.
WRemoveCur=Removing current version...
WRemovedCur=Current version removed.
WRestoring=Restoring   {0} / {1}
WUnknownVer=unknown (backup)
WRestoredSt=Done: {0} restored
WRestoredLog=Backup restored: {0}
ChipUpdate=Update available
GrpInstall=Installation
GrpLook=Appearance
GrpBehavior=Behavior
LogTitle=Activity
SetStoredAt=Settings are stored in the installation folder: {0}
FirstRunAsk=No Eden installation found yet.\n\nInstall Eden into this folder?\n{0}\n\nChoose No to pick a different folder.
GrpUpdater=Eden Updater
SelfVersion=Installed version: {0}
SelfStateIdle=Not checked for updates yet.
SelfStateChecking=Checking for updater updates...
SelfStateLatest=The updater is up to date.
SelfStateFound=New version available: {0}
SelfStateError=Check failed: {0}
SelfStateScript=Self-update is only available in the EXE version.
SelfBtnCheck=Check for updates
SelfBtnInstall=Install now
SelfBtnNotes=What's new?
SelfChkStart=Check for updater updates at startup
SelfAsk=A new version of Eden Updater is available.\n\nInstalled: {0}\nNew: {1}\n\nUpdate now? The updater will restart afterwards.
SelfDownloading=Downloading updater {0}...
SelfUpdated=Updater updated to version {0}.
NavGames=Games
GamesSearch=Search games...
GamesStart=Start game
GamesFull=Start in fullscreen
GamesInfo={0} games from {1} folders
GamesEmpty=No games found. In Eden, add a game folder (File → Add New Game Directory), then click Reload here.
GamesNoEden=Eden is not installed yet.
GamesScanning=Searching for games...
LogGameStart=Starting {0}...
ThBaseDark=Dark
ThBaseBlack=Black
ThBaseLight=Light
ThColCyan=Cyan
ThColBlue=Blue
ThColIndigo=Indigo
ThColViolet=Violet
ThColPink=Pink
ThColRed=Red
ThColOrange=Orange
ThColGold=Gold
ThColGreen=Green
ThColGrey=Grey
ThColSand=Sand
ThCustom=Custom theme
ThTabPresets=Presets
ThTabCustom=Custom
ThSlotBg=Background
ThSlotPanel=Surfaces
ThSlotText=Text
ThSlotAccent=Accent
ThCustomHint=Pick a color on the left and adjust it on the right. The preview updates instantly.
ThContrast=Readability {0} : 1
ThContrastOk=good
ThContrastLow=too low, text will be adjusted automatically
GamesClose=Close updater when a game starts
NavMods=Mods
ModsInfo={0} mods for {1} games
ModsScanning=Searching for mods...
ModsInstalling=Installing mod...
ModsFolder=Open mod folder
ModsAdd=Add mod...
ModsDelete=Delete
ModsSelectGame=Select a game on the left.
ModsGameInfo={0} mods · {1} active
ModsNoMods=no mods
ModsEmptyGame=No mods installed for this game. Use 'Add mod...' to add a ZIP or copy mod folders into the mod folder.
ModsUnknownGame=Unknown game
ModsEdenRunning=Eden is running. Close Eden to change mods, otherwise Eden overwrites the changes when it exits.
ModsAskDelete=Really delete mod '{0}'?\n\nThe folder will be moved to the Recycle Bin.
ModsDeleted=Mod deleted: {0}
ModsAdded=Mod added: {0}
ModsToggledOn=Mod enabled: {0}
ModsToggledOff=Mod disabled: {0}
'@
es = @'
Name=Español
Culture=es-ES
AppSubtitle=Actualiza a la última nightly o instala versiones anteriores
NavVersions=Versiones
NavNotes=Notas de versión
NavSettings=Ajustes
CardInstalled=INSTALADA
CardLatest=MÁS RECIENTE
BtnUpdate=Actualizar a la última
BtnUpToDate=Actualizado
BtnLaunch=Iniciar Eden
BtnInstallSel=Instalar esta versión
BtnReinstall=Reinstalar
BtnMore=Cargar más
BtnReload=Recargar
BtnRestore=Restaurar copia de seguridad
BtnRestoreTo=Volver a {0}
ListInfo={0} versiones cargadas
NotInstalled=no instalado
NotesHeader=NOTAS DE VERSIÓN
NotesHintPage=Para la versión seleccionada en la página Versiones.
NotesHintSide=Para la versión seleccionada.
NotesWeb=Abrir en el navegador
NotesSelect=Selecciona una versión en la lista.
NotesLoading=Cargando notas de versión...
NotesError=No se pudieron cargar las notas de versión:
NotesNone=Esta versión no tiene notas de versión.
SetPath=Carpeta de instalación
SetBrowse=Examinar...
SetBrowseTitle=Elige la carpeta de instalación de Eden
SetVariant=Variante de compilación
SetVariantHint=La lista se obtiene de las versiones cargadas (solo compilaciones compatibles con Windows).
VarRecommended=Recomendado: PGO (Windows, amd64)
VarCount={0}   ({1} versiones)
VarCustom=Filtro propio (regex)...
SetPattern=Filtro propio (regex sobre el enlace de descarga)
SetPages=Versiones a cargar (páginas, de 1 a 10)
SetNotes=Mostrar notas de versión
NotesOptPage=Página propia (botón 'Notas de versión' arriba)
NotesOptSide=Junto a la lista de versiones
SetTheme=Esquema de colores
SetThemePick=Elegir tema...
SetLanguage=Idioma
LangAuto=Automático ({0})
SetLanguageHint=Automático usa el idioma de Windows. Si no es compatible, se usa el alemán.
ChkBackup=Crear una copia de seguridad de la versión anterior antes de actualizar
ChkStart=Iniciar Eden automáticamente tras actualizar/instalar
ChkClose=Cerrar el actualizador automáticamente al iniciar Eden
ChkAuto=Buscar actualizaciones al iniciar el programa
ChkAutoInstall=Instalar automáticamente las actualizaciones encontradas (solo al iniciar)
Save=Guardar
Cancel=Cancelar
Apply=Aplicar
Yes=Sí
No=No
OK=Aceptar
DlgWarning=Aviso
DlgError=Error
DlgQuestion=Confirmar
DlgInfo=Información
ThemeTag=TEMA
ThemeTitle=Elegir tema
ThemeHint=Un clic muestra el tema al instante como vista previa.
StReady=Listo
StSearching=Buscando versiones...
StLoadError=Error al cargar
StError=Error
LogInstall=>> Instalando {0}
LogRestore=>> Restaurando copia de seguridad
LogEdenStarted=Eden iniciado.
LogThemeSaved=Tema guardado: {0}
LogSettingsSaved=Ajustes guardados.
LogCancelReq=Cancelación solicitada...
LogAutoOff=La búsqueda automática está desactivada. Haz clic en '{0}'.
ErrPrefix=ERROR:
ErrNoExe=No se encontró eden.exe:
ErrNoPath=Falta la carpeta de instalación.
ErrNoFilter=Falta el filtro.
ErrPages=El número de páginas debe estar entre 1 y 10.
MsgBusyClose=La operación sigue en curso. Espera a que termine.
AskInstallBackup=¿Instalar la versión {0}?\n\nLa instalación actual será reemplazada (se creará una copia de seguridad).
AskInstallNoBackup=¿Instalar la versión {0}?\n\nLa instalación actual será reemplazada (sin copia de seguridad).
AskRestoreVer=¿Restaurar la versión {0}?\n\nLa versión instalada actualmente será reemplazada. La copia de seguridad se conserva.
AskRestore=¿Restaurar la copia de seguridad?\n\nLa versión instalada actualmente será reemplazada. La copia de seguridad se conserva.
WLoadPage=Cargando lista de versiones (página {0})...
WUnreachable=git.eden-emu.dev no está disponible (HTTP {0}).
WNoReleases=No se encontraron versiones para esta variante de compilación.
WFound={0} versiones encontradas.
WEdenRunning=Eden sigue en ejecución. Ciérralo primero y vuelve a intentarlo.
WDownloading=Descargando {0}...
WDlProgress=Descarga   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Descarga   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Cancelado.
WDlFailed=La descarga falló (código de curl {0}).
WDlDone=Descarga completada ({0:N1} MB en {1:N0} s).
WBackupMaking=Creando copia de seguridad...
WBackupDone=Copia de seguridad creada.
WRemoveOld=Eliminando la versión anterior...
WRemovedOld=Archivos antiguos eliminados.
WExtracting=Extrayendo   {0} / {1} archivos
WExtracted=Extraído.
WInstalledSt=Listo: {0} instalada
WInstalledLog=Eden {0} instalado.
WBackupAt=La copia de seguridad está en: {0}
WNoBackup=No se encontró ninguna copia de seguridad.
WBackupEmpty=La copia de seguridad está vacía.
WRemoveCur=Eliminando la versión actual...
WRemovedCur=Versión actual eliminada.
WRestoring=Restaurando   {0} / {1}
WUnknownVer=desconocida (copia de seguridad)
WRestoredSt=Listo: {0} restaurada
WRestoredLog=Copia de seguridad restaurada: {0}
ChipUpdate=Actualización disponible
GrpInstall=Instalación
GrpLook=Apariencia
GrpBehavior=Comportamiento
LogTitle=Actividad
SetStoredAt=Los ajustes se guardan en la carpeta de instalación: {0}
FirstRunAsk=Aún no se encontró ninguna instalación de Eden.\n\n¿Instalar Eden en esta carpeta?\n{0}\n\nElige No para seleccionar otra carpeta.
GrpUpdater=Eden Updater
SelfVersion=Versión instalada: {0}
SelfStateIdle=Aún no se han buscado actualizaciones.
SelfStateChecking=Buscando actualizaciones del actualizador...
SelfStateLatest=El actualizador está al día.
SelfStateFound=Nueva versión disponible: {0}
SelfStateError=La búsqueda falló: {0}
SelfStateScript=La autoactualización solo está disponible en la versión EXE.
SelfBtnCheck=Buscar actualizaciones
SelfBtnInstall=Instalar ahora
SelfBtnNotes=¿Qué hay de nuevo?
SelfChkStart=Buscar actualizaciones del actualizador al iniciar
SelfAsk=Hay una nueva versión de Eden Updater disponible.\n\nInstalada: {0}\nNueva: {1}\n\n¿Actualizar ahora? El actualizador se reiniciará después.
SelfDownloading=Descargando actualizador {0}...
SelfUpdated=Actualizador actualizado a la versión {0}.
NavGames=Juegos
GamesSearch=Buscar juegos...
GamesStart=Iniciar juego
GamesFull=Iniciar en pantalla completa
GamesInfo={0} juegos de {1} carpetas
GamesEmpty=No se encontraron juegos. Añade una carpeta de juegos en Eden (Archivo → Añadir carpeta de juegos) y pulsa Recargar aquí.
GamesNoEden=Eden aún no está instalado.
GamesScanning=Buscando juegos...
LogGameStart=Iniciando {0}...
ThBaseDark=Oscuro
ThBaseBlack=Negro
ThBaseLight=Claro
ThColCyan=Cian
ThColBlue=Azul
ThColIndigo=Índigo
ThColViolet=Violeta
ThColPink=Rosa
ThColRed=Rojo
ThColOrange=Naranja
ThColGold=Oro
ThColGreen=Verde
ThColGrey=Gris
ThColSand=Arena
ThCustom=Tema propio
ThTabPresets=Plantillas
ThTabCustom=Propio
ThSlotBg=Fondo
ThSlotPanel=Superficies
ThSlotText=Texto
ThSlotAccent=Acento
ThCustomHint=Elige un color a la izquierda y ajústalo a la derecha. La vista previa se actualiza al instante.
ThContrast=Legibilidad {0} : 1
ThContrastOk=buena
ThContrastLow=demasiado baja, el texto se ajustará automáticamente
GamesClose=Cerrar el actualizador al iniciar un juego
NavMods=Mods
ModsInfo={0} mods para {1} juegos
ModsScanning=Buscando mods...
ModsInstalling=Instalando mod...
ModsFolder=Abrir carpeta de mods
ModsAdd=Añadir mod...
ModsDelete=Eliminar
ModsSelectGame=Selecciona un juego a la izquierda.
ModsGameInfo={0} mods · {1} activos
ModsNoMods=sin mods
ModsEmptyGame=No hay mods instalados para este juego. Usa 'Añadir mod...' para añadir un ZIP o copia carpetas de mods en la carpeta de mods.
ModsUnknownGame=Juego desconocido
ModsEdenRunning=Eden está en ejecución. Cierra Eden para cambiar mods; si no, Eden sobrescribirá los cambios al cerrarse.
ModsAskDelete=¿Eliminar el mod '{0}'?\n\nLa carpeta se moverá a la papelera de reciclaje.
ModsDeleted=Mod eliminado: {0}
ModsAdded=Mod añadido: {0}
ModsToggledOn=Mod activado: {0}
ModsToggledOff=Mod desactivado: {0}
'@
fr = @'
Name=Français
Culture=fr-FR
AppSubtitle=Mettre à jour vers la dernière nightly ou installer d'anciennes versions
NavVersions=Versions
NavNotes=Notes de version
NavSettings=Paramètres
CardInstalled=INSTALLÉE
CardLatest=DERNIÈRE
BtnUpdate=Passer à la dernière
BtnUpToDate=À jour
BtnLaunch=Lancer Eden
BtnInstallSel=Installer cette version
BtnReinstall=Réinstaller
BtnMore=Charger plus
BtnReload=Actualiser
BtnRestore=Restaurer la sauvegarde
BtnRestoreTo=Revenir à {0}
ListInfo={0} versions chargées
NotInstalled=non installé
NotesHeader=NOTES DE VERSION
NotesHintPage=Pour la version sélectionnée sur la page Versions.
NotesHintSide=Pour la version sélectionnée.
NotesWeb=Ouvrir dans le navigateur
NotesSelect=Sélectionnez une version dans la liste.
NotesLoading=Chargement des notes de version...
NotesError=Impossible de charger les notes de version :
NotesNone=Aucune note de version pour cette version.
SetPath=Dossier d'installation
SetBrowse=Parcourir...
SetBrowseTitle=Choisir le dossier d'installation d'Eden
SetVariant=Variante de build
SetVariantHint=La liste est établie à partir des versions chargées (builds compatibles Windows uniquement).
VarRecommended=Recommandé : PGO (Windows, amd64)
VarCount={0}   ({1} versions)
VarCustom=Filtre personnalisé (regex)...
SetPattern=Filtre personnalisé (regex sur le lien de téléchargement)
SetPages=Versions à charger (pages, de 1 à 10)
SetNotes=Affichage des notes de version
NotesOptPage=Page dédiée (bouton 'Notes de version' en haut)
NotesOptSide=À côté de la liste des versions
SetTheme=Jeu de couleurs
SetThemePick=Choisir un thème...
SetLanguage=Langue
LangAuto=Automatique ({0})
SetLanguageHint=Automatique utilise la langue de Windows. Si elle n'est pas prise en charge, l'allemand est utilisé.
ChkBackup=Créer une sauvegarde de l'ancienne version avant la mise à jour
ChkStart=Lancer Eden automatiquement après la mise à jour/l'installation
ChkClose=Fermer l'outil de mise à jour après le lancement d'Eden
ChkAuto=Rechercher des mises à jour au démarrage du programme
ChkAutoInstall=Installer automatiquement les mises à jour trouvées (uniquement au démarrage)
Save=Enregistrer
Cancel=Annuler
Apply=Appliquer
Yes=Oui
No=Non
OK=OK
DlgWarning=Avertissement
DlgError=Erreur
DlgQuestion=Confirmation
DlgInfo=Info
ThemeTag=THÈME
ThemeTitle=Choisir un thème
ThemeHint=Un clic affiche aussitôt un aperçu du thème.
StReady=Prêt
StSearching=Recherche des versions...
StLoadError=Erreur de chargement
StError=Erreur
LogInstall=>> Installation de {0}
LogRestore=>> Restauration de la sauvegarde
LogEdenStarted=Eden lancé.
LogThemeSaved=Thème enregistré : {0}
LogSettingsSaved=Paramètres enregistrés.
LogCancelReq=Annulation demandée...
LogAutoOff=La recherche automatique est désactivée. Cliquez sur '{0}'.
ErrPrefix=ERREUR :
ErrNoExe=eden.exe introuvable :
ErrNoPath=Le dossier d'installation est manquant.
ErrNoFilter=Le filtre est manquant.
ErrPages=Le nombre de pages doit être compris entre 1 et 10.
MsgBusyClose=L'opération est encore en cours. Veuillez patienter jusqu'à la fin.
AskInstallBackup=Installer la version {0} ?\n\nL'installation actuelle sera remplacée (une sauvegarde sera créée).
AskInstallNoBackup=Installer la version {0} ?\n\nL'installation actuelle sera remplacée (sans sauvegarde).
AskRestoreVer=Restaurer la version {0} ?\n\nLa version actuellement installée sera remplacée. La sauvegarde est conservée.
AskRestore=Restaurer la sauvegarde ?\n\nLa version actuellement installée sera remplacée. La sauvegarde est conservée.
WLoadPage=Chargement de la liste des versions (page {0})...
WUnreachable=git.eden-emu.dev est inaccessible (HTTP {0}).
WNoReleases=Aucune version trouvée pour cette variante de build.
WFound={0} versions trouvées.
WEdenRunning=Eden est encore en cours d'exécution. Fermez-le d'abord, puis réessayez.
WDownloading=Téléchargement de {0}...
WDlProgress=Téléchargement   {0:N1} / {1:N1} Mo   ·   {2:N1} Mo/s
WDlProgressNoSize=Téléchargement   {0:N1} Mo   ·   {1:N1} Mo/s
WCancelled=Annulé.
WDlFailed=Échec du téléchargement (code curl {0}).
WDlDone=Téléchargement terminé ({0:N1} Mo en {1:N0} s).
WBackupMaking=Création de la sauvegarde...
WBackupDone=Sauvegarde créée.
WRemoveOld=Suppression de l'ancienne version...
WRemovedOld=Anciens fichiers supprimés.
WExtracting=Extraction   {0} / {1} fichiers
WExtracted=Extraction terminée.
WInstalledSt=Terminé : {0} installée
WInstalledLog=Eden {0} installé.
WBackupAt=La sauvegarde se trouve ici : {0}
WNoBackup=Aucune sauvegarde trouvée.
WBackupEmpty=La sauvegarde est vide.
WRemoveCur=Suppression de la version actuelle...
WRemovedCur=Version actuelle supprimée.
WRestoring=Restauration   {0} / {1}
WUnknownVer=inconnue (sauvegarde)
WRestoredSt=Terminé : {0} restaurée
WRestoredLog=Sauvegarde restaurée : {0}
ChipUpdate=Mise à jour disponible
GrpInstall=Installation
GrpLook=Apparence
GrpBehavior=Comportement
LogTitle=Activité
SetStoredAt=Les paramètres sont enregistrés dans le dossier d'installation : {0}
FirstRunAsk=Aucune installation d'Eden trouvée.\n\nInstaller Eden dans ce dossier ?\n{0}\n\nChoisissez Non pour sélectionner un autre dossier.
GrpUpdater=Eden Updater
SelfVersion=Version installée : {0}
SelfStateIdle=Aucune recherche de mise à jour effectuée.
SelfStateChecking=Recherche de mises à jour de l'outil...
SelfStateLatest=L'outil de mise à jour est à jour.
SelfStateFound=Nouvelle version disponible : {0}
SelfStateError=Échec de la recherche : {0}
SelfStateScript=La mise à jour automatique n'est disponible que dans la version EXE.
SelfBtnCheck=Rechercher des mises à jour
SelfBtnInstall=Installer maintenant
SelfBtnNotes=Quoi de neuf ?
SelfChkStart=Rechercher des mises à jour de l'outil au démarrage
SelfAsk=Une nouvelle version d'Eden Updater est disponible.\n\nInstallée : {0}\nNouvelle : {1}\n\nMettre à jour maintenant ? L'outil redémarrera ensuite.
SelfDownloading=Téléchargement de l'outil {0}...
SelfUpdated=Outil mis à jour vers la version {0}.
NavGames=Jeux
GamesSearch=Rechercher des jeux...
GamesStart=Lancer le jeu
GamesFull=Lancer en plein écran
GamesInfo={0} jeux dans {1} dossiers
GamesEmpty=Aucun jeu trouvé. Ajoutez un dossier de jeux dans Eden (Fichier → Ajouter un dossier de jeux), puis cliquez ici sur Actualiser.
GamesNoEden=Eden n'est pas encore installé.
GamesScanning=Recherche des jeux...
LogGameStart=Lancement de {0}...
ThBaseDark=Sombre
ThBaseBlack=Noir
ThBaseLight=Clair
ThColCyan=Cyan
ThColBlue=Bleu
ThColIndigo=Indigo
ThColViolet=Violet
ThColPink=Rose
ThColRed=Rouge
ThColOrange=Orange
ThColGold=Or
ThColGreen=Vert
ThColGrey=Gris
ThColSand=Sable
ThCustom=Thème personnalisé
ThTabPresets=Modèles
ThTabCustom=Personnalisé
ThSlotBg=Arrière-plan
ThSlotPanel=Surfaces
ThSlotText=Texte
ThSlotAccent=Accent
ThCustomHint=Choisissez une couleur à gauche et ajustez-la à droite. L'aperçu est immédiat.
ThContrast=Lisibilité {0} : 1
ThContrastOk=bonne
ThContrastLow=trop faible, le texte sera ajusté automatiquement
GamesClose=Fermer l'outil au lancement du jeu
NavMods=Mods
ModsInfo={0} mods pour {1} jeux
ModsScanning=Recherche des mods...
ModsInstalling=Installation du mod...
ModsFolder=Ouvrir le dossier des mods
ModsAdd=Ajouter un mod...
ModsDelete=Supprimer
ModsSelectGame=Sélectionnez un jeu à gauche.
ModsGameInfo={0} mods · {1} actifs
ModsNoMods=aucun mod
ModsEmptyGame=Aucun mod installé pour ce jeu. Utilisez 'Ajouter un mod...' pour ajouter un ZIP ou copiez des dossiers de mods dans le dossier des mods.
ModsUnknownGame=Jeu inconnu
ModsEdenRunning=Eden est en cours d'exécution. Fermez Eden pour modifier les mods, sinon Eden écrasera les changements à sa fermeture.
ModsAskDelete=Supprimer vraiment le mod '{0}' ?\n\nLe dossier sera déplacé dans la corbeille.
ModsDeleted=Mod supprimé : {0}
ModsAdded=Mod ajouté : {0}
ModsToggledOn=Mod activé : {0}
ModsToggledOff=Mod désactivé : {0}
'@
it = @'
Name=Italiano
Culture=it-IT
AppSubtitle=Aggiorna all'ultima nightly o installa versioni precedenti
NavVersions=Versioni
NavNotes=Note di rilascio
NavSettings=Impostazioni
CardInstalled=INSTALLATA
CardLatest=PIÙ RECENTE
BtnUpdate=Aggiorna all'ultima
BtnUpToDate=Aggiornato
BtnLaunch=Avvia Eden
BtnInstallSel=Installa questa versione
BtnReinstall=Reinstalla
BtnMore=Carica altre
BtnReload=Ricarica
BtnRestore=Ripristina backup
BtnRestoreTo=Torna a {0}
ListInfo={0} versioni caricate
NotInstalled=non installato
NotesHeader=NOTE DI RILASCIO
NotesHintPage=Per la versione selezionata nella pagina Versioni.
NotesHintSide=Per la versione selezionata.
NotesWeb=Apri nel browser
NotesSelect=Seleziona una versione nell'elenco.
NotesLoading=Caricamento note di rilascio...
NotesError=Impossibile caricare le note di rilascio:
NotesNone=Non ci sono note di rilascio per questa versione.
SetPath=Cartella di installazione
SetBrowse=Sfoglia...
SetBrowseTitle=Scegli la cartella di installazione di Eden
SetVariant=Variante di build
SetVariantHint=L'elenco viene ricavato dalle versioni caricate (solo build compatibili con Windows).
VarRecommended=Consigliato: PGO (Windows, amd64)
VarCount={0}   ({1} versioni)
VarCustom=Filtro personalizzato (regex)...
SetPattern=Filtro personalizzato (regex sul link di download)
SetPages=Versioni da caricare (pagine, da 1 a 10)
SetNotes=Visualizzazione note di rilascio
NotesOptPage=Pagina dedicata (pulsante 'Note di rilascio' in alto)
NotesOptSide=Accanto all'elenco delle versioni
SetTheme=Combinazione di colori
SetThemePick=Scegli tema...
SetLanguage=Lingua
LangAuto=Automatica ({0})
SetLanguageHint=Automatica usa la lingua di Windows. Se non è supportata, viene usato il tedesco.
ChkBackup=Crea un backup della versione precedente prima dell'aggiornamento
ChkStart=Avvia Eden automaticamente dopo aggiornamento/installazione
ChkClose=Chiudi l'updater automaticamente dopo l'avvio di Eden
ChkAuto=Cerca aggiornamenti all'avvio del programma
ChkAutoInstall=Installa automaticamente gli aggiornamenti trovati (solo all'avvio)
Save=Salva
Cancel=Annulla
Apply=Applica
Yes=Sì
No=No
OK=OK
DlgWarning=Avviso
DlgError=Errore
DlgQuestion=Conferma
DlgInfo=Info
ThemeTag=TEMA
ThemeTitle=Scegli tema
ThemeHint=Un clic mostra subito l'anteprima del tema.
StReady=Pronto
StSearching=Ricerca versioni...
StLoadError=Errore durante il caricamento
StError=Errore
LogInstall=>> Installazione di {0}
LogRestore=>> Ripristino del backup
LogEdenStarted=Eden avviato.
LogThemeSaved=Tema salvato: {0}
LogSettingsSaved=Impostazioni salvate.
LogCancelReq=Annullamento richiesto...
LogAutoOff=La ricerca automatica è disattivata. Clicca su '{0}'.
ErrPrefix=ERRORE:
ErrNoExe=eden.exe non trovato:
ErrNoPath=Manca la cartella di installazione.
ErrNoFilter=Manca il filtro.
ErrPages=Il numero di pagine deve essere compreso tra 1 e 10.
MsgBusyClose=L'operazione è ancora in corso. Attendi che sia completata.
AskInstallBackup=Installare la versione {0}?\n\nL'installazione attuale verrà sostituita (verrà creato un backup).
AskInstallNoBackup=Installare la versione {0}?\n\nL'installazione attuale verrà sostituita (senza backup).
AskRestoreVer=Ripristinare la versione {0}?\n\nLa versione attualmente installata verrà sostituita. Il backup viene conservato.
AskRestore=Ripristinare il backup?\n\nLa versione attualmente installata verrà sostituita. Il backup viene conservato.
WLoadPage=Caricamento elenco versioni (pagina {0})...
WUnreachable=git.eden-emu.dev non raggiungibile (HTTP {0}).
WNoReleases=Nessuna versione trovata per questa variante di build.
WFound={0} versioni trovate.
WEdenRunning=Eden è ancora in esecuzione. Chiudilo prima e riprova.
WDownloading=Download di {0}...
WDlProgress=Download   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Download   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Annullato.
WDlFailed=Download non riuscito (codice curl {0}).
WDlDone=Download completato ({0:N1} MB in {1:N0} s).
WBackupMaking=Creazione del backup...
WBackupDone=Backup creato.
WRemoveOld=Rimozione della versione precedente...
WRemovedOld=File precedenti rimossi.
WExtracting=Estrazione   {0} / {1} file
WExtracted=Estrazione completata.
WInstalledSt=Fatto: {0} installata
WInstalledLog=Eden {0} installato.
WBackupAt=Il backup si trova in: {0}
WNoBackup=Nessun backup trovato.
WBackupEmpty=Il backup è vuoto.
WRemoveCur=Rimozione della versione attuale...
WRemovedCur=Versione attuale rimossa.
WRestoring=Ripristino   {0} / {1}
WUnknownVer=sconosciuta (backup)
WRestoredSt=Fatto: {0} ripristinata
WRestoredLog=Backup ripristinato: {0}
ChipUpdate=Aggiornamento disponibile
GrpInstall=Installazione
GrpLook=Aspetto
GrpBehavior=Comportamento
LogTitle=Attività
SetStoredAt=Le impostazioni vengono salvate nella cartella di installazione: {0}
FirstRunAsk=Nessuna installazione di Eden trovata.\n\nInstallare Eden in questa cartella?\n{0}\n\nScegli No per selezionare un'altra cartella.
GrpUpdater=Eden Updater
SelfVersion=Versione installata: {0}
SelfStateIdle=Nessuna ricerca di aggiornamenti effettuata.
SelfStateChecking=Ricerca aggiornamenti dell'updater...
SelfStateLatest=L'updater è aggiornato.
SelfStateFound=Nuova versione disponibile: {0}
SelfStateError=Ricerca non riuscita: {0}
SelfStateScript=L'aggiornamento automatico è disponibile solo nella versione EXE.
SelfBtnCheck=Cerca aggiornamenti
SelfBtnInstall=Installa ora
SelfBtnNotes=Novità
SelfChkStart=Cerca aggiornamenti dell'updater all'avvio
SelfAsk=È disponibile una nuova versione di Eden Updater.\n\nInstallata: {0}\nNuova: {1}\n\nAggiornare ora? L'updater verrà riavviato.
SelfDownloading=Download dell'updater {0}...
SelfUpdated=Updater aggiornato alla versione {0}.
NavGames=Giochi
GamesSearch=Cerca giochi...
GamesStart=Avvia gioco
GamesFull=Avvia a schermo intero
GamesInfo={0} giochi da {1} cartelle
GamesEmpty=Nessun gioco trovato. Aggiungi una cartella di giochi in Eden (File → Aggiungi cartella giochi), poi clicca qui su Ricarica.
GamesNoEden=Eden non è ancora installato.
GamesScanning=Ricerca giochi...
LogGameStart=Avvio di {0}...
ThBaseDark=Scuro
ThBaseBlack=Nero
ThBaseLight=Chiaro
ThColCyan=Ciano
ThColBlue=Blu
ThColIndigo=Indaco
ThColViolet=Viola
ThColPink=Rosa
ThColRed=Rosso
ThColOrange=Arancione
ThColGold=Oro
ThColGreen=Verde
ThColGrey=Grigio
ThColSand=Sabbia
ThCustom=Tema personalizzato
ThTabPresets=Modelli
ThTabCustom=Personalizzato
ThSlotBg=Sfondo
ThSlotPanel=Superfici
ThSlotText=Testo
ThSlotAccent=Accento
ThCustomHint=Scegli un colore a sinistra e regolalo a destra. L'anteprima è immediata.
ThContrast=Leggibilità {0} : 1
ThContrastOk=buona
ThContrastLow=troppo bassa, il testo verrà adattato automaticamente
GamesClose=Chiudi l'updater all'avvio del gioco
NavMods=Mod
ModsInfo={0} mod per {1} giochi
ModsScanning=Ricerca mod...
ModsInstalling=Installazione mod...
ModsFolder=Apri cartella mod
ModsAdd=Aggiungi mod...
ModsDelete=Elimina
ModsSelectGame=Seleziona un gioco a sinistra.
ModsGameInfo={0} mod · {1} attive
ModsNoMods=nessuna mod
ModsEmptyGame=Nessuna mod installata per questo gioco. Usa 'Aggiungi mod...' per aggiungere uno ZIP o copia le cartelle delle mod nella cartella mod.
ModsUnknownGame=Gioco sconosciuto
ModsEdenRunning=Eden è in esecuzione. Chiudi Eden per modificare le mod, altrimenti Eden sovrascrive le modifiche alla chiusura.
ModsAskDelete=Eliminare davvero la mod '{0}'?\n\nLa cartella verrà spostata nel Cestino.
ModsDeleted=Mod eliminata: {0}
ModsAdded=Mod aggiunta: {0}
ModsToggledOn=Mod attivata: {0}
ModsToggledOff=Mod disattivata: {0}
'@
pt = @'
Name=Português
Culture=pt-BR
AppSubtitle=Atualize para a nightly mais recente ou instale versões anteriores
NavVersions=Versões
NavNotes=Notas da versão
NavSettings=Configurações
CardInstalled=INSTALADA
CardLatest=MAIS RECENTE
BtnUpdate=Atualizar para a mais recente
BtnUpToDate=Atualizado
BtnLaunch=Iniciar Eden
BtnInstallSel=Instalar esta versão
BtnReinstall=Reinstalar
BtnMore=Carregar mais
BtnReload=Recarregar
BtnRestore=Restaurar backup
BtnRestoreTo=Voltar para {0}
ListInfo={0} versões carregadas
NotInstalled=não instalado
NotesHeader=NOTAS DA VERSÃO
NotesHintPage=Para a versão selecionada na página Versões.
NotesHintSide=Para a versão selecionada.
NotesWeb=Abrir no navegador
NotesSelect=Selecione uma versão na lista.
NotesLoading=Carregando notas da versão...
NotesError=Não foi possível carregar as notas da versão:
NotesNone=Não há notas para esta versão.
SetPath=Pasta de instalação
SetBrowse=Procurar...
SetBrowseTitle=Escolha a pasta de instalação do Eden
SetVariant=Variante de build
SetVariantHint=A lista é obtida das versões carregadas (somente builds compatíveis com Windows).
VarRecommended=Recomendado: PGO (Windows, amd64)
VarCount={0}   ({1} versões)
VarCustom=Filtro próprio (regex)...
SetPattern=Filtro próprio (regex no link de download)
SetPages=Versões a carregar (páginas, de 1 a 10)
SetNotes=Exibição das notas da versão
NotesOptPage=Página própria (botão 'Notas da versão' no topo)
NotesOptSide=Ao lado da lista de versões
SetTheme=Esquema de cores
SetThemePick=Escolher tema...
SetLanguage=Idioma
LangAuto=Automático ({0})
SetLanguageHint=Automático usa o idioma do Windows. Se não for compatível, o alemão é usado.
ChkBackup=Criar um backup da versão antiga antes de atualizar
ChkStart=Iniciar o Eden automaticamente após atualizar/instalar
ChkClose=Fechar o atualizador automaticamente após iniciar o Eden
ChkAuto=Procurar atualizações ao iniciar o programa
ChkAutoInstall=Instalar automaticamente as atualizações encontradas (somente ao iniciar)
Save=Salvar
Cancel=Cancelar
Apply=Aplicar
Yes=Sim
No=Não
OK=OK
DlgWarning=Aviso
DlgError=Erro
DlgQuestion=Confirmar
DlgInfo=Info
ThemeTag=TEMA
ThemeTitle=Escolher tema
ThemeHint=Um clique mostra o tema na hora como prévia.
StReady=Pronto
StSearching=Procurando versões...
StLoadError=Erro ao carregar
StError=Erro
LogInstall=>> Instalando {0}
LogRestore=>> Restaurando backup
LogEdenStarted=Eden iniciado.
LogThemeSaved=Tema salvo: {0}
LogSettingsSaved=Configurações salvas.
LogCancelReq=Cancelamento solicitado...
LogAutoOff=A busca automática está desativada. Clique em '{0}'.
ErrPrefix=ERRO:
ErrNoExe=eden.exe não encontrado:
ErrNoPath=Falta a pasta de instalação.
ErrNoFilter=Falta o filtro.
ErrPages=O número de páginas deve estar entre 1 e 10.
MsgBusyClose=A operação ainda está em andamento. Aguarde até terminar.
AskInstallBackup=Instalar a versão {0}?\n\nA instalação atual será substituída (um backup será criado).
AskInstallNoBackup=Instalar a versão {0}?\n\nA instalação atual será substituída (sem backup).
AskRestoreVer=Restaurar a versão {0}?\n\nA versão instalada atualmente será substituída. O backup é mantido.
AskRestore=Restaurar o backup?\n\nA versão instalada atualmente será substituída. O backup é mantido.
WLoadPage=Carregando lista de versões (página {0})...
WUnreachable=git.eden-emu.dev inacessível (HTTP {0}).
WNoReleases=Nenhuma versão encontrada para esta variante de build.
WFound={0} versões encontradas.
WEdenRunning=O Eden ainda está em execução. Feche-o primeiro e tente novamente.
WDownloading=Baixando {0}...
WDlProgress=Download   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Download   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Cancelado.
WDlFailed=Falha no download (código curl {0}).
WDlDone=Download concluído ({0:N1} MB em {1:N0} s).
WBackupMaking=Criando backup...
WBackupDone=Backup criado.
WRemoveOld=Removendo versão antiga...
WRemovedOld=Arquivos antigos removidos.
WExtracting=Extraindo   {0} / {1} arquivos
WExtracted=Extração concluída.
WInstalledSt=Concluído: {0} instalada
WInstalledLog=Eden {0} instalado.
WBackupAt=O backup está em: {0}
WNoBackup=Nenhum backup encontrado.
WBackupEmpty=O backup está vazio.
WRemoveCur=Removendo versão atual...
WRemovedCur=Versão atual removida.
WRestoring=Restaurando   {0} / {1}
WUnknownVer=desconhecida (backup)
WRestoredSt=Concluído: {0} restaurada
WRestoredLog=Backup restaurado: {0}
ChipUpdate=Atualização disponível
GrpInstall=Instalação
GrpLook=Aparência
GrpBehavior=Comportamento
LogTitle=Atividade
SetStoredAt=As configurações são salvas na pasta de instalação: {0}
FirstRunAsk=Nenhuma instalação do Eden encontrada.\n\nInstalar o Eden nesta pasta?\n{0}\n\nEscolha Não para selecionar outra pasta.
GrpUpdater=Eden Updater
SelfVersion=Versão instalada: {0}
SelfStateIdle=Ainda não foram procuradas atualizações.
SelfStateChecking=Procurando atualizações do atualizador...
SelfStateLatest=O atualizador está atualizado.
SelfStateFound=Nova versão disponível: {0}
SelfStateError=A busca falhou: {0}
SelfStateScript=A autoatualização só está disponível na versão EXE.
SelfBtnCheck=Procurar atualizações
SelfBtnInstall=Instalar agora
SelfBtnNotes=O que há de novo?
SelfChkStart=Procurar atualizações do atualizador ao iniciar
SelfAsk=Uma nova versão do Eden Updater está disponível.\n\nInstalada: {0}\nNova: {1}\n\nAtualizar agora? O atualizador será reiniciado em seguida.
SelfDownloading=Baixando atualizador {0}...
SelfUpdated=Atualizador atualizado para a versão {0}.
NavGames=Jogos
GamesSearch=Pesquisar jogos...
GamesStart=Iniciar jogo
GamesFull=Iniciar em tela cheia
GamesInfo={0} jogos de {1} pastas
GamesEmpty=Nenhum jogo encontrado. Adicione uma pasta de jogos no Eden (Arquivo → Adicionar pasta de jogos) e clique em Recarregar aqui.
GamesNoEden=O Eden ainda não está instalado.
GamesScanning=Procurando jogos...
LogGameStart=Iniciando {0}...
ThBaseDark=Escuro
ThBaseBlack=Preto
ThBaseLight=Claro
ThColCyan=Ciano
ThColBlue=Azul
ThColIndigo=Índigo
ThColViolet=Violeta
ThColPink=Rosa
ThColRed=Vermelho
ThColOrange=Laranja
ThColGold=Dourado
ThColGreen=Verde
ThColGrey=Cinza
ThColSand=Areia
ThCustom=Tema próprio
ThTabPresets=Modelos
ThTabCustom=Próprio
ThSlotBg=Fundo
ThSlotPanel=Superfícies
ThSlotText=Texto
ThSlotAccent=Destaque
ThCustomHint=Escolha uma cor à esquerda e ajuste-a à direita. A prévia é atualizada na hora.
ThContrast=Legibilidade {0} : 1
ThContrastOk=boa
ThContrastLow=baixa demais, o texto será ajustado automaticamente
GamesClose=Fechar o atualizador ao iniciar o jogo
NavMods=Mods
ModsInfo={0} mods para {1} jogos
ModsScanning=Procurando mods...
ModsInstalling=Instalando mod...
ModsFolder=Abrir pasta de mods
ModsAdd=Adicionar mod...
ModsDelete=Excluir
ModsSelectGame=Selecione um jogo à esquerda.
ModsGameInfo={0} mods · {1} ativos
ModsNoMods=sem mods
ModsEmptyGame=Nenhum mod instalado para este jogo. Use 'Adicionar mod...' para adicionar um ZIP ou copie pastas de mods para a pasta de mods.
ModsUnknownGame=Jogo desconhecido
ModsEdenRunning=O Eden está em execução. Feche o Eden para alterar mods, senão o Eden sobrescreve as alterações ao fechar.
ModsAskDelete=Excluir mesmo o mod '{0}'?\n\nA pasta será movida para a Lixeira.
ModsDeleted=Mod excluído: {0}
ModsAdded=Mod adicionado: {0}
ModsToggledOn=Mod ativado: {0}
ModsToggledOff=Mod desativado: {0}
'@
nl = @'
Name=Nederlands
Culture=nl-NL
AppSubtitle=Bijwerken naar de nieuwste nightly of oudere versies installeren
NavVersions=Versies
NavNotes=Patchnotes
NavSettings=Instellingen
CardInstalled=GEÏNSTALLEERD
CardLatest=NIEUWSTE
BtnUpdate=Bijwerken naar nieuwste
BtnUpToDate=Up-to-date
BtnLaunch=Eden starten
BtnInstallSel=Deze versie installeren
BtnReinstall=Opnieuw installeren
BtnMore=Meer laden
BtnReload=Opnieuw laden
BtnRestore=Back-up terugzetten
BtnRestoreTo=Terug naar {0}
ListInfo={0} versies geladen
NotInstalled=niet geïnstalleerd
NotesHeader=PATCHNOTES
NotesHintPage=Voor de versie die op de pagina Versies is geselecteerd.
NotesHintSide=Voor de geselecteerde versie.
NotesWeb=Openen in browser
NotesSelect=Selecteer een versie in de lijst.
NotesLoading=Patchnotes laden...
NotesError=Patchnotes konden niet worden geladen:
NotesNone=Er zijn geen patchnotes voor deze versie.
SetPath=Installatiemap
SetBrowse=Bladeren...
SetBrowseTitle=Kies de installatiemap van Eden
SetVariant=Buildvariant
SetVariantHint=De lijst wordt bepaald uit de geladen releases (alleen Windows-compatibele builds).
VarRecommended=Aanbevolen: PGO (Windows, amd64)
VarCount={0}   ({1} releases)
VarCustom=Eigen filter (regex)...
SetPattern=Eigen filter (regex op de downloadlink)
SetPages=Releases laden (pagina's, 1 tot 10)
SetNotes=Weergave van patchnotes
NotesOptPage=Eigen pagina (knop 'Patchnotes' bovenaan)
NotesOptSide=Naast de versielijst
SetTheme=Kleurenschema
SetThemePick=Thema kiezen...
SetLanguage=Taal
LangAuto=Automatisch ({0})
SetLanguageHint=Automatisch gebruikt de taal van Windows. Wordt die niet ondersteund, dan wordt Duits gebruikt.
ChkBackup=Vóór de update een back-up van de oude versie maken
ChkStart=Eden na update/installatie automatisch starten
ChkClose=Updater na het starten van Eden automatisch sluiten
ChkAuto=Bij het starten van het programma naar updates zoeken
ChkAutoInstall=Gevonden updates automatisch installeren (alleen bij het starten)
Save=Opslaan
Cancel=Annuleren
Apply=Toepassen
Yes=Ja
No=Nee
OK=OK
DlgWarning=Melding
DlgError=Fout
DlgQuestion=Bevestigen
DlgInfo=Info
ThemeTag=THEMA
ThemeTitle=Thema kiezen
ThemeHint=Eén klik toont het thema direct als voorbeeld.
StReady=Gereed
StSearching=Zoeken naar releases...
StLoadError=Fout bij het laden
StError=Fout
LogInstall=>> {0} installeren
LogRestore=>> Back-up terugzetten
LogEdenStarted=Eden gestart.
LogThemeSaved=Thema opgeslagen: {0}
LogSettingsSaved=Instellingen opgeslagen.
LogCancelReq=Annuleren aangevraagd...
LogAutoOff=Automatisch zoeken staat uit. Klik op '{0}'.
ErrPrefix=FOUT:
ErrNoExe=eden.exe niet gevonden:
ErrNoPath=De installatiemap ontbreekt.
ErrNoFilter=Het filter ontbreekt.
ErrPages=Het aantal pagina's moet tussen 1 en 10 liggen.
MsgBusyClose=De bewerking is nog bezig. Wacht tot deze klaar is.
AskInstallBackup=Versie {0} installeren?\n\nDe huidige installatie wordt vervangen (er wordt een back-up gemaakt).
AskInstallNoBackup=Versie {0} installeren?\n\nDe huidige installatie wordt vervangen (zonder back-up).
AskRestoreVer=Versie {0} terugzetten?\n\nDe momenteel geïnstalleerde versie wordt vervangen. De back-up blijft behouden.
AskRestore=De back-up terugzetten?\n\nDe momenteel geïnstalleerde versie wordt vervangen. De back-up blijft behouden.
WLoadPage=Releaselijst laden (pagina {0})...
WUnreachable=git.eden-emu.dev is niet bereikbaar (HTTP {0}).
WNoReleases=Geen passende releases gevonden voor deze buildvariant.
WFound={0} versies gevonden.
WEdenRunning=Eden draait nog. Sluit het eerst en probeer het opnieuw.
WDownloading={0} downloaden...
WDlProgress=Download   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Download   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Geannuleerd.
WDlFailed=Download mislukt (curl-code {0}).
WDlDone=Download voltooid ({0:N1} MB in {1:N0} s).
WBackupMaking=Back-up maken...
WBackupDone=Back-up gemaakt.
WRemoveOld=Oude versie verwijderen...
WRemovedOld=Oude bestanden verwijderd.
WExtracting=Uitpakken   {0} / {1} bestanden
WExtracted=Uitgepakt.
WInstalledSt=Klaar: {0} geïnstalleerd
WInstalledLog=Eden {0} geïnstalleerd.
WBackupAt=De back-up staat in: {0}
WNoBackup=Geen back-up gevonden.
WBackupEmpty=De back-up is leeg.
WRemoveCur=Huidige versie verwijderen...
WRemovedCur=Huidige versie verwijderd.
WRestoring=Terugzetten   {0} / {1}
WUnknownVer=onbekend (back-up)
WRestoredSt=Klaar: {0} teruggezet
WRestoredLog=Back-up teruggezet: {0}
ChipUpdate=Update beschikbaar
GrpInstall=Installatie
GrpLook=Weergave
GrpBehavior=Gedrag
LogTitle=Activiteit
SetStoredAt=Instellingen worden opgeslagen in de installatiemap: {0}
FirstRunAsk=Nog geen Eden-installatie gevonden.\n\nEden in deze map installeren?\n{0}\n\nKies Nee om een andere map te kiezen.
GrpUpdater=Eden Updater
SelfVersion=Geïnstalleerde versie: {0}
SelfStateIdle=Nog niet naar updates gezocht.
SelfStateChecking=Zoeken naar updates voor de updater...
SelfStateLatest=De updater is up-to-date.
SelfStateFound=Nieuwe versie beschikbaar: {0}
SelfStateError=Zoeken mislukt: {0}
SelfStateScript=Zelf-update is alleen beschikbaar in de EXE-versie.
SelfBtnCheck=Naar updates zoeken
SelfBtnInstall=Nu installeren
SelfBtnNotes=Wat is er nieuw?
SelfChkStart=Bij het starten naar updates voor de updater zoeken
SelfAsk=Er is een nieuwe versie van Eden Updater beschikbaar.\n\nGeïnstalleerd: {0}\nNieuw: {1}\n\nNu bijwerken? De updater start daarna opnieuw.
SelfDownloading=Updater {0} downloaden...
SelfUpdated=Updater bijgewerkt naar versie {0}.
NavGames=Games
GamesSearch=Games zoeken...
GamesStart=Game starten
GamesFull=Op volledig scherm starten
GamesInfo={0} games uit {1} mappen
GamesEmpty=Geen games gevonden. Voeg in Eden een gamemap toe (Bestand → Gamemap toevoegen) en klik hier op Opnieuw laden.
GamesNoEden=Eden is nog niet geïnstalleerd.
GamesScanning=Zoeken naar games...
LogGameStart={0} starten...
ThBaseDark=Donker
ThBaseBlack=Zwart
ThBaseLight=Licht
ThColCyan=Cyaan
ThColBlue=Blauw
ThColIndigo=Indigo
ThColViolet=Violet
ThColPink=Roze
ThColRed=Rood
ThColOrange=Oranje
ThColGold=Goud
ThColGreen=Groen
ThColGrey=Grijs
ThColSand=Zand
ThCustom=Eigen thema
ThTabPresets=Sjablonen
ThTabCustom=Eigen
ThSlotBg=Achtergrond
ThSlotPanel=Vlakken
ThSlotText=Tekst
ThSlotAccent=Accent
ThCustomHint=Kies links een kleur en pas die rechts aan. Het voorbeeld is direct zichtbaar.
ThContrast=Leesbaarheid {0} : 1
ThContrastOk=goed
ThContrastLow=te laag, tekst wordt automatisch aangepast
GamesClose=Updater sluiten bij het starten van een game
NavMods=Mods
ModsInfo={0} mods voor {1} games
ModsScanning=Zoeken naar mods...
ModsInstalling=Mod installeren...
ModsFolder=Modmap openen
ModsAdd=Mod toevoegen...
ModsDelete=Verwijderen
ModsSelectGame=Selecteer links een game.
ModsGameInfo={0} mods · {1} actief
ModsNoMods=geen mods
ModsEmptyGame=Geen mods geïnstalleerd voor deze game. Gebruik 'Mod toevoegen...' voor een ZIP of kopieer modmappen naar de modmap.
ModsUnknownGame=Onbekende game
ModsEdenRunning=Eden draait. Sluit Eden om mods te wijzigen, anders overschrijft Eden de wijzigingen bij het afsluiten.
ModsAskDelete=Mod '{0}' echt verwijderen?\n\nDe map wordt naar de Prullenbak verplaatst.
ModsDeleted=Mod verwijderd: {0}
ModsAdded=Mod toegevoegd: {0}
ModsToggledOn=Mod ingeschakeld: {0}
ModsToggledOff=Mod uitgeschakeld: {0}
'@
pl = @'
Name=Polski
Culture=pl-PL
AppSubtitle=Aktualizuj do najnowszej wersji nightly lub instaluj starsze wersje
NavVersions=Wersje
NavNotes=Lista zmian
NavSettings=Ustawienia
CardInstalled=ZAINSTALOWANA
CardLatest=NAJNOWSZA
BtnUpdate=Aktualizuj do najnowszej
BtnUpToDate=Aktualna
BtnLaunch=Uruchom Eden
BtnInstallSel=Zainstaluj tę wersję
BtnReinstall=Zainstaluj ponownie
BtnMore=Wczytaj więcej
BtnReload=Odśwież
BtnRestore=Przywróć kopię zapasową
BtnRestoreTo=Wróć do {0}
ListInfo=Wczytane wersje: {0}
NotInstalled=nie zainstalowano
NotesHeader=LISTA ZMIAN
NotesHintPage=Dla wersji wybranej na stronie Wersje.
NotesHintSide=Dla wybranej wersji.
NotesWeb=Otwórz w przeglądarce
NotesSelect=Wybierz wersję z listy.
NotesLoading=Wczytywanie listy zmian...
NotesError=Nie udało się wczytać listy zmian:
NotesNone=Ta wersja nie ma listy zmian.
SetPath=Folder instalacji
SetBrowse=Przeglądaj...
SetBrowseTitle=Wybierz folder instalacji Eden
SetVariant=Wariant kompilacji
SetVariantHint=Lista powstaje na podstawie wczytanych wydań (tylko kompilacje zgodne z Windows).
VarRecommended=Zalecane: PGO (Windows, amd64)
VarCount={0}   (wydania: {1})
VarCustom=Własny filtr (regex)...
SetPattern=Własny filtr (regex dla linku pobierania)
SetPages=Wczytywane wydania (strony, od 1 do 10)
SetNotes=Wyświetlanie listy zmian
NotesOptPage=Osobna strona (przycisk 'Lista zmian' u góry)
NotesOptSide=Obok listy wersji
SetTheme=Schemat kolorów
SetThemePick=Wybierz motyw...
SetLanguage=Język
LangAuto=Automatycznie ({0})
SetLanguageHint=Tryb automatyczny używa języka systemu Windows. Jeśli nie jest obsługiwany, używany jest niemiecki.
ChkBackup=Przed aktualizacją utwórz kopię zapasową starej wersji
ChkStart=Uruchom Eden automatycznie po aktualizacji/instalacji
ChkClose=Zamknij aktualizator automatycznie po uruchomieniu Eden
ChkAuto=Sprawdzaj aktualizacje przy starcie programu
ChkAutoInstall=Instaluj znalezione aktualizacje automatycznie (tylko przy starcie)
Save=Zapisz
Cancel=Anuluj
Apply=Zastosuj
Yes=Tak
No=Nie
OK=OK
DlgWarning=Uwaga
DlgError=Błąd
DlgQuestion=Potwierdź
DlgInfo=Informacja
ThemeTag=MOTYW
ThemeTitle=Wybierz motyw
ThemeHint=Kliknięcie od razu pokazuje podgląd motywu.
StReady=Gotowe
StSearching=Wyszukiwanie wydań...
StLoadError=Błąd wczytywania
StError=Błąd
LogInstall=>> Instalowanie {0}
LogRestore=>> Przywracanie kopii zapasowej
LogEdenStarted=Uruchomiono Eden.
LogThemeSaved=Zapisano motyw: {0}
LogSettingsSaved=Zapisano ustawienia.
LogCancelReq=Zażądano anulowania...
LogAutoOff=Automatyczne wyszukiwanie jest wyłączone. Kliknij '{0}'.
ErrPrefix=BŁĄD:
ErrNoExe=Nie znaleziono eden.exe:
ErrNoPath=Brak folderu instalacji.
ErrNoFilter=Brak filtra.
ErrPages=Liczba stron musi wynosić od 1 do 10.
MsgBusyClose=Operacja nadal trwa. Poczekaj na jej zakończenie.
AskInstallBackup=Zainstalować wersję {0}?\n\nObecna instalacja zostanie zastąpiona (zostanie utworzona kopia zapasowa).
AskInstallNoBackup=Zainstalować wersję {0}?\n\nObecna instalacja zostanie zastąpiona (bez kopii zapasowej).
AskRestoreVer=Przywrócić wersję {0}?\n\nObecnie zainstalowana wersja zostanie zastąpiona. Kopia zapasowa zostanie zachowana.
AskRestore=Przywrócić kopię zapasową?\n\nObecnie zainstalowana wersja zostanie zastąpiona. Kopia zapasowa zostanie zachowana.
WLoadPage=Wczytywanie listy wydań (strona {0})...
WUnreachable=git.eden-emu.dev jest niedostępny (HTTP {0}).
WNoReleases=Nie znaleziono pasujących wydań dla tego wariantu kompilacji.
WFound=Znalezione wersje: {0}.
WEdenRunning=Eden nadal działa. Najpierw go zamknij i spróbuj ponownie.
WDownloading=Pobieranie {0}...
WDlProgress=Pobieranie   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=Pobieranie   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=Anulowano.
WDlFailed=Pobieranie nie powiodło się (kod curl {0}).
WDlDone=Pobieranie zakończone ({0:N1} MB w {1:N0} s).
WBackupMaking=Tworzenie kopii zapasowej...
WBackupDone=Utworzono kopię zapasową.
WRemoveOld=Usuwanie starej wersji...
WRemovedOld=Usunięto stare pliki.
WExtracting=Rozpakowywanie   {0} / {1} plików
WExtracted=Rozpakowano.
WInstalledSt=Gotowe: zainstalowano {0}
WInstalledLog=Zainstalowano Eden {0}.
WBackupAt=Kopia zapasowa znajduje się w: {0}
WNoBackup=Nie znaleziono kopii zapasowej.
WBackupEmpty=Kopia zapasowa jest pusta.
WRemoveCur=Usuwanie bieżącej wersji...
WRemovedCur=Usunięto bieżącą wersję.
WRestoring=Przywracanie   {0} / {1}
WUnknownVer=nieznana (kopia zapasowa)
WRestoredSt=Gotowe: przywrócono {0}
WRestoredLog=Przywrócono kopię zapasową: {0}
ChipUpdate=Dostępna aktualizacja
GrpInstall=Instalacja
GrpLook=Wygląd
GrpBehavior=Działanie
LogTitle=Aktywność
SetStoredAt=Ustawienia są zapisywane w folderze instalacji: {0}
FirstRunAsk=Nie znaleziono jeszcze instalacji Eden.\n\nZainstalować Eden w tym folderze?\n{0}\n\nWybierz Nie, aby wskazać inny folder.
GrpUpdater=Eden Updater
SelfVersion=Zainstalowana wersja: {0}
SelfStateIdle=Jeszcze nie sprawdzano aktualizacji.
SelfStateChecking=Sprawdzanie aktualizacji aktualizatora...
SelfStateLatest=Aktualizator jest aktualny.
SelfStateFound=Dostępna nowa wersja: {0}
SelfStateError=Sprawdzanie nie powiodło się: {0}
SelfStateScript=Samoaktualizacja jest dostępna tylko w wersji EXE.
SelfBtnCheck=Sprawdź aktualizacje
SelfBtnInstall=Zainstaluj teraz
SelfBtnNotes=Co nowego?
SelfChkStart=Sprawdzaj aktualizacje aktualizatora przy starcie
SelfAsk=Dostępna jest nowa wersja Eden Updater.\n\nZainstalowana: {0}\nNowa: {1}\n\nZaktualizować teraz? Aktualizator uruchomi się ponownie.
SelfDownloading=Pobieranie aktualizatora {0}...
SelfUpdated=Zaktualizowano aktualizator do wersji {0}.
NavGames=Gry
GamesSearch=Szukaj gier...
GamesStart=Uruchom grę
GamesFull=Uruchom na pełnym ekranie
GamesInfo=Gry: {0} z folderów: {1}
GamesEmpty=Nie znaleziono gier. Dodaj folder z grami w Eden (Plik → Dodaj folder gier), a potem kliknij tutaj Odśwież.
GamesNoEden=Eden nie jest jeszcze zainstalowany.
GamesScanning=Wyszukiwanie gier...
LogGameStart=Uruchamianie {0}...
ThBaseDark=Ciemny
ThBaseBlack=Czarny
ThBaseLight=Jasny
ThColCyan=Cyjan
ThColBlue=Niebieski
ThColIndigo=Indygo
ThColViolet=Fioletowy
ThColPink=Różowy
ThColRed=Czerwony
ThColOrange=Pomarańczowy
ThColGold=Złoty
ThColGreen=Zielony
ThColGrey=Szary
ThColSand=Piaskowy
ThCustom=Własny motyw
ThTabPresets=Szablony
ThTabCustom=Własny
ThSlotBg=Tło
ThSlotPanel=Powierzchnie
ThSlotText=Tekst
ThSlotAccent=Akcent
ThCustomHint=Wybierz kolor po lewej i dopasuj go po prawej. Podgląd widać od razu.
ThContrast=Czytelność {0} : 1
ThContrastOk=dobra
ThContrastLow=za niska, tekst zostanie dopasowany automatycznie
GamesClose=Zamknij aktualizator po uruchomieniu gry
NavMods=Mody
ModsInfo=Mody: {0} dla gier: {1}
ModsScanning=Wyszukiwanie modów...
ModsInstalling=Instalowanie moda...
ModsFolder=Otwórz folder modów
ModsAdd=Dodaj mod...
ModsDelete=Usuń
ModsSelectGame=Wybierz grę po lewej.
ModsGameInfo=Mody: {0} · aktywne: {1}
ModsNoMods=brak modów
ModsEmptyGame=Brak modów dla tej gry. Użyj 'Dodaj mod...', aby dodać ZIP, lub skopiuj foldery modów do folderu modów.
ModsUnknownGame=Nieznana gra
ModsEdenRunning=Eden jest uruchomiony. Zamknij Eden, aby zmieniać mody, inaczej Eden nadpisze zmiany przy zamknięciu.
ModsAskDelete=Na pewno usunąć mod '{0}'?\n\nFolder zostanie przeniesiony do Kosza.
ModsDeleted=Usunięto mod: {0}
ModsAdded=Dodano mod: {0}
ModsToggledOn=Włączono mod: {0}
ModsToggledOff=Wyłączono mod: {0}
'@
tr = @'
Name=Türkçe
Culture=tr-TR
AppSubtitle=En yeni nightly sürümüne güncelleyin veya eski sürümleri yükleyin
NavVersions=Sürümler
NavNotes=Sürüm notları
NavSettings=Ayarlar
CardInstalled=YÜKLÜ
CardLatest=EN YENİ
BtnUpdate=En yeniye güncelle
BtnUpToDate=Güncel
BtnLaunch=Eden'i başlat
BtnInstallSel=Bu sürümü yükle
BtnReinstall=Yeniden yükle
BtnMore=Daha fazla yükle
BtnReload=Yenile
BtnRestore=Yedeği geri yükle
BtnRestoreTo={0} sürümüne dön
ListInfo={0} sürüm yüklendi
NotInstalled=yüklü değil
NotesHeader=SÜRÜM NOTLARI
NotesHintPage=Sürümler sayfasında seçili sürüm için.
NotesHintSide=Seçili sürüm için.
NotesWeb=Tarayıcıda aç
NotesSelect=Listeden bir sürüm seçin.
NotesLoading=Sürüm notları yükleniyor...
NotesError=Sürüm notları yüklenemedi:
NotesNone=Bu sürüm için sürüm notu yok.
SetPath=Kurulum klasörü
SetBrowse=Gözat...
SetBrowseTitle=Eden kurulum klasörünü seçin
SetVariant=Derleme türü
SetVariantHint=Liste, yüklenen sürümlerden oluşturulur (yalnızca Windows uyumlu derlemeler).
VarRecommended=Önerilen: PGO (Windows, amd64)
VarCount={0}   ({1} sürüm)
VarCustom=Özel filtre (regex)...
SetPattern=Özel filtre (indirme bağlantısı için regex)
SetPages=Yüklenecek sürümler (sayfa, 1 ile 10 arası)
SetNotes=Sürüm notlarının gösterimi
NotesOptPage=Ayrı sayfa (üstteki 'Sürüm notları' düğmesi)
NotesOptSide=Sürüm listesinin yanında
SetTheme=Renk şeması
SetThemePick=Tema seç...
SetLanguage=Dil
LangAuto=Otomatik ({0})
SetLanguageHint=Otomatik, Windows dilini kullanır. Desteklenmiyorsa Almanca kullanılır.
ChkBackup=Güncellemeden önce eski sürümün yedeğini oluştur
ChkStart=Güncelleme/kurulumdan sonra Eden'i otomatik başlat
ChkClose=Eden başlatıldıktan sonra güncelleyiciyi otomatik kapat
ChkAuto=Program açılırken güncellemeleri denetle
ChkAutoInstall=Bulunan güncellemeleri otomatik yükle (yalnızca program açılışında)
Save=Kaydet
Cancel=İptal
Apply=Uygula
Yes=Evet
No=Hayır
OK=Tamam
DlgWarning=Uyarı
DlgError=Hata
DlgQuestion=Onayla
DlgInfo=Bilgi
ThemeTag=TEMA
ThemeTitle=Tema seç
ThemeHint=Bir tıklama temayı anında önizler.
StReady=Hazır
StSearching=Sürümler aranıyor...
StLoadError=Yükleme hatası
StError=Hata
LogInstall=>> {0} yükleniyor
LogRestore=>> Yedek geri yükleniyor
LogEdenStarted=Eden başlatıldı.
LogThemeSaved=Tema kaydedildi: {0}
LogSettingsSaved=Ayarlar kaydedildi.
LogCancelReq=İptal istendi...
LogAutoOff=Otomatik arama kapalı. '{0}' düğmesine tıklayın.
ErrPrefix=HATA:
ErrNoExe=eden.exe bulunamadı:
ErrNoPath=Kurulum klasörü eksik.
ErrNoFilter=Filtre eksik.
ErrPages=Sayfa sayısı 1 ile 10 arasında olmalıdır.
MsgBusyClose=İşlem hâlâ sürüyor. Lütfen bitmesini bekleyin.
AskInstallBackup={0} sürümü yüklensin mi?\n\nMevcut kurulum değiştirilecek (yedek oluşturulacak).
AskInstallNoBackup={0} sürümü yüklensin mi?\n\nMevcut kurulum değiştirilecek (yedeksiz).
AskRestoreVer={0} sürümü geri yüklensin mi?\n\nŞu anda yüklü sürüm değiştirilecek. Yedek korunur.
AskRestore=Yedek geri yüklensin mi?\n\nŞu anda yüklü sürüm değiştirilecek. Yedek korunur.
WLoadPage=Sürüm listesi yükleniyor (sayfa {0})...
WUnreachable=git.eden-emu.dev erişilemiyor (HTTP {0}).
WNoReleases=Bu derleme türü için uygun sürüm bulunamadı.
WFound={0} sürüm bulundu.
WEdenRunning=Eden hâlâ çalışıyor. Önce kapatın ve tekrar deneyin.
WDownloading={0} indiriliyor...
WDlProgress=İndirme   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=İndirme   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=İptal edildi.
WDlFailed=İndirme başarısız (curl kodu {0}).
WDlDone=İndirme tamamlandı ({0:N1} MB, {1:N0} sn).
WBackupMaking=Yedek oluşturuluyor...
WBackupDone=Yedek oluşturuldu.
WRemoveOld=Eski sürüm kaldırılıyor...
WRemovedOld=Eski dosyalar kaldırıldı.
WExtracting=Ayıklanıyor   {0} / {1} dosya
WExtracted=Ayıklandı.
WInstalledSt=Tamamlandı: {0} yüklendi
WInstalledLog=Eden {0} yüklendi.
WBackupAt=Yedeğin konumu: {0}
WNoBackup=Yedek bulunamadı.
WBackupEmpty=Yedek boş.
WRemoveCur=Mevcut sürüm kaldırılıyor...
WRemovedCur=Mevcut sürüm kaldırıldı.
WRestoring=Geri yükleniyor   {0} / {1}
WUnknownVer=bilinmiyor (yedek)
WRestoredSt=Tamamlandı: {0} geri yüklendi
WRestoredLog=Yedek geri yüklendi: {0}
ChipUpdate=Güncelleme mevcut
GrpInstall=Kurulum
GrpLook=Görünüm
GrpBehavior=Davranış
LogTitle=Etkinlik
SetStoredAt=Ayarlar kurulum klasörüne kaydedilir: {0}
FirstRunAsk=Henüz bir Eden kurulumu bulunamadı.\n\nEden bu klasöre kurulsun mu?\n{0}\n\nBaşka bir klasör seçmek için Hayır'ı seçin.
GrpUpdater=Eden Updater
SelfVersion=Yüklü sürüm: {0}
SelfStateIdle=Henüz güncelleme aranmadı.
SelfStateChecking=Güncelleyici için güncellemeler aranıyor...
SelfStateLatest=Güncelleyici güncel.
SelfStateFound=Yeni sürüm mevcut: {0}
SelfStateError=Arama başarısız: {0}
SelfStateScript=Kendi kendini güncelleme yalnızca EXE sürümünde kullanılabilir.
SelfBtnCheck=Güncellemeleri denetle
SelfBtnInstall=Şimdi yükle
SelfBtnNotes=Yenilikler
SelfChkStart=Başlangıçta güncelleyici güncellemelerini denetle
SelfAsk=Eden Updater'ın yeni bir sürümü mevcut.\n\nYüklü: {0}\nYeni: {1}\n\nŞimdi güncellensin mi? Güncelleyici ardından yeniden başlar.
SelfDownloading=Güncelleyici {0} indiriliyor...
SelfUpdated=Güncelleyici {0} sürümüne güncellendi.
NavGames=Oyunlar
GamesSearch=Oyun ara...
GamesStart=Oyunu başlat
GamesFull=Tam ekranda başlat
GamesInfo={1} klasörde {0} oyun
GamesEmpty=Oyun bulunamadı. Eden'de bir oyun klasörü ekleyin (Dosya → Oyun klasörü ekle), ardından burada Yenile'ye tıklayın.
GamesNoEden=Eden henüz yüklü değil.
GamesScanning=Oyunlar aranıyor...
LogGameStart={0} başlatılıyor...
ThBaseDark=Koyu
ThBaseBlack=Siyah
ThBaseLight=Açık
ThColCyan=Camgöbeği
ThColBlue=Mavi
ThColIndigo=Çivit
ThColViolet=Mor
ThColPink=Pembe
ThColRed=Kırmızı
ThColOrange=Turuncu
ThColGold=Altın
ThColGreen=Yeşil
ThColGrey=Gri
ThColSand=Kum
ThCustom=Özel tema
ThTabPresets=Şablonlar
ThTabCustom=Özel
ThSlotBg=Arka plan
ThSlotPanel=Yüzeyler
ThSlotText=Metin
ThSlotAccent=Vurgu
ThCustomHint=Soldan bir renk seçin ve sağdan ayarlayın. Önizleme anında görünür.
ThContrast=Okunabilirlik {0} : 1
ThContrastOk=iyi
ThContrastLow=çok düşük, metin otomatik olarak ayarlanacak
GamesClose=Oyun başlarken güncelleyiciyi kapat
NavMods=Modlar
ModsInfo={1} oyun için {0} mod
ModsScanning=Modlar aranıyor...
ModsInstalling=Mod yükleniyor...
ModsFolder=Mod klasörünü aç
ModsAdd=Mod ekle...
ModsDelete=Sil
ModsSelectGame=Soldan bir oyun seçin.
ModsGameInfo={0} mod · {1} etkin
ModsNoMods=mod yok
ModsEmptyGame=Bu oyun için mod yüklü değil. ZIP eklemek için 'Mod ekle...' kullanın veya mod klasörlerini mod klasörüne kopyalayın.
ModsUnknownGame=Bilinmeyen oyun
ModsEdenRunning=Eden çalışıyor. Modları değiştirmek için Eden'i kapatın, aksi halde Eden kapanırken değişikliklerin üzerine yazar.
ModsAskDelete='{0}' modu gerçekten silinsin mi?\n\nKlasör Geri Dönüşüm Kutusu'na taşınacak.
ModsDeleted=Mod silindi: {0}
ModsAdded=Mod eklendi: {0}
ModsToggledOn=Mod etkinleştirildi: {0}
ModsToggledOff=Mod devre dışı: {0}
'@
ru = @'
Name=Русский
Culture=ru-RU
AppSubtitle=Обновление до последней nightly-сборки или установка старых версий
NavVersions=Версии
NavNotes=Список изменений
NavSettings=Настройки
CardInstalled=УСТАНОВЛЕНА
CardLatest=ПОСЛЕДНЯЯ
BtnUpdate=Обновить до последней
BtnUpToDate=Актуально
BtnLaunch=Запустить Eden
BtnInstallSel=Установить эту версию
BtnReinstall=Переустановить
BtnMore=Загрузить ещё
BtnReload=Обновить список
BtnRestore=Восстановить резервную копию
BtnRestoreTo=Вернуться к {0}
ListInfo=Загружено версий: {0}
NotInstalled=не установлено
NotesHeader=СПИСОК ИЗМЕНЕНИЙ
NotesHintPage=Для версии, выбранной на странице «Версии».
NotesHintSide=Для выбранной версии.
NotesWeb=Открыть в браузере
NotesSelect=Выберите версию в списке.
NotesLoading=Загрузка списка изменений...
NotesError=Не удалось загрузить список изменений:
NotesNone=Для этой версии нет списка изменений.
SetPath=Папка установки
SetBrowse=Обзор...
SetBrowseTitle=Выберите папку установки Eden
SetVariant=Вариант сборки
SetVariantHint=Список формируется из загруженных релизов (только сборки для Windows).
VarRecommended=Рекомендуется: PGO (Windows, amd64)
VarCount={0}   (релизов: {1})
VarCustom=Свой фильтр (regex)...
SetPattern=Свой фильтр (regex по ссылке на загрузку)
SetPages=Загружать релизы (страниц, от 1 до 10)
SetNotes=Отображение списка изменений
NotesOptPage=Отдельная страница (кнопка «Список изменений» вверху)
NotesOptSide=Рядом со списком версий
SetTheme=Цветовая схема
SetThemePick=Выбрать тему...
SetLanguage=Язык
LangAuto=Автоматически ({0})
SetLanguageHint=В автоматическом режиме используется язык Windows. Если он не поддерживается, используется немецкий.
ChkBackup=Создавать резервную копию старой версии перед обновлением
ChkStart=Автоматически запускать Eden после обновления/установки
ChkClose=Автоматически закрывать программу обновления после запуска Eden
ChkAuto=Проверять обновления при запуске программы
ChkAutoInstall=Автоматически устанавливать найденные обновления (только при запуске)
Save=Сохранить
Cancel=Отмена
Apply=Применить
Yes=Да
No=Нет
OK=ОК
DlgWarning=Внимание
DlgError=Ошибка
DlgQuestion=Подтверждение
DlgInfo=Информация
ThemeTag=ТЕМА
ThemeTitle=Выбор темы
ThemeHint=Щелчок сразу показывает предпросмотр темы.
StReady=Готово
StSearching=Поиск релизов...
StLoadError=Ошибка загрузки
StError=Ошибка
LogInstall=>> Установка {0}
LogRestore=>> Восстановление резервной копии
LogEdenStarted=Eden запущен.
LogThemeSaved=Тема сохранена: {0}
LogSettingsSaved=Настройки сохранены.
LogCancelReq=Запрошена отмена...
LogAutoOff=Автоматический поиск выключен. Нажмите «{0}».
ErrPrefix=ОШИБКА:
ErrNoExe=eden.exe не найден:
ErrNoPath=Не указана папка установки.
ErrNoFilter=Не указан фильтр.
ErrPages=Количество страниц должно быть от 1 до 10.
MsgBusyClose=Операция ещё выполняется. Дождитесь её завершения.
AskInstallBackup=Установить версию {0}?\n\nТекущая установка будет заменена (будет создана резервная копия).
AskInstallNoBackup=Установить версию {0}?\n\nТекущая установка будет заменена (без резервной копии).
AskRestoreVer=Восстановить версию {0}?\n\nУстановленная сейчас версия будет заменена. Резервная копия сохранится.
AskRestore=Восстановить резервную копию?\n\nУстановленная сейчас версия будет заменена. Резервная копия сохранится.
WLoadPage=Загрузка списка релизов (страница {0})...
WUnreachable=git.eden-emu.dev недоступен (HTTP {0}).
WNoReleases=Для этого варианта сборки подходящих релизов не найдено.
WFound=Найдено версий: {0}.
WEdenRunning=Eden ещё запущен. Сначала закройте его и попробуйте снова.
WDownloading=Загрузка {0}...
WDlProgress=Загрузка   {0:N1} / {1:N1} МБ   ·   {2:N1} МБ/с
WDlProgressNoSize=Загрузка   {0:N1} МБ   ·   {1:N1} МБ/с
WCancelled=Отменено.
WDlFailed=Ошибка загрузки (код curl {0}).
WDlDone=Загрузка завершена ({0:N1} МБ за {1:N0} с).
WBackupMaking=Создание резервной копии...
WBackupDone=Резервная копия создана.
WRemoveOld=Удаление старой версии...
WRemovedOld=Старые файлы удалены.
WExtracting=Распаковка   {0} / {1} файлов
WExtracted=Распаковано.
WInstalledSt=Готово: {0} установлена
WInstalledLog=Eden {0} установлен.
WBackupAt=Резервная копия находится здесь: {0}
WNoBackup=Резервная копия не найдена.
WBackupEmpty=Резервная копия пуста.
WRemoveCur=Удаление текущей версии...
WRemovedCur=Текущая версия удалена.
WRestoring=Восстановление   {0} / {1}
WUnknownVer=неизвестно (резервная копия)
WRestoredSt=Готово: {0} восстановлена
WRestoredLog=Резервная копия восстановлена: {0}
ChipUpdate=Доступно обновление
GrpInstall=Установка
GrpLook=Внешний вид
GrpBehavior=Поведение
LogTitle=Активность
SetStoredAt=Настройки сохраняются в папке установки: {0}
FirstRunAsk=Установка Eden пока не найдена.\n\nУстановить Eden в эту папку?\n{0}\n\nВыберите «Нет», чтобы указать другую папку.
GrpUpdater=Eden Updater
SelfVersion=Установленная версия: {0}
SelfStateIdle=Обновления ещё не проверялись.
SelfStateChecking=Поиск обновлений программы обновления...
SelfStateLatest=Программа обновления актуальна.
SelfStateFound=Доступна новая версия: {0}
SelfStateError=Ошибка проверки: {0}
SelfStateScript=Самообновление доступно только в EXE-версии.
SelfBtnCheck=Проверить обновления
SelfBtnInstall=Установить сейчас
SelfBtnNotes=Что нового?
SelfChkStart=Проверять обновления программы при запуске
SelfAsk=Доступна новая версия Eden Updater.\n\nУстановлена: {0}\nНовая: {1}\n\nОбновить сейчас? Программа затем перезапустится.
SelfDownloading=Загрузка программы обновления {0}...
SelfUpdated=Программа обновления обновлена до версии {0}.
NavGames=Игры
GamesSearch=Поиск игр...
GamesStart=Запустить игру
GamesFull=Запускать в полноэкранном режиме
GamesInfo=Игр: {0}, папок: {1}
GamesEmpty=Игры не найдены. Добавьте папку с играми в Eden (Файл → Добавить папку с играми), затем нажмите здесь «Обновить список».
GamesNoEden=Eden ещё не установлен.
GamesScanning=Поиск игр...
LogGameStart=Запуск {0}...
ThBaseDark=Тёмная
ThBaseBlack=Чёрная
ThBaseLight=Светлая
ThColCyan=Бирюзовый
ThColBlue=Синий
ThColIndigo=Индиго
ThColViolet=Фиолетовый
ThColPink=Розовый
ThColRed=Красный
ThColOrange=Оранжевый
ThColGold=Золотой
ThColGreen=Зелёный
ThColGrey=Серый
ThColSand=Песочный
ThCustom=Своя тема
ThTabPresets=Шаблоны
ThTabCustom=Своя
ThSlotBg=Фон
ThSlotPanel=Поверхности
ThSlotText=Текст
ThSlotAccent=Акцент
ThCustomHint=Выберите цвет слева и настройте его справа. Предпросмотр виден сразу.
ThContrast=Читаемость {0} : 1
ThContrastOk=хорошая
ThContrastLow=слишком низкая, текст будет настроен автоматически
GamesClose=Закрывать программу при запуске игры
NavMods=Моды
ModsInfo=Модов: {0}, игр: {1}
ModsScanning=Поиск модов...
ModsInstalling=Установка мода...
ModsFolder=Открыть папку модов
ModsAdd=Добавить мод...
ModsDelete=Удалить
ModsSelectGame=Выберите игру слева.
ModsGameInfo=Модов: {0} · активно: {1}
ModsNoMods=нет модов
ModsEmptyGame=Для этой игры моды не установлены. Нажмите «Добавить мод...», чтобы добавить ZIP, или скопируйте папки модов в папку модов.
ModsUnknownGame=Неизвестная игра
ModsEdenRunning=Eden запущен. Закройте Eden, чтобы изменить моды, иначе Eden перезапишет изменения при выходе.
ModsAskDelete=Удалить мод «{0}»?\n\nПапка будет перемещена в корзину.
ModsDeleted=Мод удалён: {0}
ModsAdded=Мод добавлен: {0}
ModsToggledOn=Мод включён: {0}
ModsToggledOff=Мод отключён: {0}
'@
ja = @'
Name=日本語
Culture=ja-JP
AppSubtitle=最新のNightlyビルドに更新、または旧バージョンをインストール
NavVersions=バージョン
NavNotes=パッチノート
NavSettings=設定
CardInstalled=インストール済み
CardLatest=最新
BtnUpdate=最新版に更新
BtnUpToDate=最新です
BtnLaunch=Edenを起動
BtnInstallSel=このバージョンをインストール
BtnReinstall=再インストール
BtnMore=さらに読み込む
BtnReload=再読み込み
BtnRestore=バックアップを復元
BtnRestoreTo={0} に戻す
ListInfo={0} 件のバージョンを読み込みました
NotInstalled=未インストール
NotesHeader=パッチノート
NotesHintPage=「バージョン」ページで選択したバージョンの内容です。
NotesHintSide=選択したバージョンの内容です。
NotesWeb=ブラウザで開く
NotesSelect=バージョン一覧からバージョンを選択してください。
NotesLoading=パッチノートを読み込み中...
NotesError=パッチノートを読み込めませんでした:
NotesNone=このバージョンにはパッチノートがありません。
SetPath=インストール先フォルダー
SetBrowse=参照...
SetBrowseTitle=Edenのインストール先フォルダーを選択
SetVariant=ビルドの種類
SetVariantHint=読み込んだリリースから一覧を作成します (Windows対応ビルドのみ)。
VarRecommended=推奨: PGO (Windows, amd64)
VarCount={0}   ({1} リリース)
VarCustom=カスタムフィルター (正規表現)...
SetPattern=カスタムフィルター (ダウンロードリンクに対する正規表現)
SetPages=読み込むリリース (ページ数、1〜10)
SetNotes=パッチノートの表示
NotesOptPage=専用ページ (上部の「パッチノート」ボタン)
NotesOptSide=バージョン一覧の横
SetTheme=配色
SetThemePick=テーマを選択...
SetLanguage=言語
LangAuto=自動 ({0})
SetLanguageHint=自動ではWindowsの言語を使用します。対応していない場合はドイツ語になります。
ChkBackup=更新前に旧バージョンのバックアップを作成する
ChkStart=更新/インストール後にEdenを自動で起動する
ChkClose=Eden起動後にアップデーターを自動で閉じる
ChkAuto=起動時に更新を確認する
ChkAutoInstall=見つかった更新を自動でインストールする (起動時のみ)
Save=保存
Cancel=キャンセル
Apply=適用
Yes=はい
No=いいえ
OK=OK
DlgWarning=注意
DlgError=エラー
DlgQuestion=確認
DlgInfo=情報
ThemeTag=テーマ
ThemeTitle=テーマを選択
ThemeHint=クリックするとすぐにプレビューされます。
StReady=準備完了
StSearching=リリースを検索中...
StLoadError=読み込みエラー
StError=エラー
LogInstall=>> {0} をインストール中
LogRestore=>> バックアップを復元中
LogEdenStarted=Edenを起動しました。
LogThemeSaved=テーマを保存しました: {0}
LogSettingsSaved=設定を保存しました。
LogCancelReq=キャンセルを要求しました...
LogAutoOff=自動確認はオフです。「{0}」をクリックしてください。
ErrPrefix=エラー:
ErrNoExe=eden.exe が見つかりません:
ErrNoPath=インストール先フォルダーが指定されていません。
ErrNoFilter=フィルターが指定されていません。
ErrPages=ページ数は1〜10の範囲で指定してください。
MsgBusyClose=処理はまだ実行中です。完了するまでお待ちください。
AskInstallBackup=バージョン {0} をインストールしますか?\n\n現在のインストールは置き換えられます (バックアップを作成します)。
AskInstallNoBackup=バージョン {0} をインストールしますか?\n\n現在のインストールは置き換えられます (バックアップなし)。
AskRestoreVer=バージョン {0} を復元しますか?\n\n現在インストールされているバージョンは置き換えられます。バックアップは保持されます。
AskRestore=バックアップを復元しますか?\n\n現在インストールされているバージョンは置き換えられます。バックアップは保持されます。
WLoadPage=リリース一覧を読み込み中 (ページ {0})...
WUnreachable=git.eden-emu.dev に接続できません (HTTP {0})。
WNoReleases=このビルドの種類に一致するリリースが見つかりません。
WFound={0} 件のバージョンが見つかりました。
WEdenRunning=Edenが実行中です。終了してから再試行してください。
WDownloading={0} をダウンロード中...
WDlProgress=ダウンロード   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=ダウンロード   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=キャンセルしました。
WDlFailed=ダウンロードに失敗しました (curl終了コード {0})。
WDlDone=ダウンロード完了 ({0:N1} MB、{1:N0} 秒)。
WBackupMaking=バックアップを作成中...
WBackupDone=バックアップを作成しました。
WRemoveOld=旧バージョンを削除中...
WRemovedOld=古いファイルを削除しました。
WExtracting=展開中   {0} / {1} ファイル
WExtracted=展開しました。
WInstalledSt=完了: {0} をインストールしました
WInstalledLog=Eden {0} をインストールしました。
WBackupAt=バックアップの場所: {0}
WNoBackup=バックアップが見つかりません。
WBackupEmpty=バックアップが空です。
WRemoveCur=現在のバージョンを削除中...
WRemovedCur=現在のバージョンを削除しました。
WRestoring=復元中   {0} / {1}
WUnknownVer=不明 (バックアップ)
WRestoredSt=完了: {0} を復元しました
WRestoredLog=バックアップを復元しました: {0}
ChipUpdate=更新があります
GrpInstall=インストール
GrpLook=外観
GrpBehavior=動作
LogTitle=アクティビティ
SetStoredAt=設定はインストール先フォルダーに保存されます: {0}
FirstRunAsk=Edenのインストールが見つかりません。\n\nこのフォルダーにEdenをインストールしますか?\n{0}\n\n別のフォルダーを選ぶには「いいえ」を選択してください。
GrpUpdater=Eden Updater
SelfVersion=インストール済みバージョン: {0}
SelfStateIdle=まだ更新を確認していません。
SelfStateChecking=アップデーターの更新を確認中...
SelfStateLatest=アップデーターは最新です。
SelfStateFound=新しいバージョンがあります: {0}
SelfStateError=確認に失敗しました: {0}
SelfStateScript=自動更新はEXE版でのみ利用できます。
SelfBtnCheck=更新を確認
SelfBtnInstall=今すぐインストール
SelfBtnNotes=新機能
SelfChkStart=起動時にアップデーターの更新を確認する
SelfAsk=Eden Updaterの新しいバージョンがあります。\n\nインストール済み: {0}\n新しいバージョン: {1}\n\n今すぐ更新しますか?更新後にアップデーターが再起動します。
SelfDownloading=アップデーター {0} をダウンロード中...
SelfUpdated=アップデーターをバージョン {0} に更新しました。
NavGames=ゲーム
GamesSearch=ゲームを検索...
GamesStart=ゲームを起動
GamesFull=フルスクリーンで起動
GamesInfo={1} フォルダーから {0} 本のゲーム
GamesEmpty=ゲームが見つかりません。Edenでゲームフォルダーを追加し (ファイル → ゲームフォルダーを追加)、ここで「再読み込み」をクリックしてください。
GamesNoEden=Edenはまだインストールされていません。
GamesScanning=ゲームを検索中...
LogGameStart={0} を起動中...
ThBaseDark=ダーク
ThBaseBlack=ブラック
ThBaseLight=ライト
ThColCyan=シアン
ThColBlue=ブルー
ThColIndigo=インディゴ
ThColViolet=バイオレット
ThColPink=ピンク
ThColRed=レッド
ThColOrange=オレンジ
ThColGold=ゴールド
ThColGreen=グリーン
ThColGrey=グレー
ThColSand=サンド
ThCustom=カスタムテーマ
ThTabPresets=テンプレート
ThTabCustom=カスタム
ThSlotBg=背景
ThSlotPanel=パネル
ThSlotText=テキスト
ThSlotAccent=アクセント
ThCustomHint=左で色を選び、右で調整します。プレビューはすぐに反映されます。
ThContrast=読みやすさ {0} : 1
ThContrastOk=良好
ThContrastLow=低すぎます。テキストは自動調整されます
GamesClose=ゲーム起動時にアップデーターを閉じる
NavMods=Mod
ModsInfo={1} 本のゲームに {0} 個のMod
ModsScanning=Modを検索中...
ModsInstalling=Modをインストール中...
ModsFolder=Modフォルダーを開く
ModsAdd=Modを追加...
ModsDelete=削除
ModsSelectGame=左でゲームを選択してください。
ModsGameInfo=Mod {0} 個 · 有効 {1} 個
ModsNoMods=Modなし
ModsEmptyGame=このゲームにはModがインストールされていません。「Modを追加...」でZIPを追加するか、ModフォルダーにModフォルダーをコピーしてください。
ModsUnknownGame=不明なゲーム
ModsEdenRunning=Edenが実行中です。Modを変更するにはEdenを閉じてください。閉じないと終了時に変更が上書きされます。
ModsAskDelete=Mod「{0}」を削除しますか?\n\nフォルダーはごみ箱に移動されます。
ModsDeleted=Modを削除しました: {0}
ModsAdded=Modを追加しました: {0}
ModsToggledOn=Modを有効にしました: {0}
ModsToggledOff=Modを無効にしました: {0}
'@
zh = @'
Name=中文（简体）
Culture=zh-CN
AppSubtitle=更新到最新 Nightly 版本或安装旧版本
NavVersions=版本
NavNotes=更新说明
NavSettings=设置
CardInstalled=已安装
CardLatest=最新
BtnUpdate=更新到最新版
BtnUpToDate=已是最新
BtnLaunch=启动 Eden
BtnInstallSel=安装此版本
BtnReinstall=重新安装
BtnMore=加载更多
BtnReload=重新加载
BtnRestore=恢复备份
BtnRestoreTo=回退到 {0}
ListInfo=已加载 {0} 个版本
NotInstalled=未安装
NotesHeader=更新说明
NotesHintPage=针对「版本」页面中选中的版本。
NotesHintSide=针对选中的版本。
NotesWeb=在浏览器中打开
NotesSelect=请在版本列表中选择一个版本。
NotesLoading=正在加载更新说明...
NotesError=无法加载更新说明:
NotesNone=此版本没有更新说明。
SetPath=安装文件夹
SetBrowse=浏览...
SetBrowseTitle=选择 Eden 安装文件夹
SetVariant=构建类型
SetVariantHint=列表根据已加载的版本生成 (仅限兼容 Windows 的构建)。
VarRecommended=推荐: PGO (Windows, amd64)
VarCount={0}   ({1} 个版本)
VarCustom=自定义筛选 (正则表达式)...
SetPattern=自定义筛选 (对下载链接使用正则表达式)
SetPages=要加载的版本 (页数, 1 到 10)
SetNotes=更新说明显示方式
NotesOptPage=单独页面 (顶部的「更新说明」按钮)
NotesOptSide=显示在版本列表旁边
SetTheme=配色方案
SetThemePick=选择主题...
SetLanguage=语言
LangAuto=自动 ({0})
SetLanguageHint=自动模式使用 Windows 的语言。若不受支持, 则使用德语。
ChkBackup=更新前备份旧版本
ChkStart=更新/安装后自动启动 Eden
ChkClose=启动 Eden 后自动关闭更新程序
ChkAuto=程序启动时检查更新
ChkAutoInstall=自动安装找到的更新 (仅在程序启动时)
Save=保存
Cancel=取消
Apply=应用
Yes=是
No=否
OK=确定
DlgWarning=提示
DlgError=错误
DlgQuestion=确认
DlgInfo=信息
ThemeTag=主题
ThemeTitle=选择主题
ThemeHint=点击即可立即预览主题。
StReady=就绪
StSearching=正在搜索版本...
StLoadError=加载出错
StError=错误
LogInstall=>> 正在安装 {0}
LogRestore=>> 正在恢复备份
LogEdenStarted=Eden 已启动。
LogThemeSaved=主题已保存: {0}
LogSettingsSaved=设置已保存。
LogCancelReq=已请求取消...
LogAutoOff=自动检查已关闭。请点击「{0}」。
ErrPrefix=错误:
ErrNoExe=未找到 eden.exe:
ErrNoPath=缺少安装文件夹。
ErrNoFilter=缺少筛选条件。
ErrPages=页数必须在 1 到 10 之间。
MsgBusyClose=操作仍在进行中。请等待其完成。
AskInstallBackup=安装版本 {0}?\n\n当前安装将被替换 (将创建备份)。
AskInstallNoBackup=安装版本 {0}?\n\n当前安装将被替换 (不创建备份)。
AskRestoreVer=恢复版本 {0}?\n\n当前安装的版本将被替换。备份会保留。
AskRestore=恢复备份?\n\n当前安装的版本将被替换。备份会保留。
WLoadPage=正在加载版本列表 (第 {0} 页)...
WUnreachable=无法访问 git.eden-emu.dev (HTTP {0})。
WNoReleases=未找到与此构建类型匹配的版本。
WFound=找到 {0} 个版本。
WEdenRunning=Eden 仍在运行。请先关闭它再重试。
WDownloading=正在下载 {0}...
WDlProgress=下载   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=下载   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=已取消。
WDlFailed=下载失败 (curl 退出码 {0})。
WDlDone=下载完成 ({0:N1} MB, 用时 {1:N0} 秒)。
WBackupMaking=正在创建备份...
WBackupDone=备份已创建。
WRemoveOld=正在删除旧版本...
WRemovedOld=旧文件已删除。
WExtracting=正在解压   {0} / {1} 个文件
WExtracted=解压完成。
WInstalledSt=完成: 已安装 {0}
WInstalledLog=Eden {0} 已安装。
WBackupAt=备份位置: {0}
WNoBackup=未找到备份。
WBackupEmpty=备份为空。
WRemoveCur=正在删除当前版本...
WRemovedCur=当前版本已删除。
WRestoring=正在恢复   {0} / {1}
WUnknownVer=未知 (备份)
WRestoredSt=完成: 已恢复 {0}
WRestoredLog=备份已恢复: {0}
ChipUpdate=有可用更新
GrpInstall=安装
GrpLook=外观
GrpBehavior=行为
LogTitle=活动
SetStoredAt=设置保存在安装文件夹中: {0}
FirstRunAsk=尚未找到 Eden 安装。\n\n要将 Eden 安装到此文件夹吗?\n{0}\n\n选择「否」可选择其他文件夹。
GrpUpdater=Eden Updater
SelfVersion=已安装版本: {0}
SelfStateIdle=尚未检查更新。
SelfStateChecking=正在检查更新程序的更新...
SelfStateLatest=更新程序已是最新版本。
SelfStateFound=有新版本可用: {0}
SelfStateError=检查失败: {0}
SelfStateScript=自动更新仅在 EXE 版本中可用。
SelfBtnCheck=检查更新
SelfBtnInstall=立即安装
SelfBtnNotes=更新内容
SelfChkStart=启动时检查更新程序的更新
SelfAsk=Eden Updater 有新版本可用。\n\n已安装: {0}\n新版本: {1}\n\n立即更新?更新程序随后会重新启动。
SelfDownloading=正在下载更新程序 {0}...
SelfUpdated=更新程序已更新到版本 {0}。
NavGames=游戏
GamesSearch=搜索游戏...
GamesStart=启动游戏
GamesFull=以全屏启动
GamesInfo=来自 {1} 个文件夹的 {0} 个游戏
GamesEmpty=未找到游戏。请在 Eden 中添加游戏文件夹 (文件 → 添加游戏目录), 然后在此点击「重新加载」。
GamesNoEden=尚未安装 Eden。
GamesScanning=正在搜索游戏...
LogGameStart=正在启动 {0}...
ThBaseDark=深色
ThBaseBlack=黑色
ThBaseLight=浅色
ThColCyan=青色
ThColBlue=蓝色
ThColIndigo=靛蓝
ThColViolet=紫色
ThColPink=粉色
ThColRed=红色
ThColOrange=橙色
ThColGold=金色
ThColGreen=绿色
ThColGrey=灰色
ThColSand=沙色
ThCustom=自定义主题
ThTabPresets=模板
ThTabCustom=自定义
ThSlotBg=背景
ThSlotPanel=面板
ThSlotText=文字
ThSlotAccent=强调色
ThCustomHint=在左侧选择颜色, 在右侧调整。预览会立即更新。
ThContrast=可读性 {0} : 1
ThContrastOk=良好
ThContrastLow=过低, 文字将自动调整
GamesClose=启动游戏时关闭更新程序
NavMods=模组
ModsInfo={1} 个游戏的 {0} 个模组
ModsScanning=正在搜索模组...
ModsInstalling=正在安装模组...
ModsFolder=打开模组文件夹
ModsAdd=添加模组...
ModsDelete=删除
ModsSelectGame=请在左侧选择一个游戏。
ModsGameInfo={0} 个模组 · {1} 个已启用
ModsNoMods=无模组
ModsEmptyGame=此游戏没有安装模组。点击「添加模组...」添加 ZIP, 或将模组文件夹复制到模组文件夹。
ModsUnknownGame=未知游戏
ModsEdenRunning=Eden 正在运行。请先关闭 Eden 再更改模组, 否则 Eden 退出时会覆盖更改。
ModsAskDelete=确定删除模组「{0}」?\n\n文件夹将移至回收站。
ModsDeleted=已删除模组: {0}
ModsAdded=已添加模组: {0}
ModsToggledOn=已启用模组: {0}
ModsToggledOff=已禁用模组: {0}
'@
ko = @'
Name=한국어
Culture=ko-KR
AppSubtitle=최신 Nightly 빌드로 업데이트하거나 이전 버전을 설치합니다
NavVersions=버전
NavNotes=패치 노트
NavSettings=설정
CardInstalled=설치됨
CardLatest=최신
BtnUpdate=최신 버전으로 업데이트
BtnUpToDate=최신 상태
BtnLaunch=Eden 실행
BtnInstallSel=이 버전 설치
BtnReinstall=다시 설치
BtnMore=더 불러오기
BtnReload=새로 고침
BtnRestore=백업 복원
BtnRestoreTo={0}(으)로 되돌리기
ListInfo=버전 {0}개 불러옴
NotInstalled=설치되지 않음
NotesHeader=패치 노트
NotesHintPage='버전' 페이지에서 선택한 버전의 내용입니다.
NotesHintSide=선택한 버전의 내용입니다.
NotesWeb=브라우저에서 열기
NotesSelect=버전 목록에서 버전을 선택하세요.
NotesLoading=패치 노트를 불러오는 중...
NotesError=패치 노트를 불러올 수 없습니다:
NotesNone=이 버전에는 패치 노트가 없습니다.
SetPath=설치 폴더
SetBrowse=찾아보기...
SetBrowseTitle=Eden 설치 폴더 선택
SetVariant=빌드 종류
SetVariantHint=불러온 릴리스에서 목록을 만듭니다 (Windows 호환 빌드만).
VarRecommended=권장: PGO (Windows, amd64)
VarCount={0}   (릴리스 {1}개)
VarCustom=사용자 지정 필터 (정규식)...
SetPattern=사용자 지정 필터 (다운로드 링크에 대한 정규식)
SetPages=불러올 릴리스 (페이지 수, 1~10)
SetNotes=패치 노트 표시 방식
NotesOptPage=별도 페이지 (상단의 '패치 노트' 버튼)
NotesOptSide=버전 목록 옆
SetTheme=색 구성표
SetThemePick=테마 선택...
SetLanguage=언어
LangAuto=자동 ({0})
SetLanguageHint=자동은 Windows 언어를 사용합니다. 지원되지 않으면 독일어를 사용합니다.
ChkBackup=업데이트 전에 이전 버전 백업 만들기
ChkStart=업데이트/설치 후 Eden 자동 실행
ChkClose=Eden 실행 후 업데이터 자동 종료
ChkAuto=프로그램 시작 시 업데이트 확인
ChkAutoInstall=찾은 업데이트 자동 설치 (프로그램 시작 시에만)
Save=저장
Cancel=취소
Apply=적용
Yes=예
No=아니요
OK=확인
DlgWarning=알림
DlgError=오류
DlgQuestion=확인
DlgInfo=정보
ThemeTag=테마
ThemeTitle=테마 선택
ThemeHint=클릭하면 바로 테마를 미리 볼 수 있습니다.
StReady=준비됨
StSearching=릴리스 검색 중...
StLoadError=불러오기 오류
StError=오류
LogInstall=>> {0} 설치 중
LogRestore=>> 백업 복원 중
LogEdenStarted=Eden을 실행했습니다.
LogThemeSaved=테마 저장됨: {0}
LogSettingsSaved=설정이 저장되었습니다.
LogCancelReq=취소를 요청했습니다...
LogAutoOff=자동 확인이 꺼져 있습니다. '{0}'을(를) 클릭하세요.
ErrPrefix=오류:
ErrNoExe=eden.exe를 찾을 수 없습니다:
ErrNoPath=설치 폴더가 지정되지 않았습니다.
ErrNoFilter=필터가 지정되지 않았습니다.
ErrPages=페이지 수는 1에서 10 사이여야 합니다.
MsgBusyClose=작업이 아직 진행 중입니다. 완료될 때까지 기다려 주세요.
AskInstallBackup=버전 {0}을(를) 설치할까요?\n\n현재 설치가 교체됩니다 (백업이 생성됩니다).
AskInstallNoBackup=버전 {0}을(를) 설치할까요?\n\n현재 설치가 교체됩니다 (백업 없음).
AskRestoreVer=버전 {0}을(를) 복원할까요?\n\n현재 설치된 버전이 교체됩니다. 백업은 유지됩니다.
AskRestore=백업을 복원할까요?\n\n현재 설치된 버전이 교체됩니다. 백업은 유지됩니다.
WLoadPage=릴리스 목록 불러오는 중 (페이지 {0})...
WUnreachable=git.eden-emu.dev에 연결할 수 없습니다 (HTTP {0}).
WNoReleases=이 빌드 종류에 맞는 릴리스를 찾을 수 없습니다.
WFound=버전 {0}개를 찾았습니다.
WEdenRunning=Eden이 아직 실행 중입니다. 먼저 종료한 후 다시 시도하세요.
WDownloading={0} 다운로드 중...
WDlProgress=다운로드   {0:N1} / {1:N1} MB   ·   {2:N1} MB/s
WDlProgressNoSize=다운로드   {0:N1} MB   ·   {1:N1} MB/s
WCancelled=취소되었습니다.
WDlFailed=다운로드 실패 (curl 종료 코드 {0}).
WDlDone=다운로드 완료 ({0:N1} MB, {1:N0}초).
WBackupMaking=백업 만드는 중...
WBackupDone=백업을 만들었습니다.
WRemoveOld=이전 버전 제거 중...
WRemovedOld=이전 파일을 제거했습니다.
WExtracting=압축 해제 중   {0} / {1}개 파일
WExtracted=압축을 해제했습니다.
WInstalledSt=완료: {0} 설치됨
WInstalledLog=Eden {0}을(를) 설치했습니다.
WBackupAt=백업 위치: {0}
WNoBackup=백업을 찾을 수 없습니다.
WBackupEmpty=백업이 비어 있습니다.
WRemoveCur=현재 버전 제거 중...
WRemovedCur=현재 버전을 제거했습니다.
WRestoring=복원 중   {0} / {1}
WUnknownVer=알 수 없음 (백업)
WRestoredSt=완료: {0} 복원됨
WRestoredLog=백업을 복원했습니다: {0}
ChipUpdate=업데이트 있음
GrpInstall=설치
GrpLook=모양
GrpBehavior=동작
LogTitle=활동
SetStoredAt=설정은 설치 폴더에 저장됩니다: {0}
FirstRunAsk=아직 Eden 설치를 찾지 못했습니다.\n\n이 폴더에 Eden을 설치할까요?\n{0}\n\n다른 폴더를 선택하려면 '아니요'를 선택하세요.
GrpUpdater=Eden Updater
SelfVersion=설치된 버전: {0}
SelfStateIdle=아직 업데이트를 확인하지 않았습니다.
SelfStateChecking=업데이터 업데이트 확인 중...
SelfStateLatest=업데이터가 최신 상태입니다.
SelfStateFound=새 버전 사용 가능: {0}
SelfStateError=확인 실패: {0}
SelfStateScript=자동 업데이트는 EXE 버전에서만 사용할 수 있습니다.
SelfBtnCheck=업데이트 확인
SelfBtnInstall=지금 설치
SelfBtnNotes=새로운 기능
SelfChkStart=시작할 때 업데이터 업데이트 확인
SelfAsk=Eden Updater의 새 버전이 있습니다.\n\n설치됨: {0}\n새 버전: {1}\n\n지금 업데이트할까요? 업데이터가 다시 시작됩니다.
SelfDownloading=업데이터 {0} 다운로드 중...
SelfUpdated=업데이터를 버전 {0}(으)로 업데이트했습니다.
NavGames=게임
GamesSearch=게임 검색...
GamesStart=게임 시작
GamesFull=전체 화면으로 시작
GamesInfo=폴더 {1}개에서 게임 {0}개
GamesEmpty=게임을 찾지 못했습니다. Eden에서 게임 폴더를 추가한 뒤 (파일 → 게임 폴더 추가) 여기서 '새로 고침'을 클릭하세요.
GamesNoEden=Eden이 아직 설치되지 않았습니다.
GamesScanning=게임 검색 중...
LogGameStart={0} 시작 중...
ThBaseDark=다크
ThBaseBlack=블랙
ThBaseLight=라이트
ThColCyan=시안
ThColBlue=블루
ThColIndigo=인디고
ThColViolet=바이올렛
ThColPink=핑크
ThColRed=레드
ThColOrange=오렌지
ThColGold=골드
ThColGreen=그린
ThColGrey=그레이
ThColSand=샌드
ThCustom=사용자 테마
ThTabPresets=템플릿
ThTabCustom=사용자 지정
ThSlotBg=배경
ThSlotPanel=패널
ThSlotText=텍스트
ThSlotAccent=강조색
ThCustomHint=왼쪽에서 색을 선택하고 오른쪽에서 조정하세요. 미리 보기가 바로 반영됩니다.
ThContrast=가독성 {0} : 1
ThContrastOk=좋음
ThContrastLow=너무 낮음, 텍스트가 자동으로 조정됩니다
GamesClose=게임 시작 시 업데이터 닫기
NavMods=모드
ModsInfo=게임 {1}개에 모드 {0}개
ModsScanning=모드 검색 중...
ModsInstalling=모드 설치 중...
ModsFolder=모드 폴더 열기
ModsAdd=모드 추가...
ModsDelete=삭제
ModsSelectGame=왼쪽에서 게임을 선택하세요.
ModsGameInfo=모드 {0}개 · 활성 {1}개
ModsNoMods=모드 없음
ModsEmptyGame=이 게임에 설치된 모드가 없습니다. '모드 추가...'로 ZIP을 추가하거나 모드 폴더에 모드 폴더를 복사하세요.
ModsUnknownGame=알 수 없는 게임
ModsEdenRunning=Eden이 실행 중입니다. 모드를 변경하려면 Eden을 닫으세요. 그렇지 않으면 종료 시 변경 사항을 덮어씁니다.
ModsAskDelete='{0}' 모드를 삭제할까요?\n\n폴더는 휴지통으로 이동됩니다.
ModsDeleted=모드 삭제됨: {0}
ModsAdded=모드 추가됨: {0}
ModsToggledOn=모드 활성화됨: {0}
ModsToggledOff=모드 비활성화됨: {0}
'@
}

function ConvertFrom-LangText([string]$txt) {
    $h = @{}
    foreach ($line in ($txt -split "\r?\n")) {
        $i = $line.IndexOf('=')
        if ($i -lt 1 -or $line.StartsWith('#')) { continue }
        $h[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).TrimEnd().Replace('\n', "`n")
    }
    return $h
}

$script:LangTables = @{}
foreach ($c in $LangOrder) { $script:LangTables[$c] = ConvertFrom-LangText $LangData[$c] }
$script:L           = @{}
$script:LangCode    = "de"
$script:LangCulture = "de-DE"
$script:CI          = [Globalization.CultureInfo]::CurrentCulture

# Windows-Sprache, falls unterstuetzt, sonst Deutsch
function Get-SystemLang {
    $two = ""
    try { $two = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName } catch {}
    if ($LangOrder -contains $two) { return $two }
    return "de"
}

function Resolve-Lang([string]$code) {
    if ($code -and $code -ne "auto" -and ($LangOrder -contains $code)) { return $code }
    return (Get-SystemLang)
}

function Initialize-Language {
    $code = Resolve-Lang ([string]$script:Settings.Language)
    $L = @{}
    foreach ($src in @("de", "en", $code)) {
        $t = $script:LangTables[$src]
        foreach ($k in $t.Keys) { $L[$k] = $t[$k] }
    }
    # Zahlen/Datum: Windows-Region nutzen, wenn sie zur Sprache passt (z.B. de-AT)
    $cul = [string]$script:LangTables[$code].Culture
    try {
        $cur = [Globalization.CultureInfo]::CurrentCulture
        if ($cur.Name -and $cur.TwoLetterISOLanguageName -eq $code) { $cul = $cur.Name }
    } catch {}
    $script:L           = $L
    $script:LangCode    = $code
    $script:LangCulture = $cul
    try { $script:CI = [Globalization.CultureInfo]::GetCultureInfo($cul) } catch { $script:CI = [Globalization.CultureInfo]::CurrentCulture }
}

function T([string]$k) {
    $v = $script:L[$k]
    if ($null -ne $v) { return [string]$v }
    return $k
}

function TF([string]$k) {
    return [string]::Format($script:CI, (T $k), [object[]]$args)
}

# Texte als Ressourcen ins Fenster (XAML nutzt {DynamicResource L_...})
function Set-LangResources($win) {
    if (-not $win) { return }
    foreach ($k in $script:L.Keys) { $win.Resources["L_$k"] = [string]$script:L[$k] }
    try { $win.Language = [System.Windows.Markup.XmlLanguage]::GetLanguage($script:LangCulture) } catch {}
}

Initialize-Language

# Gemeinsamer Zustand zwischen UI und Hintergrund-Thread
$sync = [hashtable]::Synchronized(@{
    Log      = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]')
    Progress = -1
    Status   = ""
    Done     = $false
    Cancel   = $false
    Result   = $null
    Args     = $null
})
$selfSync = [hashtable]::Synchronized(@{
    Done   = $false
    Result = $null
    Args   = $null
})
$gameSync = [hashtable]::Synchronized(@{
    Done   = $false
    Result = $null
    Args   = $null
})
$modSync = [hashtable]::Synchronized(@{
    Done   = $false
    Result = $null
    Args   = $null
})
$notesSync = [hashtable]::Synchronized(@{
    Log    = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]')
    Done   = $false
    Result = $null
    Args   = $null
})

# Spiele: Spieleordner aus Edens qt-config.ini lesen und nach Spieldateien durchsuchen
$jobGames = {
    $a = $sync.Args
    try {
        $eden = [string]$a.EdenPath
        # Eden nutzt den Ordner "user" im Arbeitsverzeichnis (portabel), sonst %APPDATA%\eden
        $cfgs = @(
            (Join-Path $eden "user\config\qt-config.ini"),
            $(if ($env:APPDATA) { Join-Path $env:APPDATA "eden\config\qt-config.ini" })
        )
        $cfg = $cfgs | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
        $dirs = New-Object System.Collections.ArrayList
        if ($cfg) {
            $txt = [IO.File]::ReadAllText($cfg)
            $paths = @{}; $deep = @{}
            foreach ($m in [regex]::Matches($txt, '(?m)gamedirs\\(\d+)\\path=(.*)$'))      { $paths[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() }
            foreach ($m in [regex]::Matches($txt, '(?m)gamedirs\\(\d+)\\deep_scan=(.*)$')) { $deep[$m.Groups[1].Value]  = ($m.Groups[2].Value.Trim() -eq "true") }
            foreach ($k in $paths.Keys) {
                $pth = $paths[$k].Trim('"')
                if (-not $pth -or $pth -in @("SDMC", "UserNAND", "SysNAND")) { continue }
                $pth = $pth.Replace('/', '\')
                if (Test-Path -LiteralPath $pth) { [void]$dirs.Add(@{ Path = $pth; Deep = [bool]$deep[$k] }) }
            }
        }
        # Eden legt Icon + Spielname beim Aufbau seiner Spieleliste ab:
        #   <Daten>\cache\game_list\<TitleID>.jpeg  und  <TitleID>.appname.txt
        function Get-Norm([string]$x) { return [regex]::Replace($x.ToLowerInvariant(), '[^\p{L}\p{N}]', '') }
        $dataDir = if (Test-Path -LiteralPath (Join-Path $eden "user")) { Join-Path $eden "user" }
                   elseif ($env:APPDATA) { Join-Path $env:APPDATA "eden" } else { $null }
        $meta = @{}
        if ($dataDir) {
            $gl = Join-Path $dataDir "cache\game_list"
            if (Test-Path -LiteralPath $gl) {
                foreach ($t in Get-ChildItem -LiteralPath $gl -Filter "*.appname.txt" -File -ErrorAction SilentlyContinue) {
                    $id = $t.Name.Substring(0, $t.Name.IndexOf('.')).ToUpperInvariant()
                    $nm = ""
                    try { $nm = ([IO.File]::ReadAllText($t.FullName, [Text.Encoding]::UTF8)).Trim([char]0, ' ', "`r", "`n") } catch {}
                    $jp = Join-Path $gl ($id + ".jpeg")
                    $meta[$id] = @{ Name = $nm; Norm = (Get-Norm $nm); Icon = $(if (Test-Path -LiteralPath $jp) { $jp } else { "" }) }
                }
            }
        }

        # Title-ID aus dem (unverschluesselten) Inhaltsverzeichnis einer NSP lesen:
        # PFS0-Container, die Ticket-Datei heisst <TitleID><Schluesselgeneration>.tik
        function Get-NspTid([string]$path) {
            $fs = $null
            try {
                $fs = [IO.File]::OpenRead($path)
                $br = New-Object IO.BinaryReader($fs)
                if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne "PFS0") { return $null }
                $n = $br.ReadUInt32(); $strSize = $br.ReadUInt32(); [void]$br.ReadUInt32()
                if ($n -gt 4096 -or $strSize -gt 1048576) { return $null }
                [void]$br.ReadBytes([int](24 * $n))
                $tbl = [Text.Encoding]::ASCII.GetString($br.ReadBytes([int]$strSize))
                foreach ($nm in $tbl.Split([char]0)) {
                    if ($nm -match '^(01[0-9a-fA-F]{14})[0-9a-fA-F]{16}\.(tik|cert)$') { return $Matches[1].ToUpperInvariant() }
                }
            } catch {} finally { if ($fs) { $fs.Close() } }
            return $null
        }

        $games = New-Object System.Collections.ArrayList
        $seen  = @{}
        foreach ($d in $dirs) {
            $files = if ($d.Deep) { Get-ChildItem -LiteralPath $d.Path -File -Recurse -ErrorAction SilentlyContinue }
                     else         { Get-ChildItem -LiteralPath $d.Path -File -ErrorAction SilentlyContinue }
            foreach ($f in $files) {
                if ($f.Extension -notmatch '^\.(nsp|xci|nro)$') { continue }
                if ($seen.ContainsKey($f.FullName)) { continue }
                $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
                # Updates/DLCs ueberspringen (Title-ID endet nicht auf 000)
                $tidM = [regex]::Match($base, '(?i)\b(01[0-9a-f]{14})\b')
                $tidS = if ($tidM.Success) { $tidM.Value.ToUpperInvariant() } elseif ($f.Extension -eq ".nsp") { Get-NspTid $f.FullName } else { $null }
                if ($tidS -and -not $tidS.EndsWith("000")) { continue }
                if ($base -match '(?i)\[(upd|update|dlc)\]') { continue }
                $name = [regex]::Replace($base, '\[[^\]]*\]', '')
                $name = [regex]::Replace($name, '_', ' ')
                $name = [regex]::Replace($name, '\s{2,}', ' ').Trim(' ', '-', '.')
                if (-not $name) { $name = $base }
                # Passenden Cache-Eintrag suchen: zuerst ueber die Title-ID im Dateinamen, sonst ueber den Namen
                $hit = $null
                if ($tidS -and $meta.ContainsKey($tidS)) { $hit = $meta[$tidS] }
                if (-not $hit) {
                    $n = Get-Norm $name
                    if ($n.Length -ge 4) {
                        foreach ($c in $meta.Values) {
                            if ($c.Norm.Length -ge 4 -and ($c.Norm -eq $n -or $c.Norm.Contains($n) -or $n.Contains($c.Norm))) { $hit = $c; break }
                        }
                    }
                }
                $icon = ""
                if ($hit) { if ($hit.Name) { $name = $hit.Name }; $icon = $hit.Icon }
                $seen[$f.FullName] = $true
                [void]$games.Add([pscustomobject]@{
                    Name    = $name
                    Path    = $f.FullName
                    Info    = ($f.Extension.TrimStart('.').ToUpper() + "  ·  " + $(if ($f.Length -ge 1GB) { "{0:N1} GB" -f ($f.Length / 1GB) } else { "{0:N0} MB" -f [Math]::Max(1, $f.Length / 1MB) }))
                    Initial = $name.Substring(0, 1).ToUpper()
                    Icon    = $icon
                    Tid     = [string]$tidS
                })
            }
        }
        $sorted = @($games | Sort-Object Name)
        $names = @{}
        foreach ($k in $meta.Keys) { if ($meta[$k].Name) { $names[$k] = $meta[$k].Name } }
        $sync.Result = @{ Ok = $true; Games = $sorted; Dirs = $dirs.Count; Config = [string]$cfg; CacheNames = $names }
    } catch {
        $sync.Result = @{ Ok = $false; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# Mods: <Eden-Daten>\load\<TitleID>\<Modname>\  (scan = auflisten, add = ZIP entpacken)
$jobMods = {
    $a = $sync.Args
    try {
        $load = [string]$a.LoadDir
        if ($a.Mode -eq "add") {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $known  = @("exefs", "romfs", "cheats", "romfslite", "exefs_patches")
            $target = Join-Path $load $a.Tid
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            $tmp = Join-Path $target (".eu-tmp-" + [guid]::NewGuid().ToString("N"))
            [IO.Compression.ZipFile]::ExtractToDirectory([string]$a.Zip, $tmp)
            try {
                $top     = @(Get-ChildItem -LiteralPath $tmp -Force)
                $topDirs = @($top | Where-Object { $_.PSIsContainer })
                $hasKnown = { param($dir) @(Get-ChildItem -LiteralPath $dir -Directory -Force | Where-Object { $known -contains $_.Name.ToLowerInvariant() }).Count -gt 0 }
                $sources = @()
                if (& $hasKnown $tmp) {
                    # exefs/romfs liegen direkt im ZIP -> Mod heisst wie das ZIP
                    $sources = @(@{ Src = $tmp; Name = [IO.Path]::GetFileNameWithoutExtension([string]$a.Zip); Whole = $true })
                } elseif ($topDirs.Count -eq 1 -and $top.Count -eq 1 -and $topDirs[0].Name -match '^[0-9a-fA-F]{16}$') {
                    # ZIP enthaelt <TitleID>\<Mod>\... -> jede Mod einzeln
                    foreach ($m in Get-ChildItem -LiteralPath $topDirs[0].FullName -Directory) { $sources += @{ Src = $m.FullName; Name = $m.Name; Whole = $false } }
                } elseif ($topDirs.Count -ge 1 -and @($topDirs | Where-Object { & $hasKnown $_.FullName }).Count -eq $topDirs.Count) {
                    # ein oder mehrere Mod-Ordner
                    foreach ($m in $topDirs) { $sources += @{ Src = $m.FullName; Name = $m.Name; Whole = $false } }
                } else {
                    $sources = @(@{ Src = $tmp; Name = [IO.Path]::GetFileNameWithoutExtension([string]$a.Zip); Whole = $true })
                }
                $added = @()
                foreach ($src in $sources) {
                    $name = ($src.Name -replace '[\\/:*?"<>|]', '_').Trim()
                    if (-not $name) { $name = "Mod" }
                    $dest = Join-Path $target $name
                    $i = 2
                    while (Test-Path -LiteralPath $dest) { $dest = Join-Path $target ("{0} ({1})" -f $name, $i); $i++ }
                    if ($src.Whole) {
                        New-Item -ItemType Directory -Path $dest -Force | Out-Null
                        Get-ChildItem -LiteralPath $src.Src -Force | Move-Item -Destination $dest
                    } else {
                        Move-Item -LiteralPath $src.Src -Destination $dest
                    }
                    $added += (Split-Path -Leaf $dest)
                }
                $sync.Result = @{ Ok = $true; Mode = "add"; Added = $added }
            } finally {
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
            return
        }
        $mods = New-Object System.Collections.ArrayList
        if ($load -and (Test-Path -LiteralPath $load)) {
            foreach ($td in Get-ChildItem -LiteralPath $load -Directory -ErrorAction SilentlyContinue) {
                if ($td.Name -notmatch '^[0-9a-fA-F]{16}$') { continue }
                foreach ($md in Get-ChildItem -LiteralPath $td.FullName -Directory -ErrorAction SilentlyContinue) {
                    if ($md.Name.StartsWith(".eu-tmp-")) { continue }
                    $size = 0L
                    foreach ($f in Get-ChildItem -LiteralPath $md.FullName -File -Recurse -Force -ErrorAction SilentlyContinue) { $size += $f.Length }
                    $parts = @(Get-ChildItem -LiteralPath $md.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.ToLowerInvariant() } |
                               Where-Object { $_ -in @("exefs", "romfs", "cheats", "romfslite", "exefs_patches") })
                    [void]$mods.Add(@{ Tid = $td.Name.ToUpperInvariant(); Name = $md.Name; Path = $md.FullName; Size = $size; Parts = ($parts -join ", ") })
                }
            }
        }
        $sync.Result = @{ Ok = $true; Mode = "scan"; Mods = @($mods) }
    } catch {
        $sync.Result = @{ Ok = $false; Mode = [string]$a.Mode; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# Selbst-Update: neueste Release-Info von GitHub holen bzw. die neue EXE laden
$jobSelf = {
    $a  = $sync.Args
    $UA = "EdenUpdater"
    try {
        if ($a.Mode -eq "check") {
            $tmp = [IO.Path]::GetTempFileName()
            try {
                $url  = "https://api.github.com/repos/" + $a.Repo + "/releases/latest"
                $code = & curl.exe -s -L --max-time 20 -A $UA -H "Accept: application/vnd.github+json" -o $tmp -w "%{http_code}" $url 2>$null
                if ("$code" -eq "404") { $sync.Result = @{ Ok = $true; Mode = "check"; Tag = "" }; return }
                if ("$code" -ne "200") { throw ("GitHub HTTP " + $code) }
                $j = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8) | ConvertFrom-Json
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
            $asset = @($j.assets) | Where-Object { $_.name -eq "EdenUpdater.exe" } | Select-Object -First 1
            $sync.Result = @{
                Ok   = $true; Mode = "check"
                Tag  = [string]$j.tag_name
                Page = [string]$j.html_url
                Url  = $(if ($asset) { [string]$asset.browser_download_url } else { "" })
                Size = $(if ($asset) { [long]$asset.size } else { [long]0 })
            }
        } else {
            $out = [string]$a.Target
            Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
            $code = & curl.exe -s -L --max-time 180 -A $UA -o $out -w "%{http_code}" $a.Url 2>$null
            if ("$code" -ne "200" -or -not (Test-Path -LiteralPath $out)) { throw ("Download HTTP " + $code) }
            $len = (Get-Item -LiteralPath $out).Length
            if ($a.Size -gt 0 -and $len -ne $a.Size) { throw ("Download unvollständig ($len / $($a.Size) Bytes)") }
            $fs = [IO.File]::OpenRead($out)
            try { $b1 = $fs.ReadByte(); $b2 = $fs.ReadByte() } finally { $fs.Close() }
            if ($b1 -ne 0x4D -or $b2 -ne 0x5A) { throw "Download ist keine gültige EXE." }
            $sync.Result = @{ Ok = $true; Mode = "download"; File = $out }
        }
    } catch {
        if ($a.Mode -ne "check") { Remove-Item -LiteralPath ([string]$a.Target) -Force -ErrorAction SilentlyContinue }
        $sync.Result = @{ Ok = $false; Mode = $a.Mode; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# ------------------------------------------------------------
#  Hintergrund-Code (laeuft in eigenem Runspace, fasst die UI nicht an)
# ------------------------------------------------------------
$workerLib = {
    $UA          = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    $BaseUrl     = "https://git.eden-emu.dev"
    $ReleasesUrl = "https://git.eden-emu.dev/eden-ci/nightly/releases"
    $DefaultPattern = "Windows.*amd64.*pgo"

    function Add-Log([string]$m) { $sync.Log.Enqueue($m) }

    # Uebersetzte Texte kommen aus dem UI-Thread ($sync.L / $sync.Culture)
    $CI = [Globalization.CultureInfo]::CurrentCulture
    try { if ($sync.Culture) { $CI = [Globalization.CultureInfo]::GetCultureInfo([string]$sync.Culture) } } catch {}
    function T([string]$k) {
        if ($sync.L) { $v = $sync.L[$k]; if ($null -ne $v) { return [string]$v } }
        return $k
    }
    function TF([string]$k) { return [string]::Format($CI, (T $k), [object[]]$args) }

    # curl.exe verwenden (umgeht Cloudflare-Block von PowerShell/.NET)
    function Get-Page([string]$url) {
        $tmp = [IO.Path]::GetTempFileName()
        try {
            $code = & curl.exe -s -L --max-time 20 -A $UA -o $tmp -w "%{http_code}" $url 2>$null
            $html = if (Test-Path $tmp) { [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8) } else { "" }
            [pscustomobject]@{ Code = "$code"; Html = $html }
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    # Variante = Dateiname ohne Tag/Datum/Hash, z.B. "Eden-Windows-amd64-clang-pgo"
    function Get-VariantKey([string]$fname, [string]$tag) {
        $n = [IO.Path]::GetFileNameWithoutExtension($fname)
        if ($tag) { $n = $n.Replace($tag, "") }
        $n = [regex]::Replace($n, '(?<![A-Za-z0-9])(v?\d{4}[-._]\d{2}[-._]\d{2}|\d{8})(?![A-Za-z0-9])', '')
        $n = [regex]::Replace($n, '(?<![A-Za-z0-9])(?=[0-9a-f]*\d)[0-9a-f]{7,40}(?![A-Za-z0-9])', '')
        $n = [regex]::Replace($n, '[-_.\s]{2,}', '-')
        return $n.Trim('-', '_', '.', ' ')
    }

    function Get-Releases([int]$pages, [string]$variant, [string]$pattern) {
        $items    = New-Object System.Collections.ArrayList
        $seen     = @{}
        $varSeen  = @{}
        $varCount = @{}
        for ($p = 1; $p -le $pages; $p++) {
            $url = if ($p -eq 1) { $ReleasesUrl } else { "$ReleasesUrl`?page=$p" }
            Add-Log (TF "WLoadPage" $p)
            $r = Get-Page $url
            if ($r.Code -ne "200") {
                if ($p -eq 1) { throw (TF "WUnreachable" $r.Code) } else { break }
            }
            $html       = $r.Html
            $tagMatches = [regex]::Matches($html, '/eden-ci/nightly/releases/tag/([^"''<>\s]+)')
            $zipMatches = [regex]::Matches($html, 'href="([^"]*\.zip)"')
            $added = 0
            foreach ($z in $zipMatches) {
                $href = [System.Net.WebUtility]::HtmlDecode($z.Groups[1].Value)

                # Tag aus dem Download-Link, sonst der naechste Tag-Link davor
                $tag = $null
                if ($href -match '/releases/download/([^/]+)/') {
                    $tag = [uri]::UnescapeDataString($Matches[1])
                } else {
                    foreach ($t in $tagMatches) {
                        if ($t.Index -lt $z.Index) { $tag = $t.Groups[1].Value.Trim() } else { break }
                    }
                }
                if (-not $tag) { continue }

                # Variante bestimmen und mitzaehlen (fuer das Dropdown)
                $fname = [uri]::UnescapeDataString((($href -split '\?')[0]).Split('/')[-1])
                $key   = Get-VariantKey $fname $tag
                if (-not $key) { $key = $fname }
                $vk = "$tag|$key"
                if (-not $varSeen.ContainsKey($vk)) {
                    $varSeen[$vk] = $true
                    $varCount[$key] = 1 + [int]$varCount[$key]
                }

                # Filter
                if ($variant -eq "__custom__") { $ok = ($href -match $pattern) }
                elseif ($variant)              { $ok = ($key -eq $variant) }
                else                           { $ok = ($href -match $DefaultPattern) }
                if (-not $ok -or $seen.ContainsKey($tag)) { continue }
                $seen[$tag] = $true
                $dl = if ($href -match '^https?://') { $href } else { "$BaseUrl$href" }

                # Datum (falls im HTML vorhanden)
                $date = ""
                for ($i = 0; $i -lt $tagMatches.Count; $i++) {
                    if ($tagMatches[$i].Groups[1].Value.Trim() -eq $tag) {
                        $start = $tagMatches[$i].Index
                        $end   = $html.Length
                        for ($j = $i + 1; $j -lt $tagMatches.Count; $j++) {
                            if ($tagMatches[$j].Groups[1].Value.Trim() -ne $tag) { $end = $tagMatches[$j].Index; break }
                        }
                        $seg = $html.Substring($start, $end - $start)
                        $dm  = [regex]::Match($seg, 'datetime="([^"]+)"')
                        if ($dm.Success) {
                            try { $date = ([datetime]::Parse($dm.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)).ToString("g", $CI) } catch {}
                        }
                        break
                    }
                }
                [void]$items.Add([pscustomobject]@{ Tag = $tag; Url = $dl; Date = $date })
                $added++
            }
            if ($added -eq 0) { break }
        }

        # Gefundene Varianten: nur Builds, die unter Windows laufen
        # (kein Linux/Android/macOS; ARM-Builds nur auf ARM-Rechnern)
        $isArmHost = ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
        $otherOs   = 'linux|android|macos|osx|darwin|freebsd|appimage|steamdeck|flatpak|apk'
        $vl = @(foreach ($k in $varCount.Keys) { [pscustomobject]@{ Key = $k; Count = $varCount[$k] } })
        $vl = @($vl | Where-Object {
            $_.Key -match '(?<![a-z])win(dows|64|32)?(?![a-z])' -and
            $_.Key -notmatch $otherOs -and
            ($isArmHost -or $_.Key -notmatch 'arm64|aarch64|armv')
        })
        $vl = @($vl | Sort-Object Key)
        [pscustomobject]@{ Items = $items.ToArray(); Variants = $vl }
    }

    # --- Patchnotes ---------------------------------------------------
    function Format-Notes([string]$text) {
        $out  = New-Object System.Collections.ArrayList
        $prevBlank = $true
        foreach ($raw in ($text -split "\r?\n")) {
            $l = $raw.TrimEnd()
            $l = [regex]::Replace($l, '<!--.*?-->', '')
            $l = [regex]::Replace($l, '<[^>]+>', '')
            $l = [regex]::Replace($l, '!?\[([^\]]*)\]\([^)]*\)', '$1')
            $isHead = $false
            if ($l -match '^\s{0,3}#{1,6}\s*(.+)$') { $l = $Matches[1].Trim().ToUpper(); $isHead = $true }
            $l = [regex]::Replace($l, '\*\*(.+?)\*\*', '$1')
            $l = [regex]::Replace($l, '__(.+?)__', '$1')
            $l = [regex]::Replace($l, '`([^`]*)`', '$1')
            $l = [regex]::Replace($l, '^(\s*)[-*+]\s+', '$1' + [string][char]0x2022 + ' ')
            if ($l.Trim() -eq "") {
                if (-not $prevBlank) { [void]$out.Add("") }
                $prevBlank = $true
                continue
            }
            if ($isHead -and -not $prevBlank) { [void]$out.Add("") }
            [void]$out.Add($l)
            $prevBlank = $false
        }
        $res = ($out -join "`r`n").Trim()
        if ($res.Length -gt 20000) { $res = $res.Substring(0, 20000) + "`r`n..." }
        return $res
    }

    function Convert-HtmlNotes([string]$html) {
        $m = [regex]::Match($html, '<div[^>]*class="[^"]*markup[^"]*"[^>]*>')
        if (-not $m.Success) { return $null }
        $pos   = $m.Index + $m.Length
        $depth = 1
        $end   = $html.Length
        foreach ($t in ([regex]'<(/?)div\b[^>]*>').Matches($html, $pos)) {
            if ($t.Groups[1].Value -eq '/') { $depth-- } else { $depth++ }
            if ($depth -eq 0) { $end = $t.Index; break }
        }
        $inner = $html.Substring($pos, $end - $pos)
        $inner = [regex]::Replace($inner, '(?i)<li[^>]*>', "`n- ")
        $inner = [regex]::Replace($inner, '(?i)<br\s*/?>|</p>|</h[1-6]>|</ul>|</ol>|</li>', "`n")
        $inner = [regex]::Replace($inner, '<[^>]+>', '')
        $inner = [System.Net.WebUtility]::HtmlDecode($inner)
        return (Format-Notes $inner)
    }

    # Dateigroesse fuer echten Prozentbalken (0 = unbekannt)
    function Get-RemoteSize([string]$url) {
        try {
            $h   = & curl.exe -s -I -L --max-time 20 -A $UA $url 2>$null
            $len = 0L
            foreach ($line in $h) {
                if ($line -match '^(?i)content-length:\s*(\d+)') { $len = [long]$Matches[1] }
            }
            return $len
        } catch { return 0L }
    }
}

$jobLoad = {
    $res = $null
    try {
        $a = $sync.Args
        $sync.Status   = (T "StSearching")
        $sync.Progress = -1
        $res = Get-Releases $a.Pages $a.Variant $a.Pattern
        $items = @($res.Items)
        if ($items.Count -eq 0) { throw (T "WNoReleases") }
        Add-Log (TF "WFound" $items.Count)
        $sync.Status = (T "StReady")
        $sync.Result = @{ Kind = "load"; Ok = $true; Items = $items; Variants = @($res.Variants) }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        $sync.Status = (T "StLoadError")
        $vars = if ($res) { @($res.Variants) } else { @() }
        $sync.Result = @{ Kind = "load"; Ok = $false; Error = $_.Exception.Message; Variants = $vars }
    } finally {
        $sync.Done = $true
    }
}

$jobInstall = {
    $removed = $false
    $cancelled = $false
    try {
        $a    = $sync.Args
        $tag  = $a.Tag
        $url  = $a.Url
        $eden = $a.EdenPath
        $zip  = Join-Path $env:TEMP "eden_nightly_update.zip"

        # Laeuft Eden noch aus diesem Ordner?
        $running = Get-Process -Name eden -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -and $_.Path.StartsWith($eden, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
        }
        if ($running) { throw (T "WEdenRunning") }

        # 1) Download
        $sync.Status   = (TF "WDownloading" $tag)
        $sync.Progress = -1
        $total = Get-RemoteSize $url
        if (Test-Path $zip) { Remove-Item $zip -Force }
        $argLine = "-L --fail --max-time 900 -A `"$UA`" -o `"$zip`" `"$url`""
        $proc = Start-Process -FilePath "curl.exe" -ArgumentList $argLine -WindowStyle Hidden -PassThru
        $null = $proc.Handle
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $lastB = 0L; $lastT = 0.0; $speed = 0.0
        while (-not $proc.HasExited) {
            if ($sync.Cancel) {
                try { $proc.Kill() } catch {}
                Start-Sleep -Milliseconds 300
                Remove-Item $zip -Force -ErrorAction SilentlyContinue
                $cancelled = $true
                throw (T "WCancelled")
            }
            $b = if (Test-Path $zip) { (Get-Item $zip).Length } else { 0L }
            $t = $sw.Elapsed.TotalSeconds
            if (($t - $lastT) -ge 0.5) {
                $speed = (($b - $lastB) / 1MB) / ($t - $lastT)
                $lastB = $b; $lastT = $t
            }
            if ($total -gt 0) {
                $sync.Progress = [math]::Min(100, [int](100 * $b / $total))
                $sync.Status   = (TF "WDlProgress" ($b / 1MB) ($total / 1MB) $speed)
            } else {
                $sync.Progress = -1
                $sync.Status   = (TF "WDlProgressNoSize" ($b / 1MB) $speed)
            }
            Start-Sleep -Milliseconds 200
        }
        if ($proc.ExitCode -ne 0) { throw (TF "WDlFailed" $proc.ExitCode) }
        $finalMB = (Get-Item $zip).Length / 1MB
        Add-Log (TF "WDlDone" $finalMB $sw.Elapsed.TotalSeconds)
        $sync.CanCancel = $false

        # 2) Backup der alten Version
        $sync.Progress = -1
        $excl = @($a.Excludes)
        if (-not (Test-Path $eden)) { New-Item -ItemType Directory -Path $eden | Out-Null }
        if ($a.Backup) {
            $sync.Status = (T "WBackupMaking")
            $bp = Join-Path $eden "Backup"
            if (Test-Path $bp) { Remove-Item -Path $bp -Recurse -Force }
            New-Item -ItemType Directory -Path $bp | Out-Null
            if ($a.InstalledVersion) { "$($a.InstalledVersion)" | Set-Content (Join-Path $bp "backup-version.txt") }
            Get-ChildItem -Path $eden -Exclude $excl | Copy-Item -Destination $bp -Recurse -Force
            Add-Log (T "WBackupDone")
        }

        # 3) Alten Inhalt loeschen
        $sync.Status = (T "WRemoveOld")
        $removed = $true
        Get-ChildItem -Path $eden -Exclude $excl | Remove-Item -Recurse -Force
        Add-Log (T "WRemovedOld")

        # 4) Entpacken (mit Fortschritt)
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zf = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $n    = $zf.Entries.Count
            $i    = 0
            $root = [IO.Path]::GetFullPath($eden).TrimEnd('\') + '\'
            foreach ($e in $zf.Entries) {
                $i++
                $target = [IO.Path]::GetFullPath((Join-Path $eden $e.FullName))
                if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
                if ($e.FullName.EndsWith('/')) { [void][IO.Directory]::CreateDirectory($target); continue }
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
                if (($i % 20) -eq 0 -or $i -eq $n) {
                    $sync.Progress = [int](100 * $i / $n)
                    $sync.Status   = (TF "WExtracting" $i $n)
                }
            }
        } finally {
            $zf.Dispose()
        }
        Add-Log (T "WExtracted")

        # 5) Version merken, aufraeumen
        $tag | Set-Content (Join-Path $eden "version.txt")
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        $sync.Progress = 100
        $sync.Status   = (TF "WInstalledSt" $tag)
        Add-Log (TF "WInstalledLog" $tag)
        $sync.Result = @{ Kind = "install"; Ok = $true; Tag = $tag }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        if ($removed -and $a.Backup) { Add-Log (TF "WBackupAt" (Join-Path $a.EdenPath "Backup")) }
        $sync.Status = (T "StError")
        $sync.Result = @{ Kind = "install"; Ok = $false; Error = $_.Exception.Message; Cancelled = $cancelled }
    } finally {
        $sync.Done = $true
    }
}

$jobRestore = {
    try {
        $a    = $sync.Args
        $eden = $a.EdenPath
        $bp   = Join-Path $eden "Backup"
        $excl = @($a.Excludes)
        if (-not (Test-Path $bp)) { throw (T "WNoBackup") }

        $running = Get-Process -Name eden -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -and $_.Path.StartsWith($eden, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
        }
        if ($running) { throw (T "WEdenRunning") }

        $items = @(Get-ChildItem -Path $bp -Exclude "backup-version.txt" -Force)
        if ($items.Count -eq 0) { throw (T "WBackupEmpty") }

        $sync.Progress = -1
        $sync.Status   = (T "WRemoveCur")
        Get-ChildItem -Path $eden -Exclude $excl | Remove-Item -Recurse -Force
        Add-Log (T "WRemovedCur")

        $n = $items.Count
        $i = 0
        foreach ($it in $items) {
            $sync.Progress = [int](100 * $i / $n)
            $sync.Status   = (TF "WRestoring" ($i + 1) $n)
            Copy-Item -LiteralPath $it.FullName -Destination $eden -Recurse -Force
            $i++
        }

        $ver = if ($a.BackupVersion) { "$($a.BackupVersion)" } else { T "WUnknownVer" }
        $ver | Set-Content (Join-Path $eden "version.txt")
        $sync.Progress = 100
        $sync.Status   = (TF "WRestoredSt" $ver)
        Add-Log (TF "WRestoredLog" $ver)
        $sync.Result = @{ Kind = "restore"; Ok = $true; Tag = $ver }
    } catch {
        Add-Log ((T "ErrPrefix") + " " + $_.Exception.Message)
        $sync.Status = (T "StError")
        $sync.Result = @{ Kind = "restore"; Ok = $false; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

$jobNotes = {
    $tag = $null
    try {
        $tag  = $sync.Args.Tag
        $enc  = [uri]::EscapeDataString($tag)
        $text = $null
        # 1) API (liefert den Release-Text direkt)
        $r = Get-Page "$BaseUrl/api/v1/repos/eden-ci/nightly/releases/tags/$enc"
        if ($r.Code -eq "200") {
            try {
                $j = $r.Html | ConvertFrom-Json
                if ($j.body) { $text = Format-Notes ([string]$j.body) }
            } catch {}
        }
        # 2) Fallback: Release-Seite
        if (-not $text) {
            $r = Get-Page "$BaseUrl/eden-ci/nightly/releases/tag/$enc"
            if ($r.Code -eq "200") { $text = Convert-HtmlNotes $r.Html }
        }
        $sync.Result = @{ Tag = $tag; Ok = [bool]$text; Text = $text; Error = $null }
    } catch {
        $sync.Result = @{ Tag = $tag; Ok = $false; Text = $null; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# ------------------------------------------------------------
#  Oberflaeche (XAML)
# ------------------------------------------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eden Updater" UseLayoutRounding="True" Width="1080" Height="760" MinWidth="900" MinHeight="640"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource BrBg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  <Window.Resources>
    <FontFamily x:Key="FontHead">Bahnschrift, Segoe UI Semibold</FontFamily>
    <FontFamily x:Key="FontIcon">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <SolidColorBrush x:Key="BrPanel"  Color="#171D26"/>
    <SolidColorBrush x:Key="BrPanel2" Color="#1E2632"/>
    <SolidColorBrush x:Key="BrLine"   Color="#2A3442"/>
    <SolidColorBrush x:Key="BrText"   Color="#E6EDF3"/>
    <SolidColorBrush x:Key="BrMuted"  Color="#8B98A9"/>
    <SolidColorBrush x:Key="BrAccent" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrAccentText" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrBg" Color="#0F1419"/>
    <SolidColorBrush x:Key="BrAccentFg" Color="#04222A"/>
    <SolidColorBrush x:Key="BrSel" Color="#12313A"/>
    <SolidColorBrush x:Key="BrSelStrong" Color="#164E5C"/>
    <SolidColorBrush x:Key="BrLog" Color="#0B0F14"/>
    <SolidColorBrush x:Key="BrBadgeNewBg" Color="#164E3F"/>
    <SolidColorBrush x:Key="BrBadgeNewFg" Color="#34D399"/>
    <SolidColorBrush x:Key="BrBadgeInstBg" Color="#0E3A47"/>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
    </Style>

    <!-- Kleine Ueberschrift in Grossbuchstaben (Karten, Abschnitte) -->
    <Style x:Key="Label" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontHead}"/>
      <Setter Property="FontSize" Value="10.5"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
    </Style>

    <!-- Feldbeschriftung in den Einstellungen -->
    <Style x:Key="FieldTitle" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontHead}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
    </Style>

    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource BrPanel}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="14"/>
      <Setter Property="Padding" Value="20"/>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Margin" Value="0,6,0,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel x:Name="root" Orientation="Horizontal" Background="Transparent">
              <Grid Width="20" Height="20" VerticalAlignment="Center">
                <Border x:Name="box" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                        BorderThickness="1.5" CornerRadius="6"/>
                <Border x:Name="fill" Background="{DynamicResource BrAccent}" CornerRadius="6" Opacity="0"/>
                <Path x:Name="tick" Data="M 5 10.5 L 8.5 14 L 15 6.5" Stroke="{DynamicResource BrAccentFg}"
                      StrokeThickness="2.2" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                      StrokeLineJoin="Round" Opacity="0" RenderTransformOrigin="0.5,0.5">
                  <Path.RenderTransform>
                    <ScaleTransform x:Name="tsc" ScaleX="0.5" ScaleY="0.5"/>
                  </Path.RenderTransform>
                </Path>
                <Border x:Name="ring" BorderBrush="{DynamicResource BrAccent}" BorderThickness="1.5"
                        CornerRadius="6" Opacity="0"/>
              </Grid>
              <ContentPresenter Margin="12,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="tick" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.6"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.6"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="tick" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.10"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleX" To="0.5" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="tsc" Storyboard.TargetProperty="ScaleY" To="0.5" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Ein/Aus-Schalter -->
    <Style x:Key="Switch" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid x:Name="root" Width="40" Height="22" Background="Transparent">
              <Border x:Name="track" CornerRadius="11" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1.5"/>
              <Border x:Name="fill" CornerRadius="11" Background="{DynamicResource BrAccent}" Opacity="0"/>
              <Ellipse x:Name="knob" Width="14" Height="14" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource BrMuted}">
                <Ellipse.RenderTransform>
                  <TranslateTransform x:Name="kx" X="0"/>
                </Ellipse.RenderTransform>
              </Ellipse>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="knob" Property="Fill" Value="{DynamicResource BrAccentFg}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="18" Duration="0:0:0.16"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.16"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="track" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ScrollThumb" TargetType="Thumb">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border x:Name="th" Background="{DynamicResource BrMuted}" CornerRadius="5" Margin="2" Opacity="0.4"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.4" Duration="0:0:0.25"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsDragging" Value="True">
                <Setter TargetName="th" Property="Background" Value="{DynamicResource BrAccent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="PageBtn" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RepeatButton">
            <Border Background="Transparent"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <ControlTemplate x:Key="VBar" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.DecreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageUpCommand" Style="{StaticResource PageBtn}"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumb}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageDownCommand" Style="{StaticResource PageBtn}"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>

    <ControlTemplate x:Key="HBar" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track" IsDirectionReversed="False">
          <Track.DecreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageLeftCommand" Style="{StaticResource PageBtn}"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumb}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Command="ScrollBar.PageRightCommand" Style="{StaticResource PageBtn}"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>

    <Style TargetType="ContextMenu">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ContextMenu">
            <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                    BorderThickness="1" CornerRadius="8" Padding="4">
              <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="MenuItem">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="MenuItem">
            <Border x:Name="bd" Background="Transparent" CornerRadius="6" Padding="12,7" Margin="0,1">
              <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSel}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="{x:Static MenuItem.SeparatorStyleKey}" TargetType="Separator">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Separator">
            <Border Height="1" Background="{DynamicResource BrLine}" Margin="8,4"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ToolTip">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToolTip">
            <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}"
                    BorderThickness="1" CornerRadius="6" Padding="10,6">
              <ContentPresenter/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="12"/>
      <Setter Property="Template" Value="{StaticResource VBar}"/>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="Height" Value="12"/>
          <Setter Property="Template" Value="{StaticResource HBar}"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style TargetType="ProgressBar">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid x:Name="root" ClipToBounds="True">
              <Border x:Name="PART_Track" Background="{DynamicResource BrPanel2}" CornerRadius="3"/>
              <Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{DynamicResource BrAccent}" CornerRadius="3"/>
              <Border x:Name="indet" Visibility="Collapsed" HorizontalAlignment="Left" Width="140"
                      Background="{DynamicResource BrAccent}" CornerRadius="3">
                <Border.RenderTransform>
                  <TranslateTransform x:Name="itt" X="-150"/>
                </Border.RenderTransform>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsIndeterminate" Value="True">
                <Setter TargetName="PART_Indicator" Property="Visibility" Value="Collapsed"/>
                <Setter TargetName="indet" Property="Visibility" Value="Visible"/>
                <Trigger.EnterActions>
                  <BeginStoryboard x:Name="indetSb">
                    <Storyboard RepeatBehavior="Forever">
                      <DoubleAnimation Storyboard.TargetName="itt" Storyboard.TargetProperty="X" From="-150" To="1900" Duration="0:0:2.2"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <StopStoryboard BeginStoryboardName="indetSb"/>
                </Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{DynamicResource BrPanel2}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource BrText}"/>
      <Setter Property="SelectionBrush" Value="{DynamicResource BrAccent}"/>
      <Setter Property="SelectionOpacity" Value="0.4"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False" Padding="{TemplateBinding Padding}"
                            HorizontalScrollBarVisibility="{TemplateBinding HorizontalScrollBarVisibility}"
                            VerticalScrollBarVisibility="{TemplateBinding VerticalScrollBarVisibility}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <ControlTemplate x:Key="CbToggle" TargetType="ToggleButton">
      <Border x:Name="bd" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="8">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="34"/>
          </Grid.ColumnDefinitions>
          <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="{StaticResource FontIcon}" FontSize="11"
                     Foreground="{DynamicResource BrMuted}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Grid>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrMuted}"/>
        </Trigger>
        <Trigger Property="IsChecked" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>

    <Style TargetType="ComboBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="bd" Background="Transparent" Padding="10,7" CornerRadius="6" Margin="3,1">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSel}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BrSelStrong}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ComboBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Template="{StaticResource CbToggle}" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
              <ContentPresenter IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="12,6,38,6" VerticalAlignment="Center" HorizontalAlignment="Left"/>
              <Popup Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Grid MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                  <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
                          CornerRadius="8" Margin="0,4,0,0" Padding="0,3">
                    <ScrollViewer>
                      <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                    </ScrollViewer>
                  </Border>
                </Grid>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Button: Icon kommt aus Tag (Segoe-Glyphe), Text aus Content -->
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Background" Value="{DynamicResource BrPanel2}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}"
                      CornerRadius="9" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}">
                  <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="14"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,9,0"/>
                  <ContentPresenter VerticalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="9" Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="{x:Null}">
                <Setter TargetName="ico" Property="Visibility" Value="Collapsed"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.09" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.96" Duration="0:0:0.08"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.96" Duration="0:0:0.08"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.14"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.14"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{DynamicResource BrAccent}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentFg}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Padding" Value="10,6"/>
    </Style>

    <!-- Seitenleiste: aktiver Eintrag bekommt per Code Hintergrund, Akzentfarbe und den Balken links (BorderBrush) -->
    <Style x:Key="BtnNav" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Padding" Value="14,11"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border Background="{TemplateBinding Background}" CornerRadius="9" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="16"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,13,0"/>
                  <ContentPresenter VerticalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="9" Opacity="0" IsHitTestVisible="False"/>
              <Border Width="3" HorizontalAlignment="Left" Margin="0,10" CornerRadius="2" Background="{TemplateBinding BorderBrush}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.06" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="LbItem" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root" Margin="0,0,0,3">
              <Grid.RenderTransform>
                <TranslateTransform x:Name="tt" Y="0"/>
              </Grid.RenderTransform>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="10" Opacity="0"/>
              <Border x:Name="selb" Background="{DynamicResource BrSel}" CornerRadius="10" Opacity="0"/>
              <Border x:Name="bar" Width="3" HorizontalAlignment="Left" Margin="0,12" CornerRadius="2"
                      Background="{DynamicResource BrAccent}" Opacity="0"/>
              <ContentPresenter Margin="16,10,12,10"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.30"/><DoubleAnimation Storyboard.TargetName="tt" Storyboard.TargetProperty="Y" From="10" To="0" Duration="0:0:0.30"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.18"/><DoubleAnimation Storyboard.TargetName="bar" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/><DoubleAnimation Storyboard.TargetName="bar" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid x:Name="RootGrid">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="236"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- ============ Seitenleiste ============ -->
    <Border Grid.Column="0" Background="{DynamicResource BrPanel}" BorderBrush="{DynamicResource BrLine}" BorderThickness="0,0,1,0">
      <Grid Margin="16,22,16,18">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Margin="6,0,0,0">
          <Border Width="40" Height="40" CornerRadius="10">
            <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#5EEAF4" Offset="0"/>
                <GradientStop Color="#0E7490" Offset="1"/>
              </LinearGradientBrush>
            </Border.Background>
            <Viewbox>
              <Canvas Width="64" Height="64">
                <Path Data="M 42.61,19.36 A 16.5,16.5 0 1 1 19.36,21.39" Stroke="#F4FDFF" StrokeThickness="5"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                <Path Data="M 24.5,15.26 L 14.76,17.53 L 23.96,25.25 Z" Fill="#F4FDFF"/>
                <Path Data="M 32,23 L 32,39 M 25.5,33.5 L 32,40 L 38.5,33.5" Stroke="#F4FDFF" StrokeThickness="5"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
              </Canvas>
            </Viewbox>
          </Border>
          <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
            <TextBlock Text="EDEN" FontFamily="{StaticResource FontHead}" FontSize="17" FontWeight="Bold"/>
            <TextBlock Text="UPDATER" FontFamily="{StaticResource FontHead}" FontSize="10.5" FontWeight="Bold"
                       Foreground="{DynamicResource BrAccentText}" Margin="0,-1,0,0"/>
          </StackPanel>
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="0,34,0,0">
          <Button x:Name="BtnNavVer"   Tag="&#xE8FD;" Content="{DynamicResource L_NavVersions}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavNotes" Tag="&#xE8A5;" Content="{DynamicResource L_NavNotes}"    Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavGames" Tag="&#xE7FC;" Content="{DynamicResource L_NavGames}"    Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavMods"  Tag="&#xEA86;" Content="{DynamicResource L_NavMods}"     Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavSet"   Tag="&#xE713;" Content="{DynamicResource L_NavSettings}" Style="{StaticResource BtnNav}"/>
        </StackPanel>

        <Button x:Name="BtnLaunch" Grid.Row="3" Tag="&#xE768;" Content="{DynamicResource L_BtnLaunch}"
                Style="{StaticResource Btn}" HorizontalContentAlignment="Center" Padding="14,11"/>
      </Grid>
    </Border>

    <!-- ============ Hauptbereich ============ -->
    <Grid Grid.Column="1" Margin="30,24,30,22">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Seitentitel -->
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock x:Name="TxtPageTitle" FontFamily="{StaticResource FontHead}" FontSize="26" FontWeight="SemiBold"/>
          <TextBlock Text="{DynamicResource L_AppSubtitle}" Foreground="{DynamicResource BrMuted}" Margin="0,3,0,0"
                     TextTrimming="CharacterEllipsis"/>
        </StackPanel>
        <!-- Update-Status oben rechts -->
        <Border x:Name="ChipState" Grid.Column="1" CornerRadius="16" Padding="14,7" Margin="16,2,0,0"
                VerticalAlignment="Top" Visibility="Collapsed" BorderThickness="1"
                Background="{DynamicResource BrBadgeNewBg}" BorderBrush="{DynamicResource BrLine}">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="DotState" Width="8" Height="8" VerticalAlignment="Center" Fill="{DynamicResource BrBadgeNewFg}"/>
            <TextBlock x:Name="TxtChip" FontFamily="{StaticResource FontHead}" FontSize="12.5" FontWeight="Bold"
                       Margin="9,0,0,0" VerticalAlignment="Center" Foreground="{DynamicResource BrBadgeNewFg}"/>
          </StackPanel>
        </Border>
      </Grid>

      <!-- Statuskarte: installiert -> neueste -->
      <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,18,0,16" Padding="22,16">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" MinWidth="90"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*" MinWidth="90"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0" VerticalAlignment="Center">
            <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardInstalled}"/>
            <TextBlock x:Name="TxtInstalled" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold"
                       TextTrimming="CharacterEllipsis" Margin="0,4,0,0"/>
          </StackPanel>
          <TextBlock Grid.Column="1" Text="&#xE72A;" FontFamily="{StaticResource FontIcon}" FontSize="16"
                     Foreground="{DynamicResource BrMuted}" VerticalAlignment="Center" Margin="18,14,18,0"/>
          <StackPanel Grid.Column="2" VerticalAlignment="Center">
            <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardLatest}"/>
            <TextBlock x:Name="TxtLatest" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold"
                       Foreground="{DynamicResource BrAccentText}" TextTrimming="CharacterEllipsis" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
            <Button x:Name="BtnUpdate" Tag="&#xE896;" Content="{DynamicResource L_BtnUpdate}"
                    Style="{StaticResource BtnPrimary}" Padding="18,11"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Inhalt -->
      <Grid Grid.Row="2">
        <!-- Seite: Versionen -->
        <Grid x:Name="PanelVersions">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid.ColumnDefinitions>
            <ColumnDefinition x:Name="ColList" Width="*"/>
            <ColumnDefinition x:Name="ColNotes" Width="0"/>
          </Grid.ColumnDefinitions>
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <TextBlock x:Name="TxtListInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="BtnReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnMore" Tag="&#xE70D;" Content="{DynamicResource L_BtnMore}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
            </StackPanel>
          </Grid>

          <Border Grid.Row="1" Style="{StaticResource Card}" Padding="8">
            <ListBox x:Name="List" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                     ItemContainerStyle="{StaticResource LbItem}"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
              <ListBox.ItemTemplate>
                <DataTemplate>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{Binding Tag}" Foreground="{DynamicResource BrText}" FontSize="14.5" FontWeight="SemiBold"
                                 TextTrimming="CharacterEllipsis"/>
                      <TextBlock Text="{Binding Date}" Foreground="{DynamicResource BrMuted}" FontSize="12" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Border Grid.Column="1" Visibility="{Binding NewBadge}" Background="{DynamicResource BrBadgeNewBg}"
                            CornerRadius="10" Padding="9,3" Margin="10,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardLatest}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrBadgeNewFg}"/>
                    </Border>
                    <Border Grid.Column="2" Visibility="{Binding InstBadge}" Background="{DynamicResource BrBadgeInstBg}"
                            CornerRadius="10" Padding="9,3" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardInstalled}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrAccentText}"/>
                    </Border>
                  </Grid>
                </DataTemplate>
              </ListBox.ItemTemplate>
            </ListBox>
          </Border>

          <Border x:Name="PanelNotesSide" Grid.Row="1" Grid.Column="1" Visibility="Collapsed" Style="{StaticResource Card}"
                  Padding="20,16" Margin="12,0,0,0"/>

          <StackPanel Grid.Row="2" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,12,0,0">
            <Button x:Name="BtnInstallSel" Tag="&#xE896;" Content="{DynamicResource L_BtnInstallSel}" Style="{StaticResource Btn}"/>
            <Button x:Name="BtnRestore" Tag="&#xE81C;" Content="{DynamicResource L_BtnRestore}" Style="{StaticResource Btn}" Margin="8,0,0,0"/>
          </StackPanel>
        </Grid>

        <!-- Seite: Patchnotes -->
        <Border x:Name="PanelNotes" Visibility="Collapsed" Style="{StaticResource Card}" Padding="24,18">
          <Border.RenderTransform>
            <TranslateTransform/>
          </Border.RenderTransform>
          <Grid x:Name="NotesContent">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Margin="0,0,0,14">
              <StackPanel Margin="0,0,150,0">
                <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_NotesHeader}"/>
                <TextBlock FontFamily="{StaticResource FontHead}" x:Name="TxtNotesTitle" FontSize="19" FontWeight="SemiBold"
                           TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/>
                <TextBlock x:Name="TxtNotesHint" Text="{DynamicResource L_NotesHintPage}" Style="{StaticResource Hint}" Margin="0,3,0,0"/>
              </StackPanel>
              <Button x:Name="BtnNotesWeb" Tag="&#xE774;" Content="{DynamicResource L_NotesWeb}" Style="{StaticResource Btn}"
                      Padding="12,7" HorizontalAlignment="Right" VerticalAlignment="Top"/>
            </Grid>
            <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
            <TextBox x:Name="TxtNotes" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" Margin="0,14,0,0"
                     VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0"
                     Padding="0" FontSize="14"/>
          </Grid>
        </Border>

        <!-- Seite: Spiele -->
        <Grid x:Name="PanelGames" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Grid MaxWidth="360" HorizontalAlignment="Left" Width="360">
              <TextBox x:Name="TxtGameSearch" Padding="34,7,10,7"/>
              <TextBlock Text="&#xE721;" FontFamily="{StaticResource FontIcon}" FontSize="13" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="12,0,0,0" IsHitTestVisible="False"/>
              <TextBlock x:Name="TxtGameSearchHint" Text="{DynamicResource L_GamesSearch}" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="35,0,0,0" IsHitTestVisible="False"/>
            </Grid>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
              <TextBlock x:Name="TxtGamesInfo" Style="{StaticResource Label}" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <Button x:Name="BtnGamesReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
            </StackPanel>
          </Grid>

          <Border Grid.Row="1" Style="{StaticResource Card}" Padding="8">
            <Grid>
              <ListBox x:Name="ListGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.ItemTemplate>
                  <DataTemplate>
                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Grid Width="44" Height="44" VerticalAlignment="Center">
                        <Border CornerRadius="9" Background="{DynamicResource BrSelStrong}">
                          <TextBlock Text="{Binding Initial}" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="Bold"
                                     Foreground="{DynamicResource BrAccentText}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <Border CornerRadius="9">
                          <Border.Background>
                            <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
                          </Border.Background>
                        </Border>
                      </Grid>
                      <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14.5" FontWeight="SemiBold"
                                   TextTrimming="CharacterEllipsis"/>
                        <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="12" Margin="0,2,0,0"/>
                      </StackPanel>
                    </Grid>
                  </DataTemplate>
                </ListBox.ItemTemplate>
              </ListBox>
              <TextBlock x:Name="TxtGamesEmpty" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                         HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="420" Visibility="Collapsed"/>
            </Grid>
          </Border>

          <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,12,0,0">
            <Button x:Name="BtnGameStart" Tag="&#xE768;" Content="{DynamicResource L_GamesStart}" Style="{StaticResource BtnPrimary}" IsEnabled="False"/>
            <CheckBox x:Name="ChkGamesFull" Content="{DynamicResource L_GamesFull}" VerticalAlignment="Center" Margin="16,0,0,0"/>
            <CheckBox x:Name="ChkGamesClose" Content="{DynamicResource L_GamesClose}" VerticalAlignment="Center" Margin="20,0,0,0"/>
          </StackPanel>
        </Grid>

        <!-- Seite: Mods -->
        <Grid x:Name="PanelMods" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <TextBlock x:Name="TxtModsInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <Button x:Name="BtnModsReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" HorizontalAlignment="Right"/>
          </Grid>

          <Border x:Name="ModsBanner" Grid.Row="1" Visibility="Collapsed" CornerRadius="10" Padding="14,9" Margin="0,0,0,10"
                  Background="{DynamicResource BrBadgeInstBg}">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_ModsEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListModGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.ItemTemplate>
                  <DataTemplate>
                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                      </Grid.ColumnDefinitions>
                      <Grid Width="36" Height="36" VerticalAlignment="Center">
                        <Border CornerRadius="8" Background="{DynamicResource BrSelStrong}">
                          <TextBlock Text="{Binding Initial}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="Bold"
                                     Foreground="{DynamicResource BrAccentText}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <Border CornerRadius="8">
                          <Border.Background>
                            <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
                          </Border.Background>
                        </Border>
                      </Grid>
                      <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
                        <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="13.5"
                                   FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                        <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0"/>
                      </StackPanel>
                    </Grid>
                  </DataTemplate>
                </ListBox.ItemTemplate>
              </ListBox>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <StackPanel Margin="20,16,16,12">
                  <TextBlock x:Name="TxtModGameTitle" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock x:Name="TxtModGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                             FontFamily="Cascadia Mono, Consolas" Margin="0,2,0,10"/>
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnModAdd" Tag="&#xE710;" Content="{DynamicResource L_ModsAdd}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnModFolder" Tag="&#xE838;" Content="{DynamicResource L_ModsFolder}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
                <ListBox x:Name="ListMods" Grid.Row="1" Margin="8,8,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                         ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                  <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
                      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="ListBoxItem">
                            <Grid Margin="0,0,0,3">
                              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="10" Opacity="0"/>
                              <ContentPresenter Margin="14,10,8,10"/>
                            </Grid>
                            <ControlTemplate.Triggers>
                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="hov" Property="Opacity" Value="1"/>
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>
                  </ListBox.ItemContainerStyle>
                  <ListBox.ItemTemplate>
                    <DataTemplate>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Uid="toggle" Style="{StaticResource Switch}" IsChecked="{Binding Enabled, Mode=OneWay}" VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                     FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0"/>
                        </StackPanel>
                        <Button Grid.Column="2" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_ModsDelete}" Style="{StaticResource BtnGhost}"
                                VerticalAlignment="Center"/>
                      </Grid>
                    </DataTemplate>
                  </ListBox.ItemTemplate>
                </ListBox>
                <TextBlock x:Name="TxtModsEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                           HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Visibility="Collapsed"/>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Einstellungen -->
        <Grid x:Name="PanelSettings" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <ScrollViewer x:Name="SettingsScroll" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,8,0">

              <!-- Installation -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                    <TextBlock Text="&#xE8B7;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpInstall}" FontSize="11.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPath}"/>
                  <Grid Margin="0,7,0,4">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="TxtPath" Grid.Column="0"/>
                    <Button x:Name="BtnBrowse" Grid.Column="1" Tag="&#xE838;" Content="{DynamicResource L_SetBrowse}" Style="{StaticResource Btn}"
                            Padding="14,7" Margin="8,0,0,0"/>
                  </Grid>
                  <TextBlock x:Name="TxtSettingsFile" Style="{StaticResource Hint}" Margin="0,0,0,18"/>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetVariant}"/>
                  <ComboBox x:Name="CmbVariant" SelectedValuePath="Tag" Margin="0,7,0,4"/>
                  <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetVariantHint}" Margin="0,0,0,18"/>

                  <StackPanel x:Name="PanelPattern" Visibility="Collapsed">
                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPattern}"/>
                    <TextBox x:Name="TxtPattern" Margin="0,7,0,18" FontFamily="Cascadia Mono, Consolas"/>
                  </StackPanel>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPages}"/>
                  <TextBox x:Name="TxtPages" Width="90" HorizontalAlignment="Left" Margin="0,7,0,0"/>
                </StackPanel>
              </Border>

              <!-- Darstellung -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                    <TextBlock Text="&#xE790;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpLook}" FontSize="11.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetTheme}"/>
                  <Grid Margin="0,7,0,18">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
                            CornerRadius="8" Padding="12,8">
                      <StackPanel Orientation="Horizontal">
                        <Border Width="14" Height="14" CornerRadius="7" Background="{DynamicResource BrAccent}" VerticalAlignment="Center"/>
                        <TextBlock x:Name="TxtThemeName" VerticalAlignment="Center" Margin="10,0,0,0"/>
                      </StackPanel>
                    </Border>
                    <Button x:Name="BtnThemePick" Grid.Column="1" Tag="&#xE771;" Content="{DynamicResource L_SetThemePick}" Style="{StaticResource Btn}"
                            Padding="14,7" Margin="8,0,0,0"/>
                  </Grid>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetLanguage}"/>
                  <ComboBox x:Name="CmbLang" SelectedValuePath="Tag" Margin="0,7,0,4" MaxDropDownHeight="380"/>
                  <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetLanguageHint}" Margin="0,0,0,18"/>

                  <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetNotes}"/>
                  <ComboBox x:Name="CmbNotes" SelectedValuePath="Tag" Margin="0,7,0,0"/>
                </StackPanel>
              </Border>

              <!-- Verhalten -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,0">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                    <TextBlock Text="&#xE9F5;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpBehavior}" FontSize="11.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>
                  <CheckBox x:Name="ChkBackup" Content="{DynamicResource L_ChkBackup}"/>
                  <CheckBox x:Name="ChkStart" Content="{DynamicResource L_ChkStart}"/>
                  <CheckBox x:Name="ChkClose" Content="{DynamicResource L_ChkClose}"/>
                  <CheckBox x:Name="ChkAuto" Content="{DynamicResource L_ChkAuto}"/>
                  <CheckBox x:Name="ChkAutoInstall" Content="{DynamicResource L_ChkAutoInstall}"/>
                </StackPanel>
              </Border>

              <!-- Updater selbst -->
              <Border Style="{StaticResource Card}" Margin="0,14,0,6">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                    <TextBlock Text="&#xE895;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpUpdater}" FontSize="11.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
                      <TextBlock x:Name="TxtSelfVersion" Style="{StaticResource FieldTitle}"/>
                      <TextBlock x:Name="TxtSelfState" Style="{StaticResource Hint}" Margin="0,3,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                      <Button x:Name="BtnSelfNotes" Tag="&#xE774;" Content="{DynamicResource L_SelfBtnNotes}" Style="{StaticResource BtnGhost}"
                              Visibility="Collapsed" Margin="0,0,6,0"/>
                      <Button x:Name="BtnSelfCheck" Tag="&#xE72C;" Content="{DynamicResource L_SelfBtnCheck}" Style="{StaticResource Btn}" Padding="14,8"/>
                      <Button x:Name="BtnSelfInstall" Tag="&#xE896;" Content="{DynamicResource L_SelfBtnInstall}" Style="{StaticResource BtnPrimary}"
                              Padding="14,8" Margin="8,0,0,0" Visibility="Collapsed"/>
                    </StackPanel>
                  </Grid>
                  <CheckBox x:Name="ChkSelfUpdate" Content="{DynamicResource L_SelfChkStart}" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
          <Button x:Name="BtnSave" Grid.Row="1" Tag="&#xE74E;" Content="{DynamicResource L_Save}" Style="{StaticResource BtnPrimary}"
                  HorizontalAlignment="Left" Padding="20,10" Margin="0,12,0,0"/>
        </Grid>
      </Grid>

      <!-- Aktivitaet: Status, Fortschritt, einklappbares Log -->
      <Border Grid.Row="3" Style="{StaticResource Card}" Padding="18,12" Margin="0,16,0,0">
        <StackPanel>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtStatus" Text="{DynamicResource L_StReady}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
            <Button x:Name="BtnCancel" Grid.Column="1" Tag="&#xE711;" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"
                    Padding="12,5" Margin="8,0,0,0" Visibility="Collapsed"/>
            <Button x:Name="BtnLogToggle" Grid.Column="2" Tag="&#xE70D;" Content="{DynamicResource L_LogTitle}" Style="{StaticResource BtnGhost}"
                    Margin="8,0,0,0"/>
          </Grid>
          <ProgressBar x:Name="Pb" Height="6" Minimum="0" Maximum="100" Value="0" Margin="0,10,0,0"
                       Foreground="{DynamicResource BrAccentText}" Background="{DynamicResource BrPanel2}"
                       BorderThickness="0"/>
          <TextBox x:Name="TxtLog" Height="130" Margin="0,12,0,2" IsReadOnly="True" Visibility="Collapsed"
                   FontFamily="Cascadia Mono, Consolas" FontSize="12" Background="{DynamicResource BrLog}"
                   VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
        </StackPanel>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

# ------------------------------------------------------------
#  UI-Hilfsfunktionen
# ------------------------------------------------------------
# ------------------------------------------------------------
#  Farbschema
# ------------------------------------------------------------
# Base/Color sind Text-Schluessel (Anzeige: "Dunkel (Cyan)")
$ThemePresets = [ordered]@{
    "dark-cyan"     = @{ Base = "ThBaseDark";  Color = "ThColCyan";   Bg = "#0F1419"; Panel = "#171D26"; Text = "#E6EDF3"; Accent = "#22D3EE" }
    "dark-blue"     = @{ Base = "ThBaseDark";  Color = "ThColBlue";   Bg = "#0E1320"; Panel = "#161D2E"; Text = "#E5EAF5"; Accent = "#60A5FA" }
    "dark-indigo"   = @{ Base = "ThBaseDark";  Color = "ThColIndigo"; Bg = "#0D0F1E"; Panel = "#15182B"; Text = "#E7E8F7"; Accent = "#818CF8" }
    "dark-violet"   = @{ Base = "ThBaseDark";  Color = "ThColViolet"; Bg = "#110F1A"; Panel = "#1A1726"; Text = "#ECE8F5"; Accent = "#A78BFA" }
    "dark-pink"     = @{ Base = "ThBaseDark";  Color = "ThColPink";   Bg = "#160F14"; Panel = "#21171E"; Text = "#F4E8EF"; Accent = "#F472B6" }
    "dark-red"      = @{ Base = "ThBaseDark";  Color = "ThColRed";    Bg = "#160F10"; Panel = "#211718"; Text = "#F4E9EA"; Accent = "#F87171" }
    "dark-orange"   = @{ Base = "ThBaseDark";  Color = "ThColOrange"; Bg = "#15110E"; Panel = "#1F1915"; Text = "#F3EBE4"; Accent = "#FB923C" }
    "dark-gold"     = @{ Base = "ThBaseDark";  Color = "ThColGold";   Bg = "#14120C"; Panel = "#1E1B13"; Text = "#F2EEE2"; Accent = "#FBBF24" }
    "dark-green"    = @{ Base = "ThBaseDark";  Color = "ThColGreen";  Bg = "#0E1512"; Panel = "#15201B"; Text = "#E4F0EA"; Accent = "#34D399" }
    "dark-grey"     = @{ Base = "ThBaseDark";  Color = "ThColGrey";   Bg = "#121212"; Panel = "#1C1C1E"; Text = "#EDEDED"; Accent = "#D4D4D8" }
    "amoled"        = @{ Base = "ThBaseBlack"; Color = "ThColCyan";   Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#22D3EE" }
    "amoled-red"    = @{ Base = "ThBaseBlack"; Color = "ThColRed";    Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#F87171" }
    "amoled-violet" = @{ Base = "ThBaseBlack"; Color = "ThColViolet"; Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#A78BFA" }
    "light"         = @{ Base = "ThBaseLight"; Color = "ThColCyan";   Bg = "#F3F5F8"; Panel = "#FFFFFF"; Text = "#1B2430"; Accent = "#0891B2" }
    "light-violet"  = @{ Base = "ThBaseLight"; Color = "ThColViolet"; Bg = "#F5F3FA"; Panel = "#FFFFFF"; Text = "#221D33"; Accent = "#7C3AED" }
    "light-green"   = @{ Base = "ThBaseLight"; Color = "ThColGreen";  Bg = "#F2F6F4"; Panel = "#FFFFFF"; Text = "#17251F"; Accent = "#059669" }
    "light-sand"    = @{ Base = "ThBaseLight"; Color = "ThColSand";   Bg = "#F4EFE6"; Panel = "#FFFCF6"; Text = "#2B2620"; Accent = "#C2410C" }
}
$script:ThemeWin = $null
$script:ThemePick = ""
$script:ThemeCards = @{}

function ConvertTo-WpfColor([string]$hex, [string]$fallback) {
    try { return [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
    catch { return [System.Windows.Media.Color][System.Windows.Media.ColorConverter]::ConvertFromString($fallback) }
}

function ConvertTo-Hex($c) { return ("#{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B) }

function Merge-Color($a, $b, [double]$t) {
    $r  = [byte][math]::Round($a.R + ($b.R - $a.R) * $t)
    $g  = [byte][math]::Round($a.G + ($b.G - $a.G) * $t)
    $bl = [byte][math]::Round($a.B + ($b.B - $a.B) * $t)
    return [System.Windows.Media.Color]::FromRgb($r, $g, $bl)
}

function Get-Luma($c) { return (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B) / 255 }

# Relative Helligkeit und Kontrast nach WCAG
function Get-RelLum($c) {
    $ch = foreach ($v in @($c.R, $c.G, $c.B)) {
        $x = $v / 255.0
        if ($x -le 0.03928) { $x / 12.92 } else { [Math]::Pow(($x + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $ch[0] + 0.7152 * $ch[1] + 0.0722 * $ch[2]
}

function Get-Contrast($a, $b) {
    $l1 = Get-RelLum $a; $l2 = Get-RelLum $b
    return ([Math]::Max($l1, $l2) + 0.05) / ([Math]::Min($l1, $l2) + 0.05)
}

# Vordergrund so lange Richtung Schwarz bzw. Weiss schieben, bis der Kontrast reicht
function Get-Readable($fg, $bg, [double]$min) {
    if ((Get-Contrast $fg $bg) -ge $min) { return $fg }
    $target = if ((Get-RelLum $bg) -gt 0.18) { [System.Windows.Media.Colors]::Black } else { [System.Windows.Media.Colors]::White }
    for ($i = 1; $i -le 20; $i++) {
        $c = Merge-Color $fg $target ($i / 20)
        if ((Get-Contrast $c $bg) -ge $min) { return $c }
    }
    return $target
}

# HSV <-> Farbe (fuer den Farbwaehler)
function ConvertTo-Hsv($c) {
    $r = $c.R / 255.0; $g = $c.G / 255.0; $b = $c.B / 255.0
    $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b)); $d = $max - $min
    $h = 0.0
    if ($d -gt 0) {
        if ($max -eq $r)     { $h = 60 * ((($g - $b) / $d) % 6) }
        elseif ($max -eq $g) { $h = 60 * ((($b - $r) / $d) + 2) }
        else                 { $h = 60 * ((($r - $g) / $d) + 4) }
    }
    if ($h -lt 0) { $h += 360 }
    $sat = if ($max -eq 0) { 0.0 } else { $d / $max }
    return @{ H = $h; S = $sat; V = $max }
}

function ConvertFrom-Hsv([double]$h, [double]$sat, [double]$v) {
    $h = (($h % 360) + 360) % 360
    $c = $v * $sat; $x = $c * (1 - [Math]::Abs((($h / 60) % 2) - 1)); $m = $v - $c
    switch ([int][Math]::Floor($h / 60)) {
        0 { $r = $c; $g = $x; $b = 0 }  1 { $r = $x; $g = $c; $b = 0 }  2 { $r = 0; $g = $c; $b = $x }
        3 { $r = 0; $g = $x; $b = $c }  4 { $r = $x; $g = 0; $b = $c }  default { $r = $c; $g = 0; $b = $x }
    }
    return [System.Windows.Media.Color]::FromRgb([byte][Math]::Round(($r + $m) * 255), [byte][Math]::Round(($g + $m) * 255), [byte][Math]::Round(($b + $m) * 255))
}

# ------------------------------------------------------------
#  Titelleiste und Icon im Theme
# ------------------------------------------------------------
if (-not ('DwmTheme' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DwmTheme {
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
    public static void Apply(IntPtr hwnd, bool dark, int caption, int border, int text) {
        int d = dark ? 1 : 0;
        DwmSetWindowAttribute(hwnd, 20, ref d, 4);       // dunkle Titelleiste (Win10 20H1+ / Win11)
        DwmSetWindowAttribute(hwnd, 19, ref d, 4);       // aeltere Win10-Builds
        DwmSetWindowAttribute(hwnd, 35, ref caption, 4); // Titelleistenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 34, ref border, 4);  // Rahmenfarbe (Win11)
        DwmSetWindowAttribute(hwnd, 36, ref text, 4);    // Titeltext (Win11)
    }
}
'@
}

$script:ThemeColors = $null
$script:ThemeKeys = @("BrBg","BrPanel","BrPanel2","BrLine","BrText","BrMuted","BrAccent","BrAccentFg","BrSel","BrSelStrong","BrLog","BrBadgeNewBg","BrBadgeNewFg","BrBadgeInstBg","BrAccentText")

function ConvertTo-ColorRef($c) { return ([int]$c.R -bor ([int]$c.G -shl 8) -bor ([int]$c.B -shl 16)) }

function Set-TitleBar($win) {
    try {
        if (-not $win -or -not $script:ThemeColors) { return }
        $h = [System.Windows.Interop.WindowInteropHelper]::new($win).Handle
        if ($h -eq [IntPtr]::Zero) { return }
        $t = $script:ThemeColors
        [DwmTheme]::Apply($h, [bool]$t.Dark, (ConvertTo-ColorRef $t.Bg), (ConvertTo-ColorRef $t.Line), (ConvertTo-ColorRef $t.Text))
    } catch {}
}

# App-Icon (Fenster + Taskleiste) = das EXE-Icon: Kreispfeil mit Download-Pfeil auf Cyan-Verlauf
function New-AppIcon {
    $C   = [System.Windows.Media.Color]
    $bg  = [System.Windows.Media.LinearGradientBrush]::new($C::FromRgb(0x5E, 0xEA, 0xF4), $C::FromRgb(0x0E, 0x74, 0x90),
            [System.Windows.Point]::new(0, 0), [System.Windows.Point]::new(1, 1))
    $ink = [System.Windows.Media.SolidColorBrush]::new($C::FromRgb(0xF4, 0xFD, 0xFF))
    $pen = [System.Windows.Media.Pen]::new($ink, 5)
    $pen.StartLineCap = "Round"; $pen.EndLineCap = "Round"; $pen.LineJoin = "Round"
    $G = [System.Windows.Media.Geometry]

    $dv = [System.Windows.Media.DrawingVisual]::new()
    $dc = $dv.RenderOpen()
    $dc.PushTransform([System.Windows.Media.ScaleTransform]::new(4, 4))   # 64er Zeichnung -> 256 px
    $dc.DrawRoundedRectangle($bg, $null, [System.Windows.Rect]::new(2, 2, 60, 60), 15, 15)
    $dc.DrawGeometry($null, $pen, $G::Parse("M 42.61,19.36 A 16.5,16.5 0 1 1 19.36,21.39"))
    $dc.DrawGeometry($ink, $null, $G::Parse("M 24.5,15.26 L 14.76,17.53 L 23.96,25.25 Z"))
    $dc.DrawGeometry($null, $pen, $G::Parse("M 32,23 L 32,39 M 25.5,33.5 L 32,40 L 38.5,33.5"))
    $dc.Pop()
    $dc.Close()
    $bmp = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(256, 256, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($dv)
    $bmp.Freeze()
    return $bmp
}

function Set-ThemeBrush([string]$key, $color) {
    $b = [System.Windows.Media.SolidColorBrush]::new($color)
    $b.Freeze()
    $window.Resources[$key] = $b
    if ($script:ThemeWin) { $script:ThemeWin.Resources[$key] = $b }
}

# Aus 4 Grundfarben werden alle weiteren Farben abgeleitet.
# Lesbarkeit wird erzwungen: Text >= 4.5:1, gedaempfter Text und Akzent-Text >= 3:1.
function Set-Theme($t) {
    $bg     = ConvertTo-WpfColor $t.Bg     "#0F1419"
    $panel  = ConvertTo-WpfColor $t.Panel  "#171D26"
    $text   = ConvertTo-WpfColor $t.Text   "#E6EDF3"
    $accent = ConvertTo-WpfColor $t.Accent "#22D3EE"
    $black  = [System.Windows.Media.Colors]::Black
    $white  = [System.Windows.Media.Colors]::White
    $light  = ((Get-RelLum $panel) -gt 0.18)

    $text       = Get-Readable (Get-Readable $text $panel 4.5) $bg 4.5
    $panel2     = Merge-Color $panel $text 0.045
    $line       = Merge-Color $panel $text $(if ($light) { 0.16 } else { 0.14 })
    $muted      = Get-Readable (Merge-Color $text $panel 0.42) $panel 3.0
    $accentText = Get-Readable $accent $panel 3.0
    $sel        = Merge-Color $panel $accent 0.18
    $selStrong  = Merge-Color $panel2 $accent 0.32
    $log        = if ($light) { Merge-Color $panel $text 0.03 } else { Merge-Color $bg $black 0.35 }
    $darkFg     = Merge-Color $accent $black 0.88
    $accentFg   = if ((Get-Contrast $white $accent) -ge (Get-Contrast $darkFg $accent)) { $white } else { $darkFg }
    $green      = ConvertTo-WpfColor "#34D399" "#34D399"
    $greenBg    = Merge-Color $panel $green 0.20
    $greenFg    = Get-Readable $green $greenBg 3.0

    Set-ThemeBrush "BrBg"          $bg
    Set-ThemeBrush "BrPanel"       $panel
    Set-ThemeBrush "BrPanel2"      $panel2
    Set-ThemeBrush "BrLine"        $line
    Set-ThemeBrush "BrText"        $text
    Set-ThemeBrush "BrMuted"       $muted
    Set-ThemeBrush "BrAccent"      $accent
    Set-ThemeBrush "BrAccentText"  $accentText
    Set-ThemeBrush "BrAccentFg"    $accentFg
    Set-ThemeBrush "BrSel"         $sel
    Set-ThemeBrush "BrSelStrong"   $selStrong
    Set-ThemeBrush "BrLog"         $log
    Set-ThemeBrush "BrBadgeNewBg"  $greenBg
    Set-ThemeBrush "BrBadgeNewFg"  $greenFg
    Set-ThemeBrush "BrBadgeInstBg" (Merge-Color $panel $accent 0.20)

    $script:ThemeColors = @{ Bg = $bg; Text = $text; Line = $line; Dark = (-not $light) }
    Set-TitleBar $window
    if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
    if (-not $window.Icon) { try { $window.Icon = New-AppIcon } catch {} }
}

function Get-ThemeKey {
    $k = [string]$script:Settings.ThemePreset
    if ($k -eq "custom" -and $script:Settings.CustomTheme -and $script:Settings.CustomTheme.Bg) { return "custom" }
    if ($k -and $ThemePresets.Contains($k)) { return $k }
    return "dark-cyan"
}

# Die 4 Grundfarben eines Themes (Vorlage oder eigenes)
function Get-ThemeColors([string]$id) {
    if ($id -eq "custom") {
        $c = $script:Settings.CustomTheme
        if ($c -and $c.Bg) { return @{ Bg = [string]$c.Bg; Panel = [string]$c.Panel; Text = [string]$c.Text; Accent = [string]$c.Accent } }
        $id = "dark-cyan"
    }
    if (-not $ThemePresets.Contains($id)) { $id = "dark-cyan" }
    $p = $ThemePresets[$id]
    return @{ Bg = $p.Bg; Panel = $p.Panel; Text = $p.Text; Accent = $p.Accent }
}

$script:CurrentThemeId = "dark-cyan"
function Set-ThemeById([string]$id) {
    $script:CurrentThemeId = $id
    Set-Theme (Get-ThemeColors $id)
}
function Set-ThemeByKey([string]$key) { Set-ThemeById $key }

function Get-ThemeLabel([string]$key) {
    if ($key -eq "custom") { return (T "ThCustom") }
    if (-not $ThemePresets.Contains($key)) { $key = "dark-cyan" }
    $p = $ThemePresets[$key]
    return ("{0} ({1})" -f (T $p.Base), (T $p.Color))
}

function Update-ThemeLabel {
    $ui.TxtThemeName.Text = Get-ThemeLabel (Get-ThemeKey)
}

$themeDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="{DynamicResource L_ThemeTitle}" Width="800" Height="660" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" Foreground="{DynamicResource BrText}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13">
  __RES__
  <Grid Margin="26,22,26,22">
    <Grid.Resources>
      <!-- Farbfeld-Auswahl links (Hintergrund, Flaechen, Text, Akzent) -->
      <Style x:Key="Slot" TargetType="Button">
        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
        <Setter Property="Margin" Value="0,0,0,8"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="Button">
              <Grid>
                <Border Background="{DynamicResource BrPanel}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="2"
                        CornerRadius="11" Padding="12,10">
                  <ContentPresenter/>
                </Border>
                <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="11" Opacity="0" IsHitTestVisible="False"/>
              </Grid>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="hl" Property="Opacity" Value="0.05"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
    </Grid.Resources>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0">
      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_ThemeTag}"/>
      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_ThemeTitle}" FontSize="22" FontWeight="SemiBold" Margin="0,2,0,2"/>
      <TextBlock x:Name="TxtDlgHint" Style="{StaticResource Hint}"/>
    </StackPanel>

    <Border Grid.Row="1" Background="{DynamicResource BrPanel}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
            CornerRadius="11" Padding="4" HorizontalAlignment="Left" Margin="0,16,0,16">
      <StackPanel Orientation="Horizontal">
        <Button x:Name="TabPresets" Tag="&#xE8FD;" Content="{DynamicResource L_ThTabPresets}" Style="{StaticResource BtnGhost}" Padding="14,7"/>
        <Button x:Name="TabCustom" Tag="&#xE790;" Content="{DynamicResource L_ThTabCustom}" Style="{StaticResource BtnGhost}" Padding="14,7" Margin="4,0,0,0"/>
      </StackPanel>
    </Border>

    <!-- Vorlagen -->
    <ScrollViewer x:Name="PagePresets" Grid.Row="2" VerticalScrollBarVisibility="Auto">
      <StackPanel Margin="0,0,6,0">
        <TextBlock x:Name="HdrDark" Style="{StaticResource Label}" Margin="2,0,0,10"/>
        <WrapPanel x:Name="HostDark"/>
        <TextBlock x:Name="HdrBlack" Style="{StaticResource Label}" Margin="2,8,0,10"/>
        <WrapPanel x:Name="HostBlack"/>
        <TextBlock x:Name="HdrLight" Style="{StaticResource Label}" Margin="2,8,0,10"/>
        <WrapPanel x:Name="HostLight"/>
      </StackPanel>
    </ScrollViewer>

    <!-- Eigenes Theme -->
    <Grid x:Name="PageCustom" Grid.Row="2" Visibility="Collapsed">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240"/>
        <ColumnDefinition Width="22"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <Button x:Name="SlotBg" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwBg" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotBg}"/>
              <TextBlock x:Name="HxBg" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotPanel" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwPanel" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotPanel}"/>
              <TextBlock x:Name="HxPanel" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotText" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwText" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotText}"/>
              <TextBlock x:Name="HxText" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Button x:Name="SlotAccent" Style="{StaticResource Slot}">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border x:Name="SwAccent" Width="30" Height="30" CornerRadius="15" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
              <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_ThSlotAccent}"/>
              <TextBlock x:Name="HxAccent" Style="{StaticResource Hint}" FontFamily="Cascadia Mono, Consolas"/>
            </StackPanel>
          </Grid>
        </Button>
        <Border Background="{DynamicResource BrPanel}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="11"
                Padding="12,10" Margin="0,6,0,0">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="DotContrast" Width="9" Height="9" VerticalAlignment="Center" Fill="{DynamicResource BrBadgeNewFg}"/>
            <TextBlock x:Name="TxtContrast" TextWrapping="Wrap" FontSize="12" Margin="9,0,0,0" MaxWidth="190" VerticalAlignment="Center"/>
          </StackPanel>
        </Border>
      </StackPanel>

      <Border Grid.Column="2" Style="{StaticResource Card}" Padding="18">
        <StackPanel>
          <Grid x:Name="SvBox" Width="436" Height="236" Cursor="Cross" Background="Transparent" ClipToBounds="True">
            <Rectangle x:Name="SvHue" RadiusX="10" RadiusY="10" Fill="Red"/>
            <Rectangle RadiusX="10" RadiusY="10">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#FFFFFFFF" Offset="0"/>
                  <GradientStop Color="#00FFFFFF" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Rectangle RadiusX="10" RadiusY="10">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                  <GradientStop Color="#00000000" Offset="0"/>
                  <GradientStop Color="#FF000000" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Canvas IsHitTestVisible="False">
              <Grid x:Name="SvDot" Width="20" Height="20">
                <Ellipse Stroke="#99000000" StrokeThickness="1"/>
                <Ellipse Margin="1" Stroke="White" StrokeThickness="2.5"/>
              </Grid>
            </Canvas>
          </Grid>
          <Grid x:Name="HueBar" Width="436" Height="16" Margin="0,16,0,0" Cursor="Hand" Background="Transparent">
            <Rectangle RadiusX="8" RadiusY="8">
              <Rectangle.Fill>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#FF0000" Offset="0"/>
                  <GradientStop Color="#FFFF00" Offset="0.1667"/>
                  <GradientStop Color="#00FF00" Offset="0.3333"/>
                  <GradientStop Color="#00FFFF" Offset="0.5"/>
                  <GradientStop Color="#0000FF" Offset="0.6667"/>
                  <GradientStop Color="#FF00FF" Offset="0.8333"/>
                  <GradientStop Color="#FF0000" Offset="1"/>
                </LinearGradientBrush>
              </Rectangle.Fill>
            </Rectangle>
            <Canvas IsHitTestVisible="False">
              <Border x:Name="HueThumb" Width="10" Height="24" Canvas.Top="-4" CornerRadius="5" Background="White"
                      BorderBrush="#99000000" BorderThickness="1"/>
            </Canvas>
          </Grid>
          <Grid Margin="0,18,0,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border x:Name="PickSwatch" Width="38" Height="38" CornerRadius="9" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"/>
            <TextBlock Grid.Column="1" Text="HEX" Style="{StaticResource Label}" VerticalAlignment="Center" Margin="14,0,10,0"/>
            <TextBox x:Name="TxtHex" Grid.Column="2" Width="130" HorizontalAlignment="Left" FontFamily="Cascadia Mono, Consolas" MaxLength="7"/>
          </Grid>
        </StackPanel>
      </Border>
    </Grid>

    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="BtnThemeCancel" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"/>
      <Button x:Name="BtnThemeOk" Tag="&#xE73E;" Content="{DynamicResource L_Apply}" Style="{StaticResource BtnPrimary}" Margin="8,0,0,0"/>
    </StackPanel>
  </Grid>
</Window>
'@

$themeCardXaml = @'
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Tag="@@KEY@@" Width="132" Height="92" Margin="0,0,12,12" Padding="0" Cursor="Hand"
        BorderThickness="2" BorderBrush="Transparent" Background="Transparent">
  <Button.Template>
    <ControlTemplate TargetType="Button">
      <Border Background="@@BG@@" CornerRadius="10" RenderTransformOrigin="0.5,0.5"
              BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
        <Border.RenderTransform>
          <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
        </Border.RenderTransform>
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Border Background="@@PANEL@@" CornerRadius="6" Padding="8,7">
            <StackPanel>
              <Border Background="@@ACCENT@@" Height="8" Width="40" CornerRadius="4" HorizontalAlignment="Left"/>
              <Border Background="@@TEXT@@" Height="4" Width="76" CornerRadius="2" HorizontalAlignment="Left" Margin="0,8,0,0" Opacity="0.85"/>
              <Border Background="@@TEXT@@" Height="4" Width="52" CornerRadius="2" HorizontalAlignment="Left" Margin="0,5,0,0" Opacity="0.5"/>
            </StackPanel>
          </Border>
          <TextBlock FontFamily="{DynamicResource FontHead}" Grid.Row="1" Text="@@LABEL@@" Foreground="@@TEXT@@" FontSize="11" FontWeight="SemiBold"
                     Margin="2,6,0,0" TextTrimming="CharacterEllipsis"/>
        </Grid>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1.05" Duration="0:0:0.12"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1.05" Duration="0:0:0.12"/>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
          <Trigger.ExitActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.16"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.16"/>
            </Storyboard></BeginStoryboard>
          </Trigger.ExitActions>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>
  </Button.Template>
</Button>
'@

function Update-ThemeCards {
    foreach ($k in $script:ThemeCards.Keys) {
        $btn = $script:ThemeCards[$k]
        if ($k -eq $script:ThemePick) {
            $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrAccent")
        } else {
            $btn.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        }
    }
}

function New-Brush([string]$hex) {
    $b = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-WpfColor $hex "#000000"))
    $b.Freeze()
    return $b
}

# Reiter im Theme-Fenster
function Set-ThemeTab([string]$tab) {
    $d = $script:Dlg
    $c = [System.Windows.Controls.Control]
    foreach ($pair in @(@($d.TabPresets, "presets"), @($d.TabCustom, "custom"))) {
        if ($pair[1] -eq $tab) {
            $pair[0].SetResourceReference($c::BackgroundProperty, "BrSel")
            $pair[0].SetResourceReference($c::ForegroundProperty, "BrAccentText")
        } else {
            $pair[0].ClearValue($c::BackgroundProperty)
            $pair[0].ClearValue($c::ForegroundProperty)
        }
    }
    $d.PagePresets.Visibility = if ($tab -eq "presets") { "Visible" } else { "Collapsed" }
    $d.PageCustom.Visibility  = if ($tab -eq "custom")  { "Visible" } else { "Collapsed" }
    $d.TxtDlgHint.Text = if ($tab -eq "custom") { T "ThCustomHint" } else { T "ThemeHint" }
    if ($tab -eq "custom" -and $script:ThemePick -ne "custom") {
        # Eigenes Theme startet mit den Farben der zuletzt gewaehlten Vorlage
        $script:Draft = Get-ThemeColors $script:ThemePick
        $script:ThemePick = "custom"
        Set-Theme $script:Draft
        Update-ThemeCards
    }
    if ($tab -eq "custom") { Set-PickerFromHex $script:Draft[$script:Slot]; Update-Slots }
}

# Farbfelder links + Lesbarkeit
function Update-Slots {
    $d = $script:Dlg
    foreach ($slot in @("Bg", "Panel", "Text", "Accent")) {
        $hex = [string]$script:Draft[$slot]
        $d["Sw$slot"].Background = New-Brush $hex
        $d["Hx$slot"].Text = $hex.ToUpper()
        $btn = $d["Slot$slot"]
        if ($slot -eq $script:Slot) { $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrAccent") }
        else { $btn.SetResourceReference([System.Windows.Controls.Control]::BorderBrushProperty, "BrLine") }
    }
    $ratio = Get-Contrast (ConvertTo-WpfColor $script:Draft.Text "#FFFFFF") (ConvertTo-WpfColor $script:Draft.Panel "#000000")
    $ok = $ratio -ge 4.5
    $d.TxtContrast.Text = (TF "ThContrast" ([Math]::Round($ratio, 1))) + "  –  " + $(if ($ok) { T "ThContrastOk" } else { T "ThContrastLow" })
    if ($ok) { $d.DotContrast.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, "BrBadgeNewFg") }
    else     { $d.DotContrast.Fill = New-Brush "#F59E0B" }
}

# Farbwaehler
$script:Pick = @{ H = 0.0; S = 0.0; V = 0.0 }
$script:PickWatch = [Diagnostics.Stopwatch]::StartNew()

function Set-PickerFromHex([string]$hex) {
    $script:Pick = ConvertTo-Hsv (ConvertTo-WpfColor $hex "#000000")
    Update-PickerVisual
}

function Update-PickerVisual {
    $d = $script:Dlg
    $w = $d.SvBox.Width; $h = $d.SvBox.Height
    $d.SvHue.Fill = [System.Windows.Media.SolidColorBrush]::new((ConvertFrom-Hsv $script:Pick.H 1 1))
    [System.Windows.Controls.Canvas]::SetLeft($d.SvDot, $script:Pick.S * $w - 10)
    [System.Windows.Controls.Canvas]::SetTop($d.SvDot, (1 - $script:Pick.V) * $h - 10)
    [System.Windows.Controls.Canvas]::SetLeft($d.HueThumb, $script:Pick.H / 360 * $d.HueBar.Width - 5)
    $c = ConvertFrom-Hsv $script:Pick.H $script:Pick.S $script:Pick.V
    $d.PickSwatch.Background = [System.Windows.Media.SolidColorBrush]::new($c)
    if (-not $d.TxtHex.IsKeyboardFocused) { $d.TxtHex.Text = ConvertTo-Hex $c }
}

# Aktuelle Picker-Farbe ins gewaehlte Feld schreiben (Vorschau gedrosselt, damit das Ziehen fluessig bleibt)
function Commit-Picker([bool]$force) {
    $script:Draft[$script:Slot] = ConvertTo-Hex (ConvertFrom-Hsv $script:Pick.H $script:Pick.S $script:Pick.V)
    Update-Slots
    if ($force -or $script:PickWatch.ElapsedMilliseconds -gt 60) {
        Set-Theme $script:Draft
        $script:PickWatch.Restart()
    }
}

function Set-PickFromSv($pt) {
    $d = $script:Dlg
    $script:Pick.S = [Math]::Min(1.0, [Math]::Max(0.0, $pt.X / $d.SvBox.Width))
    $script:Pick.V = [Math]::Min(1.0, [Math]::Max(0.0, 1 - $pt.Y / $d.SvBox.Height))
    Update-PickerVisual
}

function Set-PickFromHue($pt) {
    $script:Pick.H = [Math]::Min(359.9, [Math]::Max(0.0, $pt.X / $script:Dlg.HueBar.Width * 360))
    Update-PickerVisual
}

function Set-HexFromBox {
    $t = $script:Dlg.TxtHex.Text.Trim()
    if ($t -match '^#?([0-9a-fA-F]{6})$') {
        $hex = "#" + $Matches[1].ToUpper()
        $script:Draft[$script:Slot] = $hex
        Set-PickerFromHex $hex
        Update-Slots
        Set-Theme $script:Draft
    } else {
        Update-PickerVisual
    }
}

# Theme-Fenster aufbauen (wird auch fuer Screenshots genutzt)
function New-ThemeDialog([string]$tab = "presets") {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $dlg = [Windows.Markup.XamlReader]::Parse($themeDlgXaml.Replace('__RES__', $resBlock))
    $dlg.Owner = $window
    foreach ($k in $script:ThemeKeys) { $dlg.Resources[$k] = $window.Resources[$k] }
    Set-LangResources $dlg
    $script:ThemeWin   = $dlg
    $script:ThemePick  = $script:CurrentThemeId
    $script:ThemeCards = @{}
    $script:Draft      = Get-ThemeColors $script:ThemePick
    $script:Slot       = "Accent"

    $d = @{}
    foreach ($n in @("TxtDlgHint","TabPresets","TabCustom","PagePresets","PageCustom","HdrDark","HdrBlack","HdrLight","HostDark","HostBlack","HostLight",
                     "SlotBg","SlotPanel","SlotText","SlotAccent","SwBg","SwPanel","SwText","SwAccent","HxBg","HxPanel","HxText","HxAccent",
                     "TxtContrast","DotContrast","SvBox","SvHue","SvDot","HueBar","HueThumb","PickSwatch","TxtHex","BtnThemeOk","BtnThemeCancel")) {
        $d[$n] = $dlg.FindName($n)
    }
    $script:Dlg = $d
    $d.HdrDark.Text  = (T "ThBaseDark").ToUpper()
    $d.HdrBlack.Text = (T "ThBaseBlack").ToUpper() + "  ·  AMOLED"
    $d.HdrLight.Text = (T "ThBaseLight").ToUpper()

    foreach ($k in $ThemePresets.Keys) {
        $p  = $ThemePresets[$k]
        $cx = $themeCardXaml.Replace('@@KEY@@', $k).Replace('@@BG@@', $p.Bg).Replace('@@PANEL@@', $p.Panel).Replace('@@TEXT@@', $p.Text).Replace('@@ACCENT@@', $p.Accent).Replace('@@LABEL@@', [System.Security.SecurityElement]::Escape((T $p.Color)))
        $btn = [Windows.Markup.XamlReader]::Parse($cx)
        $btn.Add_Click({
            param($sender, $e)
            try {
                $script:ThemePick = [string]$sender.Tag
                $script:Draft = Get-ThemeColors $script:ThemePick
                Set-ThemeById $script:ThemePick
                Update-ThemeCards
            } catch {}
        })
        $hostPanel = switch ($p.Base) { "ThBaseLight" { $d.HostLight } "ThBaseBlack" { $d.HostBlack } default { $d.HostDark } }
        [void]$hostPanel.Children.Add($btn)
        $script:ThemeCards[$k] = $btn
    }

    $d.TabPresets.Add_Click({ Set-ThemeTab "presets" })
    $d.TabCustom.Add_Click({ Set-ThemeTab "custom" })
    foreach ($slot in @("Bg", "Panel", "Text", "Accent")) {
        $d["Slot$slot"].Tag = $slot
        $d["Slot$slot"].Add_Click({
            param($sender, $e)
            $script:Slot = [string]$sender.Tag
            Set-PickerFromHex $script:Draft[$script:Slot]
            Update-Slots
        })
    }
    $d.SvBox.Add_MouseLeftButtonDown({ param($sender, $e) [void]$sender.CaptureMouse(); Set-PickFromSv ($e.GetPosition($sender)); Commit-Picker $false })
    $d.SvBox.Add_MouseMove({ param($sender, $e) if ($sender.IsMouseCaptured) { Set-PickFromSv ($e.GetPosition($sender)); Commit-Picker $false } })
    $d.SvBox.Add_MouseLeftButtonUp({ param($sender, $e) $sender.ReleaseMouseCapture(); Commit-Picker $true })
    $d.HueBar.Add_MouseLeftButtonDown({ param($sender, $e) [void]$sender.CaptureMouse(); Set-PickFromHue ($e.GetPosition($sender)); Commit-Picker $false })
    $d.HueBar.Add_MouseMove({ param($sender, $e) if ($sender.IsMouseCaptured) { Set-PickFromHue ($e.GetPosition($sender)); Commit-Picker $false } })
    $d.HueBar.Add_MouseLeftButtonUp({ param($sender, $e) $sender.ReleaseMouseCapture(); Commit-Picker $true })
    $d.TxtHex.Add_KeyDown({ param($sender, $e) if ($e.Key -eq "Return") { Set-HexFromBox } })
    $d.TxtHex.Add_LostKeyboardFocus({ Set-HexFromBox })
    $d.BtnThemeOk.Add_Click({ $script:ThemeWin.Tag = "ok"; $script:ThemeWin.Close() })
    $d.BtnThemeCancel.Add_Click({ $script:ThemeWin.Close() })
    $dlg.Add_SourceInitialized({ Set-TitleBar $script:ThemeWin })

    Set-Theme $script:Draft
    Update-ThemeCards
    Update-Slots
    if ($tab -eq "custom" -and $script:ThemePick -ne "custom") { $script:ThemePick = "custom"; Update-ThemeCards }
    Set-ThemeTab $tab
    return $dlg
}

# Theme-Fenster anzeigen (Klick = Vorschau, Uebernehmen = speichern)
function Show-ThemeDialog {
    Set-ThemeById (Get-ThemeKey)
    $dlg = New-ThemeDialog "presets"
    $dlg.Add_ContentRendered({ try { Start-FadeIn $script:ThemeWin.Content 0 } catch {} })
    [void]$dlg.ShowDialog()
    if ($dlg.Tag -eq "ok") {
        if ($script:ThemePick -eq "custom") {
            $script:Settings.CustomTheme = @{ Bg = $script:Draft.Bg; Panel = $script:Draft.Panel; Text = $script:Draft.Text; Accent = $script:Draft.Accent }
        }
        $script:Settings.ThemePreset = $script:ThemePick
        Save-Settings
        Add-UiLog (TF "LogThemeSaved" (Get-ThemeLabel $script:ThemePick))
    }
    $script:ThemeWin = $null
    Set-ThemeById (Get-ThemeKey)       # Vorschau verwerfen bzw. gespeichertes Theme setzen
    Update-ThemeLabel
}

$msgDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eden Updater" Width="460" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  __RES__
  <Border Background="{DynamicResource BrPanel}" CornerRadius="10" Margin="16" Padding="20,18">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="MsgBar" Width="4" CornerRadius="2" Margin="0,2,16,2" Background="{DynamicResource BrAccent}"/>
      <StackPanel Grid.Column="1">
        <TextBlock x:Name="MsgTitle" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
        <TextBlock x:Name="MsgText" TextWrapping="Wrap" Foreground="{DynamicResource BrText}"/>
        <StackPanel x:Name="MsgButtons" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0"/>
      </StackPanel>
    </Grid>
  </Border>
</Window>
'@

$script:MsgWin = $null
$script:MsgResult = "Cancel"

# Ersatz fuer die weisse Windows-MessageBox: buttons = "OK" oder "YesNo", Rueckgabe "OK"/"Yes"/"No"
function Show-Dialog([string]$text, [string]$buttons = "OK", [string]$icon = "Information") {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $d = [Windows.Markup.XamlReader]::Parse($msgDlgXaml.Replace('__RES__', $resBlock))
    foreach ($k in $script:ThemeKeys) { $d.Resources[$k] = $window.Resources[$k] }
    Set-LangResources $d
    if ($window.IsVisible) { $d.Owner = $window }
    $script:MsgWin    = $d
    $script:MsgResult = if ($buttons -eq "YesNo") { "No" } else { "OK" }

    $titles = @{ Warning = (T "DlgWarning"); Error = (T "DlgError"); Question = (T "DlgQuestion"); Information = (T "DlgInfo") }
    $d.Title = $titles[$icon]
    $d.FindName("MsgTitle").Text = $titles[$icon]
    $d.FindName("MsgText").Text  = $text
    $bar = $d.FindName("MsgBar")
    if ($icon -eq "Warning") { $bar.Background = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-WpfColor "#F59E0B" "#F59E0B")) }
    elseif ($icon -eq "Error") { $bar.Background = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-WpfColor "#EF4444" "#EF4444")) }

    $panelBtns = $d.FindName("MsgButtons")
    $defs = if ($buttons -eq "YesNo") { @(@((T "No"), "No", $false), @((T "Yes"), "Yes", $true)) } else { @(, @((T "OK"), "OK", $true)) }
    foreach ($def in $defs) {
        $b = [System.Windows.Controls.Button]::new()
        $b.Content = $def[0]
        $b.CommandParameter = $def[1]
        $b.MinWidth = 84
        $b.Style   = $d.FindResource($(if ($def[2]) { "BtnPrimary" } else { "Btn" }))
        $b.Margin  = [System.Windows.Thickness]::new(8, 0, 0, 0)
        if ($def[2]) { $b.IsDefault = $true } else { $b.IsCancel = $true }
        $b.Add_Click({ param($sender, $e) $script:MsgResult = [string]$sender.CommandParameter; $script:MsgWin.Close() })
        [void]$panelBtns.Children.Add($b)
    }
    $d.Add_SourceInitialized({ Set-TitleBar $script:MsgWin })
    $d.Add_ContentRendered({ try { Start-FadeIn $script:MsgWin.Content 0 } catch {} })
    [void]$d.ShowDialog()
    $script:MsgWin = $null
    return $script:MsgResult
}

function Get-Brush([string]$hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function Show-Msg([string]$text, [string]$icon = "Warning") {
    [void](Show-Dialog $text "OK" $icon)
}

function Set-LogVisible([bool]$show) {
    $ui.TxtLog.Visibility = if ($show) { "Visible" } else { "Collapsed" }
    $ui.BtnLogToggle.Tag  = [string][char]$(if ($show) { 0xE70E } else { 0xE70D })
    if ($show) { $ui.TxtLog.ScrollToEnd() }
}

function Add-UiLog([string]$m) {
    # Fehler klappen das Log automatisch auf
    if ($m.StartsWith((T "ErrPrefix"))) { try { Set-LogVisible $true } catch {} }
    $ui.TxtLog.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format "HH:mm:ss"), $m))
    $ui.TxtLog.ScrollToEnd()
}

function Flush-Log {
    $line = $null
    while ($sync.Log.TryDequeue([ref]$line)) { Add-UiLog $line }
}

function Get-InstalledVersion {
    $vf = Join-Path $script:Settings.EdenPath "version.txt"
    if (Test-Path $vf) {
        $v = Get-Content $vf -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($v) { return "$v".Trim() }
    }
    return $null
}

# Dropdown-Eintrag: angezeigt wird nur der Text, der Wert steckt im Tag
function New-CbItem([string]$label, [string]$value) {
    $i = [System.Windows.Controls.ComboBoxItem]::new()
    $i.Content = $label
    $i.Tag     = $value
    return $i
}

function Update-PatternVisibility {
    $ui.PanelPattern.Visibility = if ([string]$ui.CmbVariant.SelectedValue -eq "__custom__") { "Visible" } else { "Collapsed" }
}

function Update-VariantCombo {
    $s = $script:Settings
    $cur = if ($ui.CmbVariant.Items.Count -gt 0 -and $null -ne $ui.CmbVariant.SelectedValue) { [string]$ui.CmbVariant.SelectedValue } else { [string]$s.AssetVariant }
    $items = New-Object System.Collections.ArrayList
    [void]$items.Add((New-CbItem ((T "VarRecommended")) ("")))
    $known = @{}
    foreach ($v in $script:Variants) {
        $known[$v.Key] = $true
        [void]$items.Add((New-CbItem ([string]$v.Key) ([string]$v.Key)))
    }
    if ($cur -and $cur -ne "__custom__" -and -not $known.ContainsKey($cur)) {
        [void]$items.Add((New-CbItem ($cur) ($cur)))
    }
    [void]$items.Add((New-CbItem ((T "VarCustom")) ("__custom__")))
    $script:SuppressVariantEvent = $true
    $ui.CmbVariant.ItemsSource = $items.ToArray()
    $ui.CmbVariant.SelectedValue = $cur
    $script:SuppressVariantEvent = $false
    Update-PatternVisibility
}

function Get-BackupVersion {
    $f = Join-Path (Join-Path $script:Settings.EdenPath "Backup") "backup-version.txt"
    if (Test-Path $f) {
        $v = Get-Content $f -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($v) { return "$v".Trim() }
    }
    return $null
}

function Test-HasBackup {
    $bp = Join-Path $script:Settings.EdenPath "Backup"
    if (-not (Test-Path $bp)) { return $false }
    return (@(Get-ChildItem -Path $bp -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "backup-version.txt" }).Count -gt 0)
}

function Update-List {
    $inst   = Get-InstalledVersion
    $latest = if ($script:Releases.Count -gt 0) { $script:Releases[0].Tag } else { $null }
    $vis    = [System.Windows.Visibility]::Visible
    $col    = [System.Windows.Visibility]::Collapsed
    $items = foreach ($r in $script:Releases) {
        [pscustomobject]@{
            Tag       = $r.Tag
            Url       = $r.Url
            Date      = $r.Date
            NewBadge  = if ($r.Tag -eq $latest) { $vis } else { $col }
            InstBadge = if ($inst -and $r.Tag -eq $inst) { $vis } else { $col }
        }
    }
    $prevTag = if ($ui.List.SelectedItem) { $ui.List.SelectedItem.Tag } else { $null }
    $ui.List.ItemsSource = @($items)
    $ui.TxtListInfo.Text = TF "ListInfo" $script:Releases.Count
    if ($ui.List.Items.Count -gt 0) {
        $idx = 0
        if ($prevTag) {
            for ($i = 0; $i -lt $ui.List.Items.Count; $i++) {
                if ($ui.List.Items[$i].Tag -eq $prevTag) { $idx = $i; break }
            }
        }
        $ui.List.SelectedIndex = $idx
    }
}

# Punkt im Status-Chip pulsiert, solange gesucht wird oder ein Update wartet
function Set-DotPulse([bool]$on) {
    $prop = [System.Windows.UIElement]::OpacityProperty
    if ($on) {
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 0.25, [TimeSpan]::FromMilliseconds(850))
        $a.AutoReverse    = $true
        $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $ui.DotState.BeginAnimation($prop, $a)
    } else {
        $ui.DotState.BeginAnimation($prop, $null)
        $ui.DotState.Opacity = 1
    }
}

function Set-StateChip([string]$text, [string]$bg, [string]$fg, [bool]$pulse) {
    $ui.ChipState.Visibility = "Visible"
    $ui.TxtChip.Text = $text
    $ui.ChipState.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $bg)
    $ui.TxtChip.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fg)
    $ui.DotState.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, $fg)
    if ($script:ChipPulse -ne $pulse) { Set-DotPulse $pulse; $script:ChipPulse = $pulse }
}

function Update-StateChip($latest) {
    if ($script:Busy -and $script:BusyKind -eq "load") {
        Set-StateChip (T "StSearching") "BrPanel2" "BrMuted" $true
    } elseif ($script:UpdateAvailable) {
        Set-StateChip (T "ChipUpdate") "BrBadgeNewBg" "BrBadgeNewFg" $true
    } elseif ($latest) {
        Set-StateChip (T "BtnUpToDate") "BrBadgeInstBg" "BrAccentText" $false
    } else {
        $ui.ChipState.Visibility = "Collapsed"
    }
}

function Update-Ui {
    try { Update-SelfCard } catch {}
    $inst   = Get-InstalledVersion
    $latest = if ($script:Releases.Count -gt 0) { $script:Releases[0].Tag } else { $null }
    $ui.TxtInstalled.Text = if ($inst) { $inst } else { T "NotInstalled" }
    $ui.TxtLatest.Text    = if ($latest) { $latest } else { "-" }
    $script:UpdateAvailable = [bool]($latest -and $latest -ne $inst)
    Update-StateChip $latest

    $busy = $script:Busy
    $ui.BtnUpdate.Content   = if ($script:UpdateAvailable) { T "BtnUpdate" } elseif ($latest) { T "BtnUpToDate" } else { T "BtnUpdate" }
    $ui.BtnUpdate.IsEnabled = (-not $busy) -and $script:UpdateAvailable
    $sel = $ui.List.SelectedItem
    $ui.BtnInstallSel.Content   = if ($sel -and $inst -and $sel.Tag -eq $inst) { T "BtnReinstall" } else { T "BtnInstallSel" }
    $ui.BtnInstallSel.IsEnabled = (-not $busy) -and ($null -ne $sel)
    $ui.BtnReload.IsEnabled = -not $busy
    $hasBk = Test-HasBackup
    $bv    = Get-BackupVersion
    $ui.BtnRestore.Content   = if ($hasBk -and $bv) { TF "BtnRestoreTo" $bv } else { T "BtnRestore" }
    $ui.BtnRestore.IsEnabled = (-not $busy) -and $hasBk
    $ui.BtnMore.IsEnabled   = -not $busy
    $ui.BtnSave.IsEnabled   = -not $busy
    $ui.BtnLaunch.IsEnabled = (-not $busy) -and (Test-Path (Join-Path $script:Settings.EdenPath "eden.exe"))
    $ui.BtnCancel.Visibility = if ($busy -and $script:BusyKind -eq "install") { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ui.BtnCancel.IsEnabled  = [bool]$sync.CanCancel
}

function Test-NotesVisible {
    return (($script:CurrentPage -eq "notes") -or (([string]$script:Settings.NotesLayout -eq "side") -and ($script:CurrentPage -eq "versions")))
}

# Patchnotes entweder als eigene Seite oder neben der Versionsliste
function Set-NotesLayout {
    $side    = ([string]$script:Settings.NotesLayout -eq "side")
    $content = $ui.NotesContent
    $parent  = $content.Parent
    if ($parent -is [System.Windows.Controls.Border]) { $parent.Child = $null }
    if ($side) {
        $ui.PanelNotesSide.Child      = $content
        $ui.PanelNotesSide.Visibility = "Visible"
        $ui.ColList.Width  = New-Object System.Windows.GridLength(1.1, [System.Windows.GridUnitType]::Star)
        $ui.ColNotes.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ui.BtnNavNotes.Visibility = "Collapsed"
        $ui.TxtNotesHint.Text = T "NotesHintSide"
        if ($script:CurrentPage -eq "notes") { Set-Page "versions"; return }
    } else {
        $ui.PanelNotes.Child          = $content
        $ui.PanelNotesSide.Visibility = "Collapsed"
        $ui.ColList.Width  = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ui.ColNotes.Width = New-Object System.Windows.GridLength(0)
        $ui.BtnNavNotes.Visibility = "Visible"
        $ui.TxtNotesHint.Text = T "NotesHintPage"
    }
    if (Test-NotesVisible) { try { Show-Notes } catch {} }
}

# ------------------------------------------------------------
#  Animationen
# ------------------------------------------------------------
function Start-FadeIn($el, [double]$slide = 10) {
    if (-not $el -or $script:Snapshot) { return }
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, 1.0, [TimeSpan]::FromMilliseconds(260))
    $fade.EasingFunction = $ease
    $el.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $tt = $el.RenderTransform
    if ($slide -ne 0 -and $tt -is [System.Windows.Media.TranslateTransform]) {
        $mv = [System.Windows.Media.Animation.DoubleAnimation]::new($slide, 0.0, [TimeSpan]::FromMilliseconds(300))
        $mv.EasingFunction = $ease
        $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $mv)
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

function Set-NavActive($btn, [bool]$active) {
    $c = [System.Windows.Controls.Control]
    if ($active) {
        $btn.SetResourceReference($c::BackgroundProperty,  "BrPanel2")
        $btn.SetResourceReference($c::ForegroundProperty,  "BrAccentText")
        $btn.SetResourceReference($c::BorderBrushProperty, "BrAccent")
    } else {
        $btn.ClearValue($c::BackgroundProperty)
        $btn.ClearValue($c::ForegroundProperty)
        $btn.ClearValue($c::BorderBrushProperty)
    }
}

function Set-Page([string]$page) {
    $prev = $script:CurrentPage
    $script:CurrentPage = $page
    $ui.PanelVersions.Visibility = if ($page -eq "versions") { "Visible" } else { "Collapsed" }
    $ui.PanelNotes.Visibility    = if ($page -eq "notes")    { "Visible" } else { "Collapsed" }
    $ui.PanelSettings.Visibility = if ($page -eq "settings") { "Visible" } else { "Collapsed" }
    $ui.PanelGames.Visibility    = if ($page -eq "games")    { "Visible" } else { "Collapsed" }
    $ui.PanelMods.Visibility     = if ($page -eq "mods")     { "Visible" } else { "Collapsed" }
    Set-NavActive $ui.BtnNavVer   ($page -eq "versions")
    Set-NavActive $ui.BtnNavNotes ($page -eq "notes")
    Set-NavActive $ui.BtnNavGames ($page -eq "games")
    Set-NavActive $ui.BtnNavMods  ($page -eq "mods")
    Set-NavActive $ui.BtnNavSet   ($page -eq "settings")
    $titleKey = switch ($page) { "notes" { "L_NavNotes" } "games" { "L_NavGames" } "mods" { "L_NavMods" } "settings" { "L_NavSettings" } default { "L_NavVersions" } }
    if ($page -eq "games" -and -not $script:GamesLoaded) { Start-GameScan }
    if ($page -eq "mods" -and -not $script:Snapshot) { Open-ModsTab }
    $ui.TxtPageTitle.SetResourceReference([System.Windows.Controls.TextBlock]::TextProperty, $titleKey)
    if ($prev -ne $page) {
        $el = switch ($page) { "versions" { $ui.PanelVersions } "notes" { $ui.PanelNotes } "games" { $ui.PanelGames } "mods" { $ui.PanelMods } "settings" { $ui.PanelSettings } }
        Start-FadeIn $el
    }
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
                    $bi.DecodePixelWidth = 96
                    $bi.UriSource        = [Uri]::new([string]$g.Icon)
                    $bi.EndInit()
                    $bi.Freeze()
                    $img = $bi
                } catch {}
            }
            $g | Add-Member -NotePropertyName IconImg -NotePropertyValue $img -Force
        }
        $script:Games     = @($r.Games)
        if ($r.CacheNames) { $script:CacheNames = $r.CacheNames }
        $script:GamesDirs = [int]$r.Dirs
    } else {
        $script:Games = @()
        $script:GamesDirs = 0
        if ($r) { Add-UiLog ((T "ErrPrefix") + " " + $r.Error) }
    }
    Update-GameList
    if ($script:ModsLoaded) { Update-ModGames }
}

function Update-GameList {
    $q = $ui.TxtGameSearch.Text.Trim()
    $ui.TxtGameSearchHint.Visibility = if ($ui.TxtGameSearch.Text) { "Collapsed" } else { "Visible" }
    if (-not $script:GamesLoaded) { return }
    $list = if ($q) { @($script:Games | Where-Object { $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 }) } else { @($script:Games) }
    $ui.ListGames.ItemsSource = $list
    $hasEden = Test-Path (Join-Path $script:Settings.EdenPath "eden.exe")
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
            $lists[$Matches[1]].Add($Matches[3])
        }
    }
    foreach ($i in ($tids.Keys | Sort-Object { [int]$_ })) {
        $l = New-Object System.Collections.Generic.List[string]
        if ($lists.ContainsKey($i)) { foreach ($x in $lists[$i]) { if ($x) { $l.Add($x) } } }
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
            $sec.Add("$i\disabled\$j\d=$($d.Replace('\', '/'))")
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
            Tid = $e.Tid; Name = $e.Name; IconImg = $e.IconImg
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
    [void]$ps.AddScript($jobSelf.ToString())
    $script:SelfWorker = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() }
}

function Start-SelfCheck([bool]$auto) {
    if (-not $script:SelfExe -or $script:SelfWorker) { return }
    $script:SelfAuto  = $auto
    $script:SelfState = "checking"
    Update-SelfCard
    Start-SelfWorker @{ Mode = "check"; Repo = $SelfRepo }
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
            Install-SelfUpdate ([string]$r.File)
            return
        }
        $script:SelfState = "error"; $script:SelfError = [string]$r.Error
        Show-Msg (TF "SelfStateError" $r.Error) "Error"
    }
    Update-SelfCard
}

function Ask-SelfUpdate {
    if ($script:SelfState -ne "found" -or -not $script:SelfInfo) { return }
    $q = TF "SelfAsk" (Format-Ver $script:SelfVersion) (Format-Ver $script:SelfInfo.Version)
    if ((Show-Dialog $q "YesNo" "Question") -eq "Yes") { Start-SelfDownload }
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
foreach ($n in @("BtnNavVer","BtnNavNotes","BtnNavSet","PanelNotes","PanelNotesSide","NotesContent","TxtNotesHint","ColList","ColNotes","CmbNotes","BtnRestore","ChkClose","TxtThemeName","BtnThemePick","CmbLang","RootGrid","TxtPageTitle","ChipState","TxtChip","DotState","BtnLogToggle","TxtSelfVersion","TxtSelfState","BtnSelfCheck","BtnSelfInstall","BtnSelfNotes","ChkSelfUpdate","BtnNavGames","PanelGames","BtnNavMods","PanelMods","TxtModsInfo","BtnModsReload","ModsBanner","ListModGames","TxtModGameTitle","TxtModGameSub","BtnModAdd","BtnModFolder","ListMods","TxtModsEmpty","TxtGameSearch","TxtGameSearchHint","BtnGamesReload","ChkGamesFull","ChkGamesClose","ListGames","TxtGamesInfo","TxtGamesEmpty","BtnGameStart","SettingsScroll","TxtSettingsFile","TxtInstalled","TxtLatest","BtnUpdate","BtnLaunch",
                 "PanelVersions","PanelSettings","List","BtnInstallSel","BtnMore","BtnReload","TxtListInfo",
                 "TxtPath","BtnBrowse","CmbVariant","PanelPattern","TxtPattern","TxtPages","ChkBackup","ChkStart","ChkAuto","ChkAutoInstall","BtnSave",
                 "TxtStatus","BtnCancel","Pb","TxtLog","TxtNotesTitle","BtnNotesWeb","TxtNotes")) {
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
    $ui.ChkStart.IsChecked       = [bool]$s.StartAfter
    $ui.ChkClose.IsChecked       = [bool]$s.CloseAfterStart
    Update-ThemeLabel
    Update-LangCombo
    $ui.ChkAuto.IsChecked        = [bool]$s.AutoCheck
    $ui.ChkAutoInstall.IsChecked = [bool]$s.AutoInstall
    $ui.ChkSelfUpdate.IsChecked  = [bool]$s.SelfUpdateCheck
    $ui.ChkGamesFull.IsChecked   = [bool]$s.GamesFullscreen
    $ui.ChkGamesClose.IsChecked  = [bool]$s.GamesCloseOnStart
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
$ui.BtnGamesReload.Add_Click({ Start-GameScan })
$ui.BtnGameStart.Add_Click({ Start-Game $ui.ListGames.SelectedItem })
$ui.ListGames.Add_MouseDoubleClick({ if ($ui.ListGames.SelectedItem) { Start-Game $ui.ListGames.SelectedItem } })
$ui.ListGames.Add_SelectionChanged({ Update-GameButton })
$ui.ListGames.Add_KeyDown({ param($s, $e) if ($e.Key -eq "Return" -and $ui.ListGames.SelectedItem) { Start-Game $ui.ListGames.SelectedItem } })
$ui.TxtGameSearch.Add_TextChanged({ Update-GameList })
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
$ui.BtnLogToggle.Add_Click({ Set-LogVisible ($ui.TxtLog.Visibility -ne "Visible") })
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
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = T "SetBrowseTitle"
        if (Test-Path $ui.TxtPath.Text) { $dlg.SelectedPath = $ui.TxtPath.Text }
        if ($dlg.ShowDialog() -eq "OK") { $ui.TxtPath.Text = $dlg.SelectedPath }
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
            SelfUpdateCheck = [bool]$ui.ChkSelfUpdate.IsChecked
            GamesFullscreen = [bool]$ui.ChkGamesFull.IsChecked
            GamesCloseOnStart = [bool]$ui.ChkGamesClose.IsChecked
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
        if ([string]$old.EdenPath -ne $path) { $script:GamesLoaded = $false }
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
        if ($script:ModWorker -and $modSync.Done) { Complete-ModWorker }
        if ($script:CurrentPage -eq "mods") { Update-ModsBanner }
        if ($script:SelfPrompt -and -not $script:Busy -and -not $script:MsgWin -and -not $script:ThemeWin) {
            $script:SelfPrompt = $false
            Ask-SelfUpdate
        }
        if ($script:SelfCleanAt -and [DateTime]::Now -gt $script:SelfCleanAt) { $script:SelfCleanAt = $null; Remove-SelfOld }
    } catch {}
})

# --- Installation darf nicht mittendrin durch Schliessen unterbrochen werden
$window.Add_Closing({
    param($s, $e)
    if ($script:Busy -and ($script:BusyKind -eq "install" -or $script:BusyKind -eq "restore")) {
        $e.Cancel = $true
        Show-Msg (T "MsgBusyClose") "Information"
    }
})

# Erster Start: Eden-Ordner abfragen (Vorschlag: Ordner des Updaters)
function Invoke-FirstRun {
    $dir = [string]$ScriptDir
    $ans = Show-Dialog (TF "FirstRunAsk" $dir) "YesNo" "Question"
    if ($ans -ne "Yes") {
        try {
            $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlg.Description  = T "SetBrowseTitle"
            $dlg.SelectedPath = $dir
            if ($dlg.ShowDialog() -eq "OK") { $dir = $dlg.SelectedPath }
        } catch {}
    }
    $script:Settings.EdenPath = $dir
    Save-Settings
    Set-SettingsControls
    Update-Ui
    Add-UiLog (TF "SetStoredAt" (Get-SettingsPathFor $dir))
}

$window.Add_SourceInitialized({ Set-TitleBar $window })
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
    $script:Games = @("Abenteuer im Nebelwald", "Kart Turbo Deluxe", "Pixel Quest", "Sternenhafen 2", "Zeitreise-Labor") | ForEach-Object {
        [pscustomobject]@{ Name = $_; Path = ""; Info = "NSP  ·  4,2 GB"; Initial = $_.Substring(0, 1); Icon = ""; IconImg = $null }
    }
    $script:GamesLoaded = $true
    $script:GamesDirs   = 1
    $i = 0
    foreach ($g in $script:Games) { $i++; $g | Add-Member -NotePropertyName Tid -NotePropertyValue ("0100000000{0:X2}0000" -f $i) -Force }
    $script:Mods = @(
        @{ Tid = "0100000000010000"; Name = "60 FPS"; Path = ""; Size = 48KB; Parts = "exefs" },
        @{ Tid = "0100000000010000"; Name = "HD-Texturen"; Path = ""; Size = 1.4GB; Parts = "romfs" },
        @{ Tid = "0100000000010000"; Name = "Unendlich Ausdauer"; Path = ""; Size = 2KB; Parts = "cheats" },
        @{ Tid = "0100000000020000"; Name = "Dynamische Aufloesung aus"; Path = ""; Size = 12KB; Parts = "exefs" }
    )
    $script:ModsLoaded = $true
    Update-List
    Update-GameList
    Update-ModGames
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
        foreach ($pg in @("versions", "notes", "games", "mods", "settings", "settings-end", "dialog", "themes", "themes-custom")) {
            $script:SnapSteps.Enqueue(@{ Theme = $t; Page = $pg })
        }
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
                default        { Set-Page $st.Page }
            }
            $script:SnapPending = $st
        } catch {
            try { Add-Content -Path (Join-Path $script:Snapshot "errors.txt") -Value ($_.Exception.Message + " | " + $_.InvocationInfo.PositionMessage) } catch {}
        }
    })
    $script:SnapTimer.Start()
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
    Start-FadeIn $ui.RootGrid 0
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
[void]$window.ShowDialog()
