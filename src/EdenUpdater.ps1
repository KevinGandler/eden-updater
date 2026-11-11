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
SubNotes=Was sich in der gewählten Version geändert hat
SubGames=Deine Spiele direkt mit Eden starten
SubMods=Mods pro Spiel verwalten
SubContent=Updates und DLCs pro Spiel verwalten
SubSaves=Spielstände sichern und Shader-Cache aufräumen
SubFirmware=Firmware und Schlüssel für Eden
SubSettings=Updater und Oberfläche einstellen
SelfWaiting=Das Updater-Update ist geladen und wird installiert, sobald die laufende Aktion fertig ist.
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
GamesContinue=Weiterspielen
GamesLastPlayed=Zuletzt gespielt: {0}
GamesLaunches={0}× gestartet
GamesSortName=Nach Name
GamesSortRecent=Zuletzt gespielt
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Als Favorit markieren (oben anzeigen)
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
NavContent=Updates & DLC
NavFirmware=Firmware
SysEdenRunning=Eden läuft gerade. Schließe Eden, bevor du hier etwas änderst, sonst überschreibt Eden die Änderungen beim Beenden.
ContentInfo={0} Updates · {1} DLCs
ContentScanning=Suche nach Updates und DLCs...
ContentCopying=Kopiere {0}...
ContentAdd=Update/DLC hinzufügen...
ContentFolder=Ordner öffnen
ContentDelete=Löschen
ContentGameInfo={0} Updates · {1} DLCs
ContentNone=Keine Updates/DLCs
ContentEmptyGame=Für dieses Spiel sind keine Updates oder DLCs vorhanden. Füge mit 'Update/DLC hinzufügen...' eine NSP- oder XCI-Datei hinzu.
ContentUpdate=Update {0}
ContentUpdateAny=Update
ContentDlc=DLC {0}
ContentUnknown=Update/DLC
ContentFromGameDir=aus dem Spieleordner
ContentFromNand=im NAND installiert
ContentNandNoKeys=Im NAND installierte Updates/DLCs können ohne prod.keys nicht erkannt werden (siehe Firmware-Tab).
ContentDlcAll=Schalter gilt für alle DLCs
ContentAskDelete='{0}' löschen?\n\nDie Datei wird in den Papierkorb verschoben.
ContentDeleted=Gelöscht: {0}
ContentAdded=Hinzugefügt: {0}
ContentOtherGame='{0}' gehört zu einem anderen Spiel (Title-ID {1}) und wird dort angezeigt.
ContentToggledOn=Aktiviert: {0}
ContentToggledOff=Deaktiviert: {0}
ContentRegistered=Ordner in Eden als externer Inhaltsordner eingetragen: {0}
FwTitle=Firmware
FwNone=Keine Firmware installiert
FwVersion=Firmware {0}
FwVersionUnknown=Firmware installiert (Version unbekannt)
FwFiles={0} Dateien · {1}
FwInstallZip=Aus ZIP installieren...
FwInstallDir=Aus Ordner...
FwDelete=Löschen
FwFolder=Ordner öffnen
FwHint=Beim Installieren wird die vorhandene Firmware ersetzt. Klappt etwas nicht, bleibt die alte Firmware erhalten.
FwPreparing=Bereite Firmware vor...
FwInstalling=Installiere Firmware... {0}/{1}
FwDone=Firmware installiert ({0} Dateien).
FwNoNca=In der Auswahl wurden keine .nca-Dateien gefunden.
FwAskReplace=Es ist bereits Firmware installiert ({0}). Ersetzen?
FwAskDelete=Firmware wirklich löschen?\n\nSpiele, die Firmware brauchen, starten danach nicht mehr.
FwDeleted=Firmware gelöscht.
FwKeysTooOld=Deine prod.keys sind zu alt für diese Firmware (sie reichen bis Firmware {0}).
KeysTitle=Schlüssel
KeysNone=Keine prod.keys installiert
KeysInstalled=prod.keys · {0} Schlüssel
KeysGen=Reicht bis Firmware {1} (Master-Key {0})
KeysGenRaw=Master-Key {0}
KeysTitleKeys=title.keys · {0} Einträge
KeysInstall=prod.keys installieren...
KeysDelete=Löschen
KeysHint=title.keys und key_retail.bin aus demselben Ordner werden mitkopiert.
KeysInvalid=Die gewählte Datei sieht nicht wie eine prod.keys aus.
KeysDone=Schlüssel installiert.
KeysAskDelete=prod.keys und title.keys löschen?\n\nDie Dateien werden in den Papierkorb verschoben.
KeysDeleted=Schlüssel gelöscht.
KeysMissingForFw=Ohne prod.keys kann Eden die Firmware nicht nutzen.
NavSaves=Spieldaten
SavesInfo={0} Spielstände · {1} Backups · Shader-Cache {2}
SavesScanning=Suche Spielstände und Shader-Caches...
SavesWorking=Bitte warten...
SavesBackupDir=Backup-Ordner
SavesShaderAll=Alle Shader-Caches löschen
SavesGameSave=Spielstand {0}
SavesGameNoSave=Kein Spielstand
SavesGameShader=Shader {0}
SavesGameBackups={0} Backups
SavesSaveTitle=Spielstand
SavesSaveInfo={0} · geändert {1}
SavesSaveNone=Noch kein Spielstand – Eden legt ihn beim ersten Speichern im Spiel an.
SavesBackupNow=Jetzt sichern
SavesOpenFolder=Ordner öffnen
SavesShaderTitle=Shader-Cache
SavesShaderNone=Kein Shader-Cache
SavesShaderDelete=Cache löschen
SavesShaderHint=Hilft bei Grafikfehlern nach einem Eden-Update. Eden baut den Cache beim Spielen neu auf (anfangs kurze Ruckler).
SavesBackupsTitle=Backups
SavesBackupsEmpty=Noch keine Backups für dieses Spiel. Mit 'Jetzt sichern' legst du eins an.
SavesRestore=Wiederherstellen
SavesDelete=Löschen
SavesReasonManual=Manuell
SavesReasonAuto=Automatisch vor Eden-Update
SavesReasonRestore=Stand vor dem Wiederherstellen
SavesBackupDone=Spielstand gesichert: {0}
SavesNothing=Für dieses Spiel gibt es keinen Spielstand zum Sichern.
SavesAskRestore=Spielstand vom {0} wiederherstellen?\n\nDer aktuelle Spielstand wird vorher gesichert.
SavesRestored=Spielstand wiederhergestellt: {0}
SavesAskDelete=Backup vom {0} löschen?\n\nDie Datei wird in den Papierkorb verschoben.
SavesDeleted=Backup gelöscht: {0}
SavesAskShader=Shader-Cache von '{0}' löschen ({1})?
SavesAskShaderAll=Alle Shader-Caches löschen ({0})?\n\nEden baut sie beim Spielen neu auf.
SavesShaderDeleted=Shader-Cache gelöscht: {0}
ChkSaveAuto=Spielstände vor jedem Eden-Update sichern
WSavesBackup=Sichere Spielstände...
WSavesBacked=Spielstände gesichert ({0} Spiele mit Änderungen).
'@
en = @'
Name=English
Culture=en-US
AppSubtitle=Update to the latest nightly or install older versions
SubNotes=What changed in the selected version
SubGames=Start your games directly with Eden
SubMods=Manage mods per game
SubContent=Manage updates and DLCs per game
SubSaves=Back up saves and clean up the shader cache
SubFirmware=Firmware and keys for Eden
SubSettings=Configure the updater and the interface
SelfWaiting=The updater update is downloaded and will be installed as soon as the current task has finished.
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
GamesContinue=Continue playing
GamesLastPlayed=Last played: {0}
GamesLaunches=launched {0}×
GamesSortName=By name
GamesSortRecent=Recently played
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Mark as favorite (show at top)
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
NavContent=Updates & DLC
NavFirmware=Firmware
SysEdenRunning=Eden is running. Close Eden before changing anything here, otherwise Eden overwrites the changes when it exits.
ContentInfo={0} updates · {1} DLCs
ContentScanning=Searching for updates and DLCs...
ContentCopying=Copying {0}...
ContentAdd=Add update/DLC...
ContentFolder=Open folder
ContentDelete=Delete
ContentGameInfo={0} updates · {1} DLCs
ContentNone=No updates/DLCs
ContentEmptyGame=No updates or DLCs for this game. Use 'Add update/DLC...' to add an NSP or XCI file.
ContentUpdate=Update {0}
ContentUpdateAny=Update
ContentDlc=DLC {0}
ContentUnknown=Update/DLC
ContentFromGameDir=from the game folder
ContentFromNand=installed in NAND
ContentNandNoKeys=Updates/DLCs installed in NAND can't be identified without prod.keys (see Firmware tab).
ContentDlcAll=Switch applies to all DLCs
ContentAskDelete=Delete '{0}'?\n\nThe file will be moved to the Recycle Bin.
ContentDeleted=Deleted: {0}
ContentAdded=Added: {0}
ContentOtherGame='{0}' belongs to a different game (Title ID {1}) and is shown there.
ContentToggledOn=Enabled: {0}
ContentToggledOff=Disabled: {0}
ContentRegistered=Folder added to Eden as an external content folder: {0}
FwTitle=Firmware
FwNone=No firmware installed
FwVersion=Firmware {0}
FwVersionUnknown=Firmware installed (version unknown)
FwFiles={0} files · {1}
FwInstallZip=Install from ZIP...
FwInstallDir=From folder...
FwDelete=Delete
FwFolder=Open folder
FwHint=Installing replaces the current firmware. If something goes wrong, the old firmware is kept.
FwPreparing=Preparing firmware...
FwInstalling=Installing firmware... {0}/{1}
FwDone=Firmware installed ({0} files).
FwNoNca=No .nca files were found in the selection.
FwAskReplace=Firmware is already installed ({0}). Replace it?
FwAskDelete=Really delete the firmware?\n\nGames that need firmware will no longer start.
FwDeleted=Firmware deleted.
FwKeysTooOld=Your prod.keys are too old for this firmware (they cover up to firmware {0}).
KeysTitle=Keys
KeysNone=No prod.keys installed
KeysInstalled=prod.keys · {0} keys
KeysGen=Covers up to firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} entries
KeysInstall=Install prod.keys...
KeysDelete=Delete
KeysHint=title.keys and key_retail.bin from the same folder are copied too.
KeysInvalid=The selected file doesn't look like a prod.keys file.
KeysDone=Keys installed.
KeysAskDelete=Delete prod.keys and title.keys?\n\nThe files will be moved to the Recycle Bin.
KeysDeleted=Keys deleted.
KeysMissingForFw=Eden can't use the firmware without prod.keys.
NavSaves=Game data
SavesInfo={0} saves · {1} backups · shader cache {2}
SavesScanning=Searching for saves and shader caches...
SavesWorking=Please wait...
SavesBackupDir=Backup folder
SavesShaderAll=Delete all shader caches
SavesGameSave=Save {0}
SavesGameNoSave=No save
SavesGameShader=Shaders {0}
SavesGameBackups={0} backups
SavesSaveTitle=Save data
SavesSaveInfo={0} · changed {1}
SavesSaveNone=No save yet – Eden creates it the first time you save in the game.
SavesBackupNow=Back up now
SavesOpenFolder=Open folder
SavesShaderTitle=Shader cache
SavesShaderNone=No shader cache
SavesShaderDelete=Delete cache
SavesShaderHint=Helps with graphics glitches after an Eden update. Eden rebuilds the cache while you play (short stutters at first).
SavesBackupsTitle=Backups
SavesBackupsEmpty=No backups for this game yet. Use 'Back up now' to create one.
SavesRestore=Restore
SavesDelete=Delete
SavesReasonManual=Manual
SavesReasonAuto=Automatic before Eden update
SavesReasonRestore=State before restoring
SavesBackupDone=Save backed up: {0}
SavesNothing=There is no save to back up for this game.
SavesAskRestore=Restore the save from {0}?\n\nThe current save is backed up first.
SavesRestored=Save restored: {0}
SavesAskDelete=Delete the backup from {0}?\n\nThe file will be moved to the Recycle Bin.
SavesDeleted=Backup deleted: {0}
SavesAskShader=Delete the shader cache of '{0}' ({1})?
SavesAskShaderAll=Delete all shader caches ({0})?\n\nEden rebuilds them while you play.
SavesShaderDeleted=Shader cache deleted: {0}
ChkSaveAuto=Back up saves before every Eden update
WSavesBackup=Backing up saves...
WSavesBacked=Saves backed up ({0} games with changes).
'@
es = @'
Name=Español
Culture=es-ES
AppSubtitle=Actualiza a la última nightly o instala versiones anteriores
SubNotes=Qué cambió en la versión seleccionada
SubGames=Inicia tus juegos directamente con Eden
SubMods=Gestiona los mods de cada juego
SubContent=Gestiona las actualizaciones y DLC de cada juego
SubSaves=Copia tus partidas y limpia la caché de shaders
SubFirmware=Firmware y claves para Eden
SubSettings=Configura el actualizador y la interfaz
SelfWaiting=La actualización del actualizador está descargada y se instalará cuando termine la tarea en curso.
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
GamesContinue=Seguir jugando
GamesLastPlayed=Última partida: {0}
GamesLaunches=iniciado {0}×
GamesSortName=Por nombre
GamesSortRecent=Jugados recientemente
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Marcar como favorito (mostrar arriba)
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
NavContent=Actualizaciones y DLC
NavFirmware=Firmware
SysEdenRunning=Eden se está ejecutando. Cierra Eden antes de cambiar algo aquí; si no, Eden sobrescribirá los cambios al cerrarse.
ContentInfo={0} actualizaciones · {1} DLC
ContentScanning=Buscando actualizaciones y DLC...
ContentCopying=Copiando {0}...
ContentAdd=Añadir actualización/DLC...
ContentFolder=Abrir carpeta
ContentDelete=Eliminar
ContentGameInfo={0} actualizaciones · {1} DLC
ContentNone=Sin actualizaciones/DLC
ContentEmptyGame=No hay actualizaciones ni DLC para este juego. Usa 'Añadir actualización/DLC...' para añadir un archivo NSP o XCI.
ContentUpdate=Actualización {0}
ContentUpdateAny=Actualización
ContentDlc=DLC {0}
ContentUnknown=Actualización/DLC
ContentFromGameDir=de la carpeta de juegos
ContentFromNand=instalado en la NAND
ContentNandNoKeys=Las actualizaciones/DLC instalados en la NAND no se pueden identificar sin prod.keys (ver pestaña Firmware).
ContentDlcAll=El interruptor afecta a todos los DLC
ContentAskDelete=¿Eliminar '{0}'?\n\nEl archivo se moverá a la Papelera.
ContentDeleted=Eliminado: {0}
ContentAdded=Añadido: {0}
ContentOtherGame='{0}' pertenece a otro juego (Title ID {1}) y se muestra allí.
ContentToggledOn=Activado: {0}
ContentToggledOff=Desactivado: {0}
ContentRegistered=Carpeta añadida a Eden como carpeta de contenido externo: {0}
FwTitle=Firmware
FwNone=No hay firmware instalado
FwVersion=Firmware {0}
FwVersionUnknown=Firmware instalado (versión desconocida)
FwFiles={0} archivos · {1}
FwInstallZip=Instalar desde ZIP...
FwInstallDir=Desde carpeta...
FwDelete=Eliminar
FwFolder=Abrir carpeta
FwHint=Al instalar se reemplaza el firmware actual. Si algo falla, se conserva el firmware anterior.
FwPreparing=Preparando firmware...
FwInstalling=Instalando firmware... {0}/{1}
FwDone=Firmware instalado ({0} archivos).
FwNoNca=No se encontraron archivos .nca en la selección.
FwAskReplace=Ya hay firmware instalado ({0}). ¿Reemplazarlo?
FwAskDelete=¿Eliminar el firmware?\n\nLos juegos que necesitan firmware dejarán de iniciarse.
FwDeleted=Firmware eliminado.
FwKeysTooOld=Tus prod.keys son demasiado antiguas para este firmware (llegan hasta el firmware {0}).
KeysTitle=Claves
KeysNone=No hay prod.keys instaladas
KeysInstalled=prod.keys · {0} claves
KeysGen=Válidas hasta el firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} entradas
KeysInstall=Instalar prod.keys...
KeysDelete=Eliminar
KeysHint=También se copian title.keys y key_retail.bin de la misma carpeta.
KeysInvalid=El archivo seleccionado no parece un prod.keys.
KeysDone=Claves instaladas.
KeysAskDelete=¿Eliminar prod.keys y title.keys?\n\nLos archivos se moverán a la Papelera.
KeysDeleted=Claves eliminadas.
KeysMissingForFw=Sin prod.keys, Eden no puede usar el firmware.
NavSaves=Datos de juego
SavesInfo={0} partidas · {1} copias · caché de shaders {2}
SavesScanning=Buscando partidas y cachés de shaders...
SavesWorking=Espera un momento...
SavesBackupDir=Carpeta de copias
SavesShaderAll=Eliminar todas las cachés de shaders
SavesGameSave=Partida {0}
SavesGameNoSave=Sin partida
SavesGameShader=Shaders {0}
SavesGameBackups={0} copias
SavesSaveTitle=Partida guardada
SavesSaveInfo={0} · modificada {1}
SavesSaveNone=Aún no hay partida: Eden la crea la primera vez que guardas en el juego.
SavesBackupNow=Copiar ahora
SavesOpenFolder=Abrir carpeta
SavesShaderTitle=Caché de shaders
SavesShaderNone=Sin caché de shaders
SavesShaderDelete=Eliminar caché
SavesShaderHint=Ayuda con fallos gráficos tras una actualización de Eden. Eden reconstruye la caché mientras juegas (al principio con tirones breves).
SavesBackupsTitle=Copias de seguridad
SavesBackupsEmpty=Todavía no hay copias de este juego. Crea una con 'Copiar ahora'.
SavesRestore=Restaurar
SavesDelete=Eliminar
SavesReasonManual=Manual
SavesReasonAuto=Automática antes de actualizar Eden
SavesReasonRestore=Estado antes de restaurar
SavesBackupDone=Partida copiada: {0}
SavesNothing=Este juego no tiene partida que copiar.
SavesAskRestore=¿Restaurar la partida del {0}?\n\nAntes se hace una copia de la partida actual.
SavesRestored=Partida restaurada: {0}
SavesAskDelete=¿Eliminar la copia del {0}?\n\nEl archivo se moverá a la Papelera.
SavesDeleted=Copia eliminada: {0}
SavesAskShader=¿Eliminar la caché de shaders de '{0}' ({1})?
SavesAskShaderAll=¿Eliminar todas las cachés de shaders ({0})?\n\nEden las reconstruye mientras juegas.
SavesShaderDeleted=Caché de shaders eliminada: {0}
ChkSaveAuto=Copiar las partidas antes de cada actualización de Eden
WSavesBackup=Copiando partidas...
WSavesBacked=Partidas copiadas ({0} juegos con cambios).
'@
fr = @'
Name=Français
Culture=fr-FR
AppSubtitle=Mettre à jour vers la dernière nightly ou installer d'anciennes versions
SubNotes=Ce qui a changé dans la version choisie
SubGames=Lancez vos jeux directement avec Eden
SubMods=Gérer les mods de chaque jeu
SubContent=Gérer les mises à jour et DLC de chaque jeu
SubSaves=Copier les sauvegardes et vider le cache de shaders
SubFirmware=Firmware et clés pour Eden
SubSettings=Régler le programme de mise à jour et l'interface
SelfWaiting=La mise à jour du programme est téléchargée et sera installée dès que la tâche en cours sera terminée.
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
GamesContinue=Continuer à jouer
GamesLastPlayed=Dernière partie : {0}
GamesLaunches=lancé {0}×
GamesSortName=Par nom
GamesSortRecent=Joués récemment
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Marquer comme favori (afficher en haut)
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
NavContent=Mises à jour & DLC
NavFirmware=Firmware
SysEdenRunning=Eden est en cours d'exécution. Fermez Eden avant de modifier quoi que ce soit ici, sinon Eden écrasera les modifications en quittant.
ContentInfo={0} mises à jour · {1} DLC
ContentScanning=Recherche des mises à jour et DLC...
ContentCopying=Copie de {0}...
ContentAdd=Ajouter une mise à jour/DLC...
ContentFolder=Ouvrir le dossier
ContentDelete=Supprimer
ContentGameInfo={0} mises à jour · {1} DLC
ContentNone=Aucune mise à jour/DLC
ContentEmptyGame=Aucune mise à jour ni DLC pour ce jeu. Utilisez 'Ajouter une mise à jour/DLC...' pour ajouter un fichier NSP ou XCI.
ContentUpdate=Mise à jour {0}
ContentUpdateAny=Mise à jour
ContentDlc=DLC {0}
ContentUnknown=Mise à jour/DLC
ContentFromGameDir=du dossier de jeux
ContentFromNand=installé dans la NAND
ContentNandNoKeys=Les mises à jour/DLC installés dans la NAND ne peuvent pas être identifiés sans prod.keys (voir l'onglet Firmware).
ContentDlcAll=L'interrupteur s'applique à tous les DLC
ContentAskDelete=Supprimer '{0}' ?\n\nLe fichier sera placé dans la Corbeille.
ContentDeleted=Supprimé : {0}
ContentAdded=Ajouté : {0}
ContentOtherGame='{0}' appartient à un autre jeu (Title ID {1}) et y est affiché.
ContentToggledOn=Activé : {0}
ContentToggledOff=Désactivé : {0}
ContentRegistered=Dossier ajouté à Eden comme dossier de contenu externe : {0}
FwTitle=Firmware
FwNone=Aucun firmware installé
FwVersion=Firmware {0}
FwVersionUnknown=Firmware installé (version inconnue)
FwFiles={0} fichiers · {1}
FwInstallZip=Installer depuis un ZIP...
FwInstallDir=Depuis un dossier...
FwDelete=Supprimer
FwFolder=Ouvrir le dossier
FwHint=L'installation remplace le firmware actuel. En cas de problème, l'ancien firmware est conservé.
FwPreparing=Préparation du firmware...
FwInstalling=Installation du firmware... {0}/{1}
FwDone=Firmware installé ({0} fichiers).
FwNoNca=Aucun fichier .nca trouvé dans la sélection.
FwAskReplace=Un firmware est déjà installé ({0}). Le remplacer ?
FwAskDelete=Vraiment supprimer le firmware ?\n\nLes jeux qui en ont besoin ne démarreront plus.
FwDeleted=Firmware supprimé.
FwKeysTooOld=Vos prod.keys sont trop anciennes pour ce firmware (elles vont jusqu'au firmware {0}).
KeysTitle=Clés
KeysNone=Aucun prod.keys installé
KeysInstalled=prod.keys · {0} clés
KeysGen=Valables jusqu'au firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} entrées
KeysInstall=Installer prod.keys...
KeysDelete=Supprimer
KeysHint=title.keys et key_retail.bin du même dossier sont aussi copiés.
KeysInvalid=Le fichier choisi ne ressemble pas à un prod.keys.
KeysDone=Clés installées.
KeysAskDelete=Supprimer prod.keys et title.keys ?\n\nLes fichiers seront placés dans la Corbeille.
KeysDeleted=Clés supprimées.
KeysMissingForFw=Sans prod.keys, Eden ne peut pas utiliser le firmware.
NavSaves=Données de jeu
SavesInfo={0} sauvegardes · {1} copies · cache de shaders {2}
SavesScanning=Recherche des sauvegardes et caches de shaders...
SavesWorking=Veuillez patienter...
SavesBackupDir=Dossier des copies
SavesShaderAll=Supprimer tous les caches de shaders
SavesGameSave=Sauvegarde {0}
SavesGameNoSave=Aucune sauvegarde
SavesGameShader=Shaders {0}
SavesGameBackups={0} copies
SavesSaveTitle=Sauvegarde
SavesSaveInfo={0} · modifiée le {1}
SavesSaveNone=Pas encore de sauvegarde – Eden la crée la première fois que vous sauvegardez dans le jeu.
SavesBackupNow=Copier maintenant
SavesOpenFolder=Ouvrir le dossier
SavesShaderTitle=Cache de shaders
SavesShaderNone=Aucun cache de shaders
SavesShaderDelete=Supprimer le cache
SavesShaderHint=Aide en cas de problèmes graphiques après une mise à jour d'Eden. Eden reconstruit le cache en jouant (petites saccades au début).
SavesBackupsTitle=Copies
SavesBackupsEmpty=Pas encore de copie pour ce jeu. Utilisez 'Copier maintenant' pour en créer une.
SavesRestore=Restaurer
SavesDelete=Supprimer
SavesReasonManual=Manuelle
SavesReasonAuto=Automatique avant la mise à jour d'Eden
SavesReasonRestore=État avant restauration
SavesBackupDone=Sauvegarde copiée : {0}
SavesNothing=Ce jeu n'a pas de sauvegarde à copier.
SavesAskRestore=Restaurer la sauvegarde du {0} ?\n\nLa sauvegarde actuelle est copiée avant.
SavesRestored=Sauvegarde restaurée : {0}
SavesAskDelete=Supprimer la copie du {0} ?\n\nLe fichier sera placé dans la Corbeille.
SavesDeleted=Copie supprimée : {0}
SavesAskShader=Supprimer le cache de shaders de '{0}' ({1}) ?
SavesAskShaderAll=Supprimer tous les caches de shaders ({0}) ?\n\nEden les reconstruit en jouant.
SavesShaderDeleted=Cache de shaders supprimé : {0}
ChkSaveAuto=Copier les sauvegardes avant chaque mise à jour d'Eden
WSavesBackup=Copie des sauvegardes...
WSavesBacked=Sauvegardes copiées ({0} jeux modifiés).
'@
it = @'
Name=Italiano
Culture=it-IT
AppSubtitle=Aggiorna all'ultima nightly o installa versioni precedenti
SubNotes=Cosa è cambiato nella versione selezionata
SubGames=Avvia i tuoi giochi direttamente con Eden
SubMods=Gestisci le mod di ogni gioco
SubContent=Gestisci aggiornamenti e DLC di ogni gioco
SubSaves=Esegui il backup dei salvataggi e pulisci la cache shader
SubFirmware=Firmware e chiavi per Eden
SubSettings=Configura l'updater e l'interfaccia
SelfWaiting=L'aggiornamento dell'updater è scaricato e verrà installato al termine dell'operazione in corso.
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
GamesContinue=Continua a giocare
GamesLastPlayed=Ultima partita: {0}
GamesLaunches=avviato {0}×
GamesSortName=Per nome
GamesSortRecent=Giocati di recente
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Segna come preferito (mostra in alto)
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
NavContent=Aggiornamenti e DLC
NavFirmware=Firmware
SysEdenRunning=Eden è in esecuzione. Chiudi Eden prima di modificare qualcosa qui, altrimenti Eden sovrascrive le modifiche alla chiusura.
ContentInfo={0} aggiornamenti · {1} DLC
ContentScanning=Ricerca di aggiornamenti e DLC...
ContentCopying=Copia di {0}...
ContentAdd=Aggiungi aggiornamento/DLC...
ContentFolder=Apri cartella
ContentDelete=Elimina
ContentGameInfo={0} aggiornamenti · {1} DLC
ContentNone=Nessun aggiornamento/DLC
ContentEmptyGame=Nessun aggiornamento o DLC per questo gioco. Usa 'Aggiungi aggiornamento/DLC...' per aggiungere un file NSP o XCI.
ContentUpdate=Aggiornamento {0}
ContentUpdateAny=Aggiornamento
ContentDlc=DLC {0}
ContentUnknown=Aggiornamento/DLC
ContentFromGameDir=dalla cartella giochi
ContentFromNand=installato nella NAND
ContentNandNoKeys=Aggiornamenti/DLC installati nella NAND non possono essere riconosciuti senza prod.keys (vedi scheda Firmware).
ContentDlcAll=L'interruttore vale per tutti i DLC
ContentAskDelete=Eliminare '{0}'?\n\nIl file verrà spostato nel Cestino.
ContentDeleted=Eliminato: {0}
ContentAdded=Aggiunto: {0}
ContentOtherGame='{0}' appartiene a un altro gioco (Title ID {1}) e viene mostrato lì.
ContentToggledOn=Attivato: {0}
ContentToggledOff=Disattivato: {0}
ContentRegistered=Cartella aggiunta a Eden come cartella di contenuti esterni: {0}
FwTitle=Firmware
FwNone=Nessun firmware installato
FwVersion=Firmware {0}
FwVersionUnknown=Firmware installato (versione sconosciuta)
FwFiles={0} file · {1}
FwInstallZip=Installa da ZIP...
FwInstallDir=Da cartella...
FwDelete=Elimina
FwFolder=Apri cartella
FwHint=L'installazione sostituisce il firmware attuale. Se qualcosa va storto, il vecchio firmware viene mantenuto.
FwPreparing=Preparazione del firmware...
FwInstalling=Installazione firmware... {0}/{1}
FwDone=Firmware installato ({0} file).
FwNoNca=Nessun file .nca trovato nella selezione.
FwAskReplace=È già installato un firmware ({0}). Sostituirlo?
FwAskDelete=Eliminare davvero il firmware?\n\nI giochi che lo richiedono non si avvieranno più.
FwDeleted=Firmware eliminato.
FwKeysTooOld=Le tue prod.keys sono troppo vecchie per questo firmware (arrivano fino al firmware {0}).
KeysTitle=Chiavi
KeysNone=Nessun prod.keys installato
KeysInstalled=prod.keys · {0} chiavi
KeysGen=Valide fino al firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} voci
KeysInstall=Installa prod.keys...
KeysDelete=Elimina
KeysHint=Vengono copiati anche title.keys e key_retail.bin dalla stessa cartella.
KeysInvalid=Il file selezionato non sembra un prod.keys.
KeysDone=Chiavi installate.
KeysAskDelete=Eliminare prod.keys e title.keys?\n\nI file verranno spostati nel Cestino.
KeysDeleted=Chiavi eliminate.
KeysMissingForFw=Senza prod.keys Eden non può usare il firmware.
NavSaves=Dati di gioco
SavesInfo={0} salvataggi · {1} backup · cache shader {2}
SavesScanning=Ricerca di salvataggi e cache shader...
SavesWorking=Attendere...
SavesBackupDir=Cartella backup
SavesShaderAll=Elimina tutte le cache shader
SavesGameSave=Salvataggio {0}
SavesGameNoSave=Nessun salvataggio
SavesGameShader=Shader {0}
SavesGameBackups={0} backup
SavesSaveTitle=Salvataggio
SavesSaveInfo={0} · modificato {1}
SavesSaveNone=Ancora nessun salvataggio: Eden lo crea la prima volta che salvi nel gioco.
SavesBackupNow=Esegui backup
SavesOpenFolder=Apri cartella
SavesShaderTitle=Cache shader
SavesShaderNone=Nessuna cache shader
SavesShaderDelete=Elimina cache
SavesShaderHint=Aiuta con errori grafici dopo un aggiornamento di Eden. Eden ricrea la cache durante il gioco (all'inizio brevi scatti).
SavesBackupsTitle=Backup
SavesBackupsEmpty=Ancora nessun backup per questo gioco. Creane uno con 'Esegui backup'.
SavesRestore=Ripristina
SavesDelete=Elimina
SavesReasonManual=Manuale
SavesReasonAuto=Automatico prima dell'aggiornamento di Eden
SavesReasonRestore=Stato prima del ripristino
SavesBackupDone=Salvataggio copiato: {0}
SavesNothing=Questo gioco non ha un salvataggio da copiare.
SavesAskRestore=Ripristinare il salvataggio del {0}?\n\nPrima viene fatto un backup del salvataggio attuale.
SavesRestored=Salvataggio ripristinato: {0}
SavesAskDelete=Eliminare il backup del {0}?\n\nIl file verrà spostato nel Cestino.
SavesDeleted=Backup eliminato: {0}
SavesAskShader=Eliminare la cache shader di '{0}' ({1})?
SavesAskShaderAll=Eliminare tutte le cache shader ({0})?\n\nEden le ricrea durante il gioco.
SavesShaderDeleted=Cache shader eliminata: {0}
ChkSaveAuto=Esegui il backup dei salvataggi prima di ogni aggiornamento di Eden
WSavesBackup=Backup dei salvataggi...
WSavesBacked=Salvataggi copiati ({0} giochi con modifiche).
'@
pt = @'
Name=Português
Culture=pt-BR
AppSubtitle=Atualize para a nightly mais recente ou instale versões anteriores
SubNotes=O que mudou na versão selecionada
SubGames=Inicie seus jogos diretamente com o Eden
SubMods=Gerencie os mods de cada jogo
SubContent=Gerencie atualizações e DLCs de cada jogo
SubSaves=Faça backup dos saves e limpe o cache de shaders
SubFirmware=Firmware e chaves para o Eden
SubSettings=Configure o atualizador e a interface
SelfWaiting=A atualização do atualizador foi baixada e será instalada assim que a tarefa atual terminar.
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
GamesContinue=Continuar a jogar
GamesLastPlayed=Jogado pela última vez: {0}
GamesLaunches=iniciado {0}×
GamesSortName=Por nome
GamesSortRecent=Jogados recentemente
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Marcar como favorito (mostrar no topo)
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
NavContent=Atualizações e DLC
NavFirmware=Firmware
SysEdenRunning=O Eden está em execução. Feche o Eden antes de alterar algo aqui, senão o Eden sobrescreve as alterações ao sair.
ContentInfo={0} atualizações · {1} DLCs
ContentScanning=Procurando atualizações e DLCs...
ContentCopying=Copiando {0}...
ContentAdd=Adicionar atualização/DLC...
ContentFolder=Abrir pasta
ContentDelete=Excluir
ContentGameInfo={0} atualizações · {1} DLCs
ContentNone=Sem atualizações/DLCs
ContentEmptyGame=Não há atualizações nem DLCs para este jogo. Use 'Adicionar atualização/DLC...' para adicionar um arquivo NSP ou XCI.
ContentUpdate=Atualização {0}
ContentUpdateAny=Atualização
ContentDlc=DLC {0}
ContentUnknown=Atualização/DLC
ContentFromGameDir=da pasta de jogos
ContentFromNand=instalado na NAND
ContentNandNoKeys=Atualizações/DLCs instalados na NAND não podem ser identificados sem prod.keys (veja a aba Firmware).
ContentDlcAll=O botão vale para todos os DLCs
ContentAskDelete=Excluir '{0}'?\n\nO arquivo será movido para a Lixeira.
ContentDeleted=Excluído: {0}
ContentAdded=Adicionado: {0}
ContentOtherGame='{0}' pertence a outro jogo (Title ID {1}) e é mostrado lá.
ContentToggledOn=Ativado: {0}
ContentToggledOff=Desativado: {0}
ContentRegistered=Pasta adicionada ao Eden como pasta de conteúdo externo: {0}
FwTitle=Firmware
FwNone=Nenhum firmware instalado
FwVersion=Firmware {0}
FwVersionUnknown=Firmware instalado (versão desconhecida)
FwFiles={0} arquivos · {1}
FwInstallZip=Instalar de ZIP...
FwInstallDir=De pasta...
FwDelete=Excluir
FwFolder=Abrir pasta
FwHint=A instalação substitui o firmware atual. Se algo der errado, o firmware antigo é mantido.
FwPreparing=Preparando firmware...
FwInstalling=Instalando firmware... {0}/{1}
FwDone=Firmware instalado ({0} arquivos).
FwNoNca=Nenhum arquivo .nca encontrado na seleção.
FwAskReplace=Já existe firmware instalado ({0}). Substituir?
FwAskDelete=Excluir mesmo o firmware?\n\nJogos que precisam de firmware não vão mais iniciar.
FwDeleted=Firmware excluído.
FwKeysTooOld=Suas prod.keys são antigas demais para este firmware (vão até o firmware {0}).
KeysTitle=Chaves
KeysNone=Nenhum prod.keys instalado
KeysInstalled=prod.keys · {0} chaves
KeysGen=Válidas até o firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} entradas
KeysInstall=Instalar prod.keys...
KeysDelete=Excluir
KeysHint=title.keys e key_retail.bin da mesma pasta também são copiados.
KeysInvalid=O arquivo escolhido não parece um prod.keys.
KeysDone=Chaves instaladas.
KeysAskDelete=Excluir prod.keys e title.keys?\n\nOs arquivos serão movidos para a Lixeira.
KeysDeleted=Chaves excluídas.
KeysMissingForFw=Sem prod.keys o Eden não consegue usar o firmware.
NavSaves=Dados de jogo
SavesInfo={0} saves · {1} backups · cache de shaders {2}
SavesScanning=Procurando saves e caches de shaders...
SavesWorking=Aguarde...
SavesBackupDir=Pasta de backups
SavesShaderAll=Excluir todos os caches de shaders
SavesGameSave=Save {0}
SavesGameNoSave=Sem save
SavesGameShader=Shaders {0}
SavesGameBackups={0} backups
SavesSaveTitle=Save
SavesSaveInfo={0} · alterado {1}
SavesSaveNone=Ainda não há save – o Eden o cria na primeira vez que você salva no jogo.
SavesBackupNow=Fazer backup agora
SavesOpenFolder=Abrir pasta
SavesShaderTitle=Cache de shaders
SavesShaderNone=Sem cache de shaders
SavesShaderDelete=Excluir cache
SavesShaderHint=Ajuda com falhas gráficas após uma atualização do Eden. O Eden recria o cache enquanto você joga (no início com breves travadas).
SavesBackupsTitle=Backups
SavesBackupsEmpty=Ainda não há backups deste jogo. Crie um com 'Fazer backup agora'.
SavesRestore=Restaurar
SavesDelete=Excluir
SavesReasonManual=Manual
SavesReasonAuto=Automático antes da atualização do Eden
SavesReasonRestore=Estado antes de restaurar
SavesBackupDone=Save copiado: {0}
SavesNothing=Este jogo não tem save para copiar.
SavesAskRestore=Restaurar o save de {0}?\n\nAntes é feito um backup do save atual.
SavesRestored=Save restaurado: {0}
SavesAskDelete=Excluir o backup de {0}?\n\nO arquivo será movido para a Lixeira.
SavesDeleted=Backup excluído: {0}
SavesAskShader=Excluir o cache de shaders de '{0}' ({1})?
SavesAskShaderAll=Excluir todos os caches de shaders ({0})?\n\nO Eden os recria enquanto você joga.
SavesShaderDeleted=Cache de shaders excluído: {0}
ChkSaveAuto=Fazer backup dos saves antes de cada atualização do Eden
WSavesBackup=Fazendo backup dos saves...
WSavesBacked=Saves copiados ({0} jogos com alterações).
'@
nl = @'
Name=Nederlands
Culture=nl-NL
AppSubtitle=Bijwerken naar de nieuwste nightly of oudere versies installeren
SubNotes=Wat er in de gekozen versie is veranderd
SubGames=Start je games direct met Eden
SubMods=Mods per game beheren
SubContent=Updates en DLC's per game beheren
SubSaves=Saves back-uppen en de shadercache opruimen
SubFirmware=Firmware en sleutels voor Eden
SubSettings=Updater en interface instellen
SelfWaiting=De update van de updater is gedownload en wordt geïnstalleerd zodra de huidige taak klaar is.
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
GamesContinue=Verder spelen
GamesLastPlayed=Laatst gespeeld: {0}
GamesLaunches={0}× gestart
GamesSortName=Op naam
GamesSortRecent=Recent gespeeld
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Als favoriet markeren (bovenaan tonen)
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
NavContent=Updates & DLC
NavFirmware=Firmware
SysEdenRunning=Eden is actief. Sluit Eden voordat je hier iets wijzigt, anders overschrijft Eden de wijzigingen bij het afsluiten.
ContentInfo={0} updates · {1} DLC's
ContentScanning=Zoeken naar updates en DLC's...
ContentCopying={0} kopiëren...
ContentAdd=Update/DLC toevoegen...
ContentFolder=Map openen
ContentDelete=Verwijderen
ContentGameInfo={0} updates · {1} DLC's
ContentNone=Geen updates/DLC's
ContentEmptyGame=Geen updates of DLC's voor deze game. Gebruik 'Update/DLC toevoegen...' om een NSP- of XCI-bestand toe te voegen.
ContentUpdate=Update {0}
ContentUpdateAny=Update
ContentDlc=DLC {0}
ContentUnknown=Update/DLC
ContentFromGameDir=uit de gamemap
ContentFromNand=geïnstalleerd in NAND
ContentNandNoKeys=In NAND geïnstalleerde updates/DLC's kunnen zonder prod.keys niet worden herkend (zie tabblad Firmware).
ContentDlcAll=Schakelaar geldt voor alle DLC's
ContentAskDelete='{0}' verwijderen?\n\nHet bestand wordt naar de Prullenbak verplaatst.
ContentDeleted=Verwijderd: {0}
ContentAdded=Toegevoegd: {0}
ContentOtherGame='{0}' hoort bij een andere game (Title ID {1}) en wordt daar getoond.
ContentToggledOn=Ingeschakeld: {0}
ContentToggledOff=Uitgeschakeld: {0}
ContentRegistered=Map aan Eden toegevoegd als externe inhoudsmap: {0}
FwTitle=Firmware
FwNone=Geen firmware geïnstalleerd
FwVersion=Firmware {0}
FwVersionUnknown=Firmware geïnstalleerd (versie onbekend)
FwFiles={0} bestanden · {1}
FwInstallZip=Installeren uit ZIP...
FwInstallDir=Uit map...
FwDelete=Verwijderen
FwFolder=Map openen
FwHint=Installeren vervangt de huidige firmware. Gaat er iets mis, dan blijft de oude firmware behouden.
FwPreparing=Firmware voorbereiden...
FwInstalling=Firmware installeren... {0}/{1}
FwDone=Firmware geïnstalleerd ({0} bestanden).
FwNoNca=Geen .nca-bestanden gevonden in de selectie.
FwAskReplace=Er is al firmware geïnstalleerd ({0}). Vervangen?
FwAskDelete=Firmware echt verwijderen?\n\nGames die firmware nodig hebben, starten dan niet meer.
FwDeleted=Firmware verwijderd.
FwKeysTooOld=Je prod.keys zijn te oud voor deze firmware (ze gaan tot firmware {0}).
KeysTitle=Sleutels
KeysNone=Geen prod.keys geïnstalleerd
KeysInstalled=prod.keys · {0} sleutels
KeysGen=Geldig tot firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} items
KeysInstall=prod.keys installeren...
KeysDelete=Verwijderen
KeysHint=title.keys en key_retail.bin uit dezelfde map worden ook gekopieerd.
KeysInvalid=Het gekozen bestand lijkt geen prod.keys te zijn.
KeysDone=Sleutels geïnstalleerd.
KeysAskDelete=prod.keys en title.keys verwijderen?\n\nDe bestanden worden naar de Prullenbak verplaatst.
KeysDeleted=Sleutels verwijderd.
KeysMissingForFw=Zonder prod.keys kan Eden de firmware niet gebruiken.
NavSaves=Gamedata
SavesInfo={0} saves · {1} back-ups · shadercache {2}
SavesScanning=Zoeken naar saves en shadercaches...
SavesWorking=Even geduld...
SavesBackupDir=Back-upmap
SavesShaderAll=Alle shadercaches verwijderen
SavesGameSave=Save {0}
SavesGameNoSave=Geen save
SavesGameShader=Shaders {0}
SavesGameBackups={0} back-ups
SavesSaveTitle=Save
SavesSaveInfo={0} · gewijzigd {1}
SavesSaveNone=Nog geen save – Eden maakt die aan zodra je in de game opslaat.
SavesBackupNow=Nu back-up maken
SavesOpenFolder=Map openen
SavesShaderTitle=Shadercache
SavesShaderNone=Geen shadercache
SavesShaderDelete=Cache verwijderen
SavesShaderHint=Helpt bij grafische fouten na een Eden-update. Eden bouwt de cache tijdens het spelen opnieuw op (in het begin korte haperingen).
SavesBackupsTitle=Back-ups
SavesBackupsEmpty=Nog geen back-ups voor deze game. Maak er een met 'Nu back-up maken'.
SavesRestore=Herstellen
SavesDelete=Verwijderen
SavesReasonManual=Handmatig
SavesReasonAuto=Automatisch vóór Eden-update
SavesReasonRestore=Stand vóór het herstellen
SavesBackupDone=Save geback-upt: {0}
SavesNothing=Deze game heeft geen save om te back-uppen.
SavesAskRestore=Save van {0} herstellen?\n\nVan de huidige save wordt eerst een back-up gemaakt.
SavesRestored=Save hersteld: {0}
SavesAskDelete=Back-up van {0} verwijderen?\n\nHet bestand wordt naar de Prullenbak verplaatst.
SavesDeleted=Back-up verwijderd: {0}
SavesAskShader=Shadercache van '{0}' verwijderen ({1})?
SavesAskShaderAll=Alle shadercaches verwijderen ({0})?\n\nEden bouwt ze tijdens het spelen opnieuw op.
SavesShaderDeleted=Shadercache verwijderd: {0}
ChkSaveAuto=Saves back-uppen vóór elke Eden-update
WSavesBackup=Saves back-uppen...
WSavesBacked=Saves geback-upt ({0} games met wijzigingen).
'@
pl = @'
Name=Polski
Culture=pl-PL
AppSubtitle=Aktualizuj do najnowszej wersji nightly lub instaluj starsze wersje
SubNotes=Co zmieniło się w wybranej wersji
SubGames=Uruchamiaj gry bezpośrednio w Edenie
SubMods=Zarządzaj modami każdej gry
SubContent=Zarządzaj aktualizacjami i DLC każdej gry
SubSaves=Twórz kopie zapisów i czyść cache shaderów
SubFirmware=Firmware i klucze dla Edena
SubSettings=Ustawienia aktualizatora i interfejsu
SelfWaiting=Aktualizacja aktualizatora jest pobrana i zostanie zainstalowana po zakończeniu bieżącego zadania.
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
GamesContinue=Graj dalej
GamesLastPlayed=Ostatnio grane: {0}
GamesLaunches=uruchomiono {0}×
GamesSortName=Według nazwy
GamesSortRecent=Ostatnio grane
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Oznacz jako ulubioną (pokaż na górze)
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
NavContent=Aktualizacje i DLC
NavFirmware=Firmware
SysEdenRunning=Eden jest uruchomiony. Zamknij Eden, zanim coś tu zmienisz, inaczej Eden nadpisze zmiany przy zamykaniu.
ContentInfo=Aktualizacje: {0} · DLC: {1}
ContentScanning=Wyszukiwanie aktualizacji i DLC...
ContentCopying=Kopiowanie {0}...
ContentAdd=Dodaj aktualizację/DLC...
ContentFolder=Otwórz folder
ContentDelete=Usuń
ContentGameInfo=Aktualizacje: {0} · DLC: {1}
ContentNone=Brak aktualizacji/DLC
ContentEmptyGame=Brak aktualizacji i DLC dla tej gry. Użyj 'Dodaj aktualizację/DLC...', aby dodać plik NSP lub XCI.
ContentUpdate=Aktualizacja {0}
ContentUpdateAny=Aktualizacja
ContentDlc=DLC {0}
ContentUnknown=Aktualizacja/DLC
ContentFromGameDir=z folderu gier
ContentFromNand=zainstalowane w NAND
ContentNandNoKeys=Aktualizacji/DLC zainstalowanych w NAND nie da się rozpoznać bez prod.keys (zobacz kartę Firmware).
ContentDlcAll=Przełącznik dotyczy wszystkich DLC
ContentAskDelete=Usunąć '{0}'?\n\nPlik zostanie przeniesiony do Kosza.
ContentDeleted=Usunięto: {0}
ContentAdded=Dodano: {0}
ContentOtherGame='{0}' należy do innej gry (Title ID {1}) i jest tam wyświetlany.
ContentToggledOn=Włączono: {0}
ContentToggledOff=Wyłączono: {0}
ContentRegistered=Folder dodany do Eden jako folder zawartości zewnętrznej: {0}
FwTitle=Firmware
FwNone=Brak zainstalowanego firmware
FwVersion=Firmware {0}
FwVersionUnknown=Firmware zainstalowany (wersja nieznana)
FwFiles=Pliki: {0} · {1}
FwInstallZip=Zainstaluj z ZIP...
FwInstallDir=Z folderu...
FwDelete=Usuń
FwFolder=Otwórz folder
FwHint=Instalacja zastępuje obecny firmware. Jeśli coś pójdzie nie tak, stary firmware zostaje zachowany.
FwPreparing=Przygotowywanie firmware...
FwInstalling=Instalowanie firmware... {0}/{1}
FwDone=Firmware zainstalowany (pliki: {0}).
FwNoNca=W wyborze nie znaleziono plików .nca.
FwAskReplace=Firmware jest już zainstalowany ({0}). Zastąpić?
FwAskDelete=Na pewno usunąć firmware?\n\nGry wymagające firmware przestaną się uruchamiać.
FwDeleted=Firmware usunięty.
FwKeysTooOld=Twoje prod.keys są za stare dla tego firmware (obejmują do firmware {0}).
KeysTitle=Klucze
KeysNone=Brak zainstalowanego prod.keys
KeysInstalled=prod.keys · kluczy: {0}
KeysGen=Obejmują do firmware {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · wpisów: {0}
KeysInstall=Zainstaluj prod.keys...
KeysDelete=Usuń
KeysHint=title.keys i key_retail.bin z tego samego folderu też są kopiowane.
KeysInvalid=Wybrany plik nie wygląda na prod.keys.
KeysDone=Klucze zainstalowane.
KeysAskDelete=Usunąć prod.keys i title.keys?\n\nPliki zostaną przeniesione do Kosza.
KeysDeleted=Klucze usunięte.
KeysMissingForFw=Bez prod.keys Eden nie może użyć firmware.
NavSaves=Dane gier
SavesInfo=Zapisy: {0} · kopie: {1} · cache shaderów {2}
SavesScanning=Wyszukiwanie zapisów i cache shaderów...
SavesWorking=Proszę czekać...
SavesBackupDir=Folder kopii
SavesShaderAll=Usuń wszystkie cache shaderów
SavesGameSave=Zapis {0}
SavesGameNoSave=Brak zapisu
SavesGameShader=Shadery {0}
SavesGameBackups=Kopie: {0}
SavesSaveTitle=Zapis gry
SavesSaveInfo={0} · zmieniono {1}
SavesSaveNone=Brak zapisu – Eden utworzy go przy pierwszym zapisie w grze.
SavesBackupNow=Utwórz kopię
SavesOpenFolder=Otwórz folder
SavesShaderTitle=Cache shaderów
SavesShaderNone=Brak cache shaderów
SavesShaderDelete=Usuń cache
SavesShaderHint=Pomaga przy błędach grafiki po aktualizacji Edena. Eden odbuduje cache podczas gry (na początku krótkie przycięcia).
SavesBackupsTitle=Kopie zapasowe
SavesBackupsEmpty=Brak kopii dla tej gry. Utwórz ją przyciskiem 'Utwórz kopię'.
SavesRestore=Przywróć
SavesDelete=Usuń
SavesReasonManual=Ręczna
SavesReasonAuto=Automatyczna przed aktualizacją Edena
SavesReasonRestore=Stan przed przywróceniem
SavesBackupDone=Zapis skopiowany: {0}
SavesNothing=Ta gra nie ma zapisu do skopiowania.
SavesAskRestore=Przywrócić zapis z {0}?\n\nNajpierw zostanie utworzona kopia obecnego zapisu.
SavesRestored=Zapis przywrócony: {0}
SavesAskDelete=Usunąć kopię z {0}?\n\nPlik zostanie przeniesiony do Kosza.
SavesDeleted=Kopia usunięta: {0}
SavesAskShader=Usunąć cache shaderów gry '{0}' ({1})?
SavesAskShaderAll=Usunąć wszystkie cache shaderów ({0})?\n\nEden odbuduje je podczas gry.
SavesShaderDeleted=Cache shaderów usunięty: {0}
ChkSaveAuto=Twórz kopię zapisów przed każdą aktualizacją Edena
WSavesBackup=Kopiowanie zapisów...
WSavesBacked=Zapisy skopiowane (gry ze zmianami: {0}).
'@
tr = @'
Name=Türkçe
Culture=tr-TR
AppSubtitle=En yeni nightly sürümüne güncelleyin veya eski sürümleri yükleyin
SubNotes=Seçilen sürümde neler değişti
SubGames=Oyunlarınızı doğrudan Eden ile başlatın
SubMods=Her oyunun modlarını yönetin
SubContent=Her oyunun güncellemelerini ve DLC'lerini yönetin
SubSaves=Kayıtları yedekleyin ve shader önbelleğini temizleyin
SubFirmware=Eden için firmware ve anahtarlar
SubSettings=Güncelleyiciyi ve arayüzü ayarlayın
SelfWaiting=Güncelleyici güncellemesi indirildi; mevcut işlem bitince yüklenecek.
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
GamesContinue=Oynamaya devam et
GamesLastPlayed=Son oynama: {0}
GamesLaunches={0} kez başlatıldı
GamesSortName=Ada göre
GamesSortRecent=Son oynananlar
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Favori olarak işaretle (en üstte göster)
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
NavContent=Güncellemeler ve DLC
NavFirmware=Firmware
SysEdenRunning=Eden çalışıyor. Burada bir şey değiştirmeden önce Eden'i kapatın, aksi halde Eden çıkarken değişikliklerin üzerine yazar.
ContentInfo={0} güncelleme · {1} DLC
ContentScanning=Güncellemeler ve DLC'ler aranıyor...
ContentCopying={0} kopyalanıyor...
ContentAdd=Güncelleme/DLC ekle...
ContentFolder=Klasörü aç
ContentDelete=Sil
ContentGameInfo={0} güncelleme · {1} DLC
ContentNone=Güncelleme/DLC yok
ContentEmptyGame=Bu oyun için güncelleme veya DLC yok. NSP ya da XCI dosyası eklemek için 'Güncelleme/DLC ekle...' kullanın.
ContentUpdate=Güncelleme {0}
ContentUpdateAny=Güncelleme
ContentDlc=DLC {0}
ContentUnknown=Güncelleme/DLC
ContentFromGameDir=oyun klasöründen
ContentFromNand=NAND'e yüklü
ContentNandNoKeys=NAND'e yüklü güncellemeler/DLC'ler prod.keys olmadan tanınamaz (Firmware sekmesine bakın).
ContentDlcAll=Anahtar tüm DLC'ler için geçerli
ContentAskDelete='{0}' silinsin mi?\n\nDosya Geri Dönüşüm Kutusu'na taşınacak.
ContentDeleted=Silindi: {0}
ContentAdded=Eklendi: {0}
ContentOtherGame='{0}' başka bir oyuna ait (Title ID {1}) ve orada gösteriliyor.
ContentToggledOn=Etkinleştirildi: {0}
ContentToggledOff=Devre dışı bırakıldı: {0}
ContentRegistered=Klasör Eden'e harici içerik klasörü olarak eklendi: {0}
FwTitle=Firmware
FwNone=Yüklü firmware yok
FwVersion=Firmware {0}
FwVersionUnknown=Firmware yüklü (sürüm bilinmiyor)
FwFiles={0} dosya · {1}
FwInstallZip=ZIP'ten yükle...
FwInstallDir=Klasörden...
FwDelete=Sil
FwFolder=Klasörü aç
FwHint=Yükleme mevcut firmware'i değiştirir. Bir sorun olursa eski firmware korunur.
FwPreparing=Firmware hazırlanıyor...
FwInstalling=Firmware yükleniyor... {0}/{1}
FwDone=Firmware yüklendi ({0} dosya).
FwNoNca=Seçimde .nca dosyası bulunamadı.
FwAskReplace=Zaten firmware yüklü ({0}). Değiştirilsin mi?
FwAskDelete=Firmware gerçekten silinsin mi?\n\nFirmware gerektiren oyunlar artık başlamaz.
FwDeleted=Firmware silindi.
FwKeysTooOld=prod.keys dosyanız bu firmware için çok eski (firmware {0} sürümüne kadar yetiyor).
KeysTitle=Anahtarlar
KeysNone=Yüklü prod.keys yok
KeysInstalled=prod.keys · {0} anahtar
KeysGen=Firmware {1} sürümüne kadar (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} kayıt
KeysInstall=prod.keys yükle...
KeysDelete=Sil
KeysHint=Aynı klasördeki title.keys ve key_retail.bin de kopyalanır.
KeysInvalid=Seçilen dosya bir prod.keys gibi görünmüyor.
KeysDone=Anahtarlar yüklendi.
KeysAskDelete=prod.keys ve title.keys silinsin mi?\n\nDosyalar Geri Dönüşüm Kutusu'na taşınacak.
KeysDeleted=Anahtarlar silindi.
KeysMissingForFw=prod.keys olmadan Eden firmware'i kullanamaz.
NavSaves=Oyun verileri
SavesInfo={0} kayıt · {1} yedek · shader önbelleği {2}
SavesScanning=Kayıtlar ve shader önbellekleri aranıyor...
SavesWorking=Lütfen bekleyin...
SavesBackupDir=Yedek klasörü
SavesShaderAll=Tüm shader önbelleklerini sil
SavesGameSave=Kayıt {0}
SavesGameNoSave=Kayıt yok
SavesGameShader=Shader {0}
SavesGameBackups={0} yedek
SavesSaveTitle=Oyun kaydı
SavesSaveInfo={0} · değiştirildi {1}
SavesSaveNone=Henüz kayıt yok – Eden, oyunda ilk kez kaydettiğinizde oluşturur.
SavesBackupNow=Şimdi yedekle
SavesOpenFolder=Klasörü aç
SavesShaderTitle=Shader önbelleği
SavesShaderNone=Shader önbelleği yok
SavesShaderDelete=Önbelleği sil
SavesShaderHint=Eden güncellemesinden sonraki grafik hatalarına yardımcı olur. Eden önbelleği oynarken yeniden oluşturur (başta kısa takılmalar).
SavesBackupsTitle=Yedekler
SavesBackupsEmpty=Bu oyun için henüz yedek yok. 'Şimdi yedekle' ile bir tane oluşturun.
SavesRestore=Geri yükle
SavesDelete=Sil
SavesReasonManual=Elle
SavesReasonAuto=Eden güncellemesinden önce otomatik
SavesReasonRestore=Geri yüklemeden önceki durum
SavesBackupDone=Kayıt yedeklendi: {0}
SavesNothing=Bu oyunun yedeklenecek kaydı yok.
SavesAskRestore={0} tarihli kayıt geri yüklensin mi?\n\nMevcut kaydın önce yedeği alınır.
SavesRestored=Kayıt geri yüklendi: {0}
SavesAskDelete={0} tarihli yedek silinsin mi?\n\nDosya Geri Dönüşüm Kutusu'na taşınacak.
SavesDeleted=Yedek silindi: {0}
SavesAskShader='{0}' shader önbelleği silinsin mi ({1})?
SavesAskShaderAll=Tüm shader önbellekleri silinsin mi ({0})?\n\nEden bunları oynarken yeniden oluşturur.
SavesShaderDeleted=Shader önbelleği silindi: {0}
ChkSaveAuto=Her Eden güncellemesinden önce kayıtları yedekle
WSavesBackup=Kayıtlar yedekleniyor...
WSavesBacked=Kayıtlar yedeklendi (değişikliği olan {0} oyun).
'@
ru = @'
Name=Русский
Culture=ru-RU
AppSubtitle=Обновление до последней nightly-сборки или установка старых версий
SubNotes=Что изменилось в выбранной версии
SubGames=Запускайте игры прямо через Eden
SubMods=Управление модами для каждой игры
SubContent=Управление обновлениями и DLC для каждой игры
SubSaves=Копии сохранений и очистка кэша шейдеров
SubFirmware=Прошивка и ключи для Eden
SubSettings=Настройки программы и интерфейса
SelfWaiting=Обновление программы загружено и будет установлено, как только завершится текущая операция.
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
GamesContinue=Продолжить игру
GamesLastPlayed=Последний запуск: {0}
GamesLaunches=запусков: {0}
GamesSortName=По названию
GamesSortRecent=Недавно запущенные
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=Добавить в избранное (показывать сверху)
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
NavContent=Обновления и DLC
NavFirmware=Прошивка
SysEdenRunning=Eden запущен. Закройте Eden, прежде чем что-то менять здесь, иначе Eden перезапишет изменения при выходе.
ContentInfo=Обновлений: {0} · DLC: {1}
ContentScanning=Поиск обновлений и DLC...
ContentCopying=Копирование {0}...
ContentAdd=Добавить обновление/DLC...
ContentFolder=Открыть папку
ContentDelete=Удалить
ContentGameInfo=Обновлений: {0} · DLC: {1}
ContentNone=Нет обновлений/DLC
ContentEmptyGame=Для этой игры нет обновлений и DLC. Нажмите «Добавить обновление/DLC...», чтобы добавить файл NSP или XCI.
ContentUpdate=Обновление {0}
ContentUpdateAny=Обновление
ContentDlc=DLC {0}
ContentUnknown=Обновление/DLC
ContentFromGameDir=из папки с играми
ContentFromNand=установлено в NAND
ContentNandNoKeys=Обновления/DLC, установленные в NAND, нельзя распознать без prod.keys (см. вкладку «Прошивка»).
ContentDlcAll=Переключатель действует на все DLC
ContentAskDelete=Удалить «{0}»?\n\nФайл будет перемещён в корзину.
ContentDeleted=Удалено: {0}
ContentAdded=Добавлено: {0}
ContentOtherGame=«{0}» относится к другой игре (Title ID {1}) и показывается там.
ContentToggledOn=Включено: {0}
ContentToggledOff=Выключено: {0}
ContentRegistered=Папка добавлена в Eden как папка внешнего контента: {0}
FwTitle=Прошивка
FwNone=Прошивка не установлена
FwVersion=Прошивка {0}
FwVersionUnknown=Прошивка установлена (версия неизвестна)
FwFiles=Файлов: {0} · {1}
FwInstallZip=Установить из ZIP...
FwInstallDir=Из папки...
FwDelete=Удалить
FwFolder=Открыть папку
FwHint=Установка заменяет текущую прошивку. Если что-то пойдёт не так, старая прошивка сохранится.
FwPreparing=Подготовка прошивки...
FwInstalling=Установка прошивки... {0}/{1}
FwDone=Прошивка установлена (файлов: {0}).
FwNoNca=В выбранном не найдено файлов .nca.
FwAskReplace=Прошивка уже установлена ({0}). Заменить?
FwAskDelete=Точно удалить прошивку?\n\nИгры, которым нужна прошивка, перестанут запускаться.
FwDeleted=Прошивка удалена.
FwKeysTooOld=Ваши prod.keys слишком старые для этой прошивки (подходят до прошивки {0}).
KeysTitle=Ключи
KeysNone=prod.keys не установлены
KeysInstalled=prod.keys · ключей: {0}
KeysGen=Подходят до прошивки {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · записей: {0}
KeysInstall=Установить prod.keys...
KeysDelete=Удалить
KeysHint=title.keys и key_retail.bin из той же папки тоже копируются.
KeysInvalid=Выбранный файл не похож на prod.keys.
KeysDone=Ключи установлены.
KeysAskDelete=Удалить prod.keys и title.keys?\n\nФайлы будут перемещены в корзину.
KeysDeleted=Ключи удалены.
KeysMissingForFw=Без prod.keys Eden не сможет использовать прошивку.
NavSaves=Данные игр
SavesInfo=Сохранений: {0} · копий: {1} · кэш шейдеров {2}
SavesScanning=Поиск сохранений и кэша шейдеров...
SavesWorking=Подождите...
SavesBackupDir=Папка копий
SavesShaderAll=Удалить весь кэш шейдеров
SavesGameSave=Сохранение {0}
SavesGameNoSave=Нет сохранения
SavesGameShader=Шейдеры {0}
SavesGameBackups=Копий: {0}
SavesSaveTitle=Сохранение
SavesSaveInfo={0} · изменено {1}
SavesSaveNone=Сохранения пока нет — Eden создаст его при первом сохранении в игре.
SavesBackupNow=Создать копию
SavesOpenFolder=Открыть папку
SavesShaderTitle=Кэш шейдеров
SavesShaderNone=Нет кэша шейдеров
SavesShaderDelete=Удалить кэш
SavesShaderHint=Помогает при графических ошибках после обновления Eden. Eden заново создаёт кэш во время игры (сначала возможны подтормаживания).
SavesBackupsTitle=Резервные копии
SavesBackupsEmpty=Для этой игры ещё нет копий. Создайте её кнопкой «Создать копию».
SavesRestore=Восстановить
SavesDelete=Удалить
SavesReasonManual=Вручную
SavesReasonAuto=Автоматически перед обновлением Eden
SavesReasonRestore=Состояние перед восстановлением
SavesBackupDone=Сохранение скопировано: {0}
SavesNothing=У этой игры нет сохранения для копирования.
SavesAskRestore=Восстановить сохранение от {0}?\n\nПеред этим будет создана копия текущего сохранения.
SavesRestored=Сохранение восстановлено: {0}
SavesAskDelete=Удалить копию от {0}?\n\nФайл будет перемещён в корзину.
SavesDeleted=Копия удалена: {0}
SavesAskShader=Удалить кэш шейдеров «{0}» ({1})?
SavesAskShaderAll=Удалить весь кэш шейдеров ({0})?\n\nEden создаст его заново во время игры.
SavesShaderDeleted=Кэш шейдеров удалён: {0}
ChkSaveAuto=Копировать сохранения перед каждым обновлением Eden
WSavesBackup=Копирование сохранений...
WSavesBacked=Сохранения скопированы (игр с изменениями: {0}).
'@
ja = @'
Name=日本語
Culture=ja-JP
AppSubtitle=最新のNightlyビルドに更新、または旧バージョンをインストール
SubNotes=選択したバージョンの変更点
SubGames=ゲームをEdenで直接起動
SubMods=ゲームごとにModを管理
SubContent=ゲームごとにアップデートとDLCを管理
SubSaves=セーブのバックアップとシェーダーキャッシュの整理
SubFirmware=Eden用のファームウェアとキー
SubSettings=アップデーターと画面の設定
SelfWaiting=アップデーターの更新はダウンロード済みです。実行中の処理が終わり次第インストールされます。
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
GamesContinue=続きをプレイ
GamesLastPlayed=最終プレイ: {0}
GamesLaunches=起動 {0} 回
GamesSortName=名前順
GamesSortRecent=最近プレイした順
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=お気に入りに追加 (上部に表示)
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
NavContent=アップデートとDLC
NavFirmware=ファームウェア
SysEdenRunning=Edenが実行中です。ここで変更する前にEdenを閉じてください。そうしないと、Eden終了時に変更が上書きされます。
ContentInfo=アップデート {0} 件 · DLC {1} 件
ContentScanning=アップデートとDLCを検索中...
ContentCopying={0} をコピー中...
ContentAdd=アップデート/DLCを追加...
ContentFolder=フォルダーを開く
ContentDelete=削除
ContentGameInfo=アップデート {0} 件 · DLC {1} 件
ContentNone=アップデート/DLCなし
ContentEmptyGame=このゲームのアップデートやDLCはありません。「アップデート/DLCを追加...」でNSPまたはXCIファイルを追加してください。
ContentUpdate=アップデート {0}
ContentUpdateAny=アップデート
ContentDlc=DLC {0}
ContentUnknown=アップデート/DLC
ContentFromGameDir=ゲームフォルダーから
ContentFromNand=NANDにインストール済み
ContentNandNoKeys=NANDにインストールされたアップデート/DLCは prod.keys がないと識別できません (ファームウェアタブを参照)。
ContentDlcAll=スイッチはすべてのDLCに適用されます
ContentAskDelete='{0}' を削除しますか?\n\nファイルはごみ箱に移動されます。
ContentDeleted=削除しました: {0}
ContentAdded=追加しました: {0}
ContentOtherGame='{0}' は別のゲーム (Title ID {1}) のもので、そちらに表示されます。
ContentToggledOn=有効化: {0}
ContentToggledOff=無効化: {0}
ContentRegistered=フォルダーをEdenの外部コンテンツフォルダーとして登録しました: {0}
FwTitle=ファームウェア
FwNone=ファームウェアがインストールされていません
FwVersion=ファームウェア {0}
FwVersionUnknown=ファームウェアあり (バージョン不明)
FwFiles={0} ファイル · {1}
FwInstallZip=ZIPからインストール...
FwInstallDir=フォルダーから...
FwDelete=削除
FwFolder=フォルダーを開く
FwHint=インストールすると現在のファームウェアが置き換えられます。失敗した場合は古いファームウェアが残ります。
FwPreparing=ファームウェアを準備中...
FwInstalling=ファームウェアをインストール中... {0}/{1}
FwDone=ファームウェアをインストールしました ({0} ファイル)。
FwNoNca=選択した中に .nca ファイルが見つかりません。
FwAskReplace=ファームウェアは既にインストールされています ({0})。置き換えますか?
FwAskDelete=ファームウェアを削除しますか?\n\nファームウェアが必要なゲームは起動しなくなります。
FwDeleted=ファームウェアを削除しました。
FwKeysTooOld=prod.keys がこのファームウェアには古すぎます (ファームウェア {0} まで対応)。
KeysTitle=キー
KeysNone=prod.keys がインストールされていません
KeysInstalled=prod.keys · {0} 個のキー
KeysGen=ファームウェア {1} まで対応 (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} 件
KeysInstall=prod.keys をインストール...
KeysDelete=削除
KeysHint=同じフォルダーの title.keys と key_retail.bin もコピーされます。
KeysInvalid=選択したファイルは prod.keys ではないようです。
KeysDone=キーをインストールしました。
KeysAskDelete=prod.keys と title.keys を削除しますか?\n\nファイルはごみ箱に移動されます。
KeysDeleted=キーを削除しました。
KeysMissingForFw=prod.keys がないとEdenはファームウェアを使用できません。
NavSaves=ゲームデータ
SavesInfo=セーブ {0} 件 · バックアップ {1} 件 · シェーダーキャッシュ {2}
SavesScanning=セーブとシェーダーキャッシュを検索中...
SavesWorking=お待ちください...
SavesBackupDir=バックアップフォルダー
SavesShaderAll=すべてのシェーダーキャッシュを削除
SavesGameSave=セーブ {0}
SavesGameNoSave=セーブなし
SavesGameShader=シェーダー {0}
SavesGameBackups=バックアップ {0} 件
SavesSaveTitle=セーブデータ
SavesSaveInfo={0} · 更新 {1}
SavesSaveNone=まだセーブがありません。ゲームで最初にセーブしたときにEdenが作成します。
SavesBackupNow=今すぐバックアップ
SavesOpenFolder=フォルダーを開く
SavesShaderTitle=シェーダーキャッシュ
SavesShaderNone=シェーダーキャッシュなし
SavesShaderDelete=キャッシュを削除
SavesShaderHint=Edenの更新後のグラフィック不具合に効果があります。キャッシュはプレイ中にEdenが再作成します (最初は短いカクつきあり)。
SavesBackupsTitle=バックアップ
SavesBackupsEmpty=このゲームのバックアップはまだありません。「今すぐバックアップ」で作成できます。
SavesRestore=復元
SavesDelete=削除
SavesReasonManual=手動
SavesReasonAuto=Eden更新前に自動
SavesReasonRestore=復元前の状態
SavesBackupDone=セーブをバックアップしました: {0}
SavesNothing=このゲームにはバックアップするセーブがありません。
SavesAskRestore={0} のセーブを復元しますか?\n\n現在のセーブは先にバックアップされます。
SavesRestored=セーブを復元しました: {0}
SavesAskDelete={0} のバックアップを削除しますか?\n\nファイルはごみ箱に移動されます。
SavesDeleted=バックアップを削除しました: {0}
SavesAskShader='{0}' のシェーダーキャッシュを削除しますか ({1})?
SavesAskShaderAll=すべてのシェーダーキャッシュを削除しますか ({0})?\n\nプレイ中にEdenが再作成します。
SavesShaderDeleted=シェーダーキャッシュを削除しました: {0}
ChkSaveAuto=Edenの更新前に毎回セーブをバックアップする
WSavesBackup=セーブをバックアップ中...
WSavesBacked=セーブをバックアップしました (変更のあるゲーム {0} 件)。
'@
zh = @'
Name=中文（简体）
Culture=zh-CN
AppSubtitle=更新到最新 Nightly 版本或安装旧版本
SubNotes=所选版本的更改内容
SubGames=直接用 Eden 启动你的游戏
SubMods=按游戏管理 Mod
SubContent=按游戏管理更新和 DLC
SubSaves=备份存档并清理着色器缓存
SubFirmware=Eden 的固件和密钥
SubSettings=设置更新程序和界面
SelfWaiting=更新程序的更新已下载，将在当前任务完成后安装。
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
GamesContinue=继续游戏
GamesLastPlayed=上次游玩：{0}
GamesLaunches=启动 {0} 次
GamesSortName=按名称
GamesSortRecent=最近游玩
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=标记为收藏 (显示在顶部)
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
NavContent=更新和 DLC
NavFirmware=固件
SysEdenRunning=Eden 正在运行。在此处更改前请先关闭 Eden，否则 Eden 退出时会覆盖更改。
ContentInfo={0} 个更新 · {1} 个 DLC
ContentScanning=正在搜索更新和 DLC...
ContentCopying=正在复制 {0}...
ContentAdd=添加更新/DLC...
ContentFolder=打开文件夹
ContentDelete=删除
ContentGameInfo={0} 个更新 · {1} 个 DLC
ContentNone=没有更新/DLC
ContentEmptyGame=此游戏没有更新或 DLC。点击「添加更新/DLC...」添加 NSP 或 XCI 文件。
ContentUpdate=更新 {0}
ContentUpdateAny=更新
ContentDlc=DLC {0}
ContentUnknown=更新/DLC
ContentFromGameDir=来自游戏文件夹
ContentFromNand=已安装到 NAND
ContentNandNoKeys=没有 prod.keys 无法识别安装在 NAND 中的更新/DLC (见固件选项卡)。
ContentDlcAll=开关适用于所有 DLC
ContentAskDelete=删除「{0}」?\n\n文件将被移到回收站。
ContentDeleted=已删除: {0}
ContentAdded=已添加: {0}
ContentOtherGame=「{0}」属于另一个游戏 (Title ID {1})，会显示在那里。
ContentToggledOn=已启用: {0}
ContentToggledOff=已禁用: {0}
ContentRegistered=已将文件夹作为外部内容文件夹添加到 Eden: {0}
FwTitle=固件
FwNone=未安装固件
FwVersion=固件 {0}
FwVersionUnknown=已安装固件 (版本未知)
FwFiles={0} 个文件 · {1}
FwInstallZip=从 ZIP 安装...
FwInstallDir=从文件夹...
FwDelete=删除
FwFolder=打开文件夹
FwHint=安装会替换当前固件。如果出错，旧固件会被保留。
FwPreparing=正在准备固件...
FwInstalling=正在安装固件... {0}/{1}
FwDone=固件已安装 ({0} 个文件)。
FwNoNca=所选内容中没有找到 .nca 文件。
FwAskReplace=已安装固件 ({0})。要替换吗?
FwAskDelete=确定删除固件吗?\n\n需要固件的游戏将无法启动。
FwDeleted=固件已删除。
FwKeysTooOld=你的 prod.keys 对此固件来说太旧了 (最高支持固件 {0})。
KeysTitle=密钥
KeysNone=未安装 prod.keys
KeysInstalled=prod.keys · {0} 个密钥
KeysGen=最高支持固件 {1} (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · {0} 条
KeysInstall=安装 prod.keys...
KeysDelete=删除
KeysHint=同一文件夹中的 title.keys 和 key_retail.bin 也会被复制。
KeysInvalid=所选文件看起来不是 prod.keys。
KeysDone=密钥已安装。
KeysAskDelete=删除 prod.keys 和 title.keys?\n\n文件将被移到回收站。
KeysDeleted=密钥已删除。
KeysMissingForFw=没有 prod.keys，Eden 无法使用固件。
NavSaves=游戏数据
SavesInfo={0} 个存档 · {1} 个备份 · 着色器缓存 {2}
SavesScanning=正在搜索存档和着色器缓存...
SavesWorking=请稍候...
SavesBackupDir=备份文件夹
SavesShaderAll=删除所有着色器缓存
SavesGameSave=存档 {0}
SavesGameNoSave=没有存档
SavesGameShader=着色器 {0}
SavesGameBackups={0} 个备份
SavesSaveTitle=存档
SavesSaveInfo={0} · 修改于 {1}
SavesSaveNone=还没有存档——在游戏中第一次保存时 Eden 会创建。
SavesBackupNow=立即备份
SavesOpenFolder=打开文件夹
SavesShaderTitle=着色器缓存
SavesShaderNone=没有着色器缓存
SavesShaderDelete=删除缓存
SavesShaderHint=可解决 Eden 更新后的图形错误。Eden 会在游戏时重建缓存 (开始时会短暂卡顿)。
SavesBackupsTitle=备份
SavesBackupsEmpty=此游戏还没有备份。点击「立即备份」创建一个。
SavesRestore=恢复
SavesDelete=删除
SavesReasonManual=手动
SavesReasonAuto=Eden 更新前自动备份
SavesReasonRestore=恢复前的状态
SavesBackupDone=存档已备份: {0}
SavesNothing=此游戏没有可备份的存档。
SavesAskRestore=恢复 {0} 的存档?\n\n会先备份当前存档。
SavesRestored=存档已恢复: {0}
SavesAskDelete=删除 {0} 的备份?\n\n文件将被移到回收站。
SavesDeleted=备份已删除: {0}
SavesAskShader=删除「{0}」的着色器缓存 ({1})?
SavesAskShaderAll=删除所有着色器缓存 ({0})?\n\nEden 会在游戏时重建。
SavesShaderDeleted=着色器缓存已删除: {0}
ChkSaveAuto=每次更新 Eden 前备份存档
WSavesBackup=正在备份存档...
WSavesBacked=存档已备份 ({0} 个有改动的游戏)。
'@
ko = @'
Name=한국어
Culture=ko-KR
AppSubtitle=최신 Nightly 빌드로 업데이트하거나 이전 버전을 설치합니다
SubNotes=선택한 버전의 변경 사항
SubGames=Eden으로 게임을 바로 실행
SubMods=게임별 모드 관리
SubContent=게임별 업데이트와 DLC 관리
SubSaves=세이브 백업과 셰이더 캐시 정리
SubFirmware=Eden용 펌웨어와 키
SubSettings=업데이터와 화면 설정
SelfWaiting=업데이터 업데이트가 다운로드되었으며 현재 작업이 끝나면 설치됩니다.
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
GamesContinue=이어서 플레이
GamesLastPlayed=마지막 플레이: {0}
GamesLaunches={0}회 실행
GamesSortName=이름순
GamesSortRecent=최근 플레이순
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
ThColAurora=Aurora
ThColSunset=Sunset
ThColSynth=Synthwave
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
GamesFavTip=즐겨찾기로 표시 (맨 위에 표시)
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
NavContent=업데이트 및 DLC
NavFirmware=펌웨어
SysEdenRunning=Eden이 실행 중입니다. 여기서 변경하기 전에 Eden을 닫으세요. 그렇지 않으면 종료 시 변경 사항을 덮어씁니다.
ContentInfo=업데이트 {0}개 · DLC {1}개
ContentScanning=업데이트와 DLC 검색 중...
ContentCopying={0} 복사 중...
ContentAdd=업데이트/DLC 추가...
ContentFolder=폴더 열기
ContentDelete=삭제
ContentGameInfo=업데이트 {0}개 · DLC {1}개
ContentNone=업데이트/DLC 없음
ContentEmptyGame=이 게임에 대한 업데이트나 DLC가 없습니다. '업데이트/DLC 추가...'로 NSP 또는 XCI 파일을 추가하세요.
ContentUpdate=업데이트 {0}
ContentUpdateAny=업데이트
ContentDlc=DLC {0}
ContentUnknown=업데이트/DLC
ContentFromGameDir=게임 폴더에서
ContentFromNand=NAND에 설치됨
ContentNandNoKeys=NAND에 설치된 업데이트/DLC는 prod.keys 없이 식별할 수 없습니다 (펌웨어 탭 참조).
ContentDlcAll=스위치는 모든 DLC에 적용됩니다
ContentAskDelete='{0}'을(를) 삭제할까요?\n\n파일은 휴지통으로 이동됩니다.
ContentDeleted=삭제됨: {0}
ContentAdded=추가됨: {0}
ContentOtherGame='{0}'은(는) 다른 게임(Title ID {1})의 것이며 그쪽에 표시됩니다.
ContentToggledOn=활성화됨: {0}
ContentToggledOff=비활성화됨: {0}
ContentRegistered=폴더를 Eden의 외부 콘텐츠 폴더로 등록했습니다: {0}
FwTitle=펌웨어
FwNone=설치된 펌웨어 없음
FwVersion=펌웨어 {0}
FwVersionUnknown=펌웨어 설치됨 (버전 알 수 없음)
FwFiles=파일 {0}개 · {1}
FwInstallZip=ZIP에서 설치...
FwInstallDir=폴더에서...
FwDelete=삭제
FwFolder=폴더 열기
FwHint=설치하면 현재 펌웨어가 교체됩니다. 문제가 생기면 이전 펌웨어가 유지됩니다.
FwPreparing=펌웨어 준비 중...
FwInstalling=펌웨어 설치 중... {0}/{1}
FwDone=펌웨어 설치됨 (파일 {0}개).
FwNoNca=선택한 항목에서 .nca 파일을 찾지 못했습니다.
FwAskReplace=이미 펌웨어가 설치되어 있습니다 ({0}). 교체할까요?
FwAskDelete=정말 펌웨어를 삭제할까요?\n\n펌웨어가 필요한 게임은 더 이상 실행되지 않습니다.
FwDeleted=펌웨어가 삭제되었습니다.
FwKeysTooOld=prod.keys가 이 펌웨어에 비해 너무 오래되었습니다 (펌웨어 {0}까지 지원).
KeysTitle=키
KeysNone=설치된 prod.keys 없음
KeysInstalled=prod.keys · 키 {0}개
KeysGen=펌웨어 {1}까지 지원 (master key {0})
KeysGenRaw=Master key {0}
KeysTitleKeys=title.keys · 항목 {0}개
KeysInstall=prod.keys 설치...
KeysDelete=삭제
KeysHint=같은 폴더의 title.keys와 key_retail.bin도 함께 복사됩니다.
KeysInvalid=선택한 파일이 prod.keys가 아닌 것 같습니다.
KeysDone=키가 설치되었습니다.
KeysAskDelete=prod.keys와 title.keys를 삭제할까요?\n\n파일은 휴지통으로 이동됩니다.
KeysDeleted=키가 삭제되었습니다.
KeysMissingForFw=prod.keys가 없으면 Eden이 펌웨어를 사용할 수 없습니다.
NavSaves=게임 데이터
SavesInfo=세이브 {0}개 · 백업 {1}개 · 셰이더 캐시 {2}
SavesScanning=세이브와 셰이더 캐시 검색 중...
SavesWorking=잠시만 기다려 주세요...
SavesBackupDir=백업 폴더
SavesShaderAll=모든 셰이더 캐시 삭제
SavesGameSave=세이브 {0}
SavesGameNoSave=세이브 없음
SavesGameShader=셰이더 {0}
SavesGameBackups=백업 {0}개
SavesSaveTitle=세이브 데이터
SavesSaveInfo={0} · 변경 {1}
SavesSaveNone=아직 세이브가 없습니다. 게임에서 처음 저장할 때 Eden이 만듭니다.
SavesBackupNow=지금 백업
SavesOpenFolder=폴더 열기
SavesShaderTitle=셰이더 캐시
SavesShaderNone=셰이더 캐시 없음
SavesShaderDelete=캐시 삭제
SavesShaderHint=Eden 업데이트 후 그래픽 오류에 도움이 됩니다. Eden이 플레이 중에 캐시를 다시 만듭니다 (처음에는 잠깐 끊김).
SavesBackupsTitle=백업
SavesBackupsEmpty=이 게임의 백업이 아직 없습니다. '지금 백업'으로 만드세요.
SavesRestore=복원
SavesDelete=삭제
SavesReasonManual=수동
SavesReasonAuto=Eden 업데이트 전 자동
SavesReasonRestore=복원 전 상태
SavesBackupDone=세이브 백업됨: {0}
SavesNothing=이 게임에는 백업할 세이브가 없습니다.
SavesAskRestore={0}의 세이브를 복원할까요?\n\n현재 세이브는 먼저 백업됩니다.
SavesRestored=세이브 복원됨: {0}
SavesAskDelete={0}의 백업을 삭제할까요?\n\n파일은 휴지통으로 이동됩니다.
SavesDeleted=백업 삭제됨: {0}
SavesAskShader='{0}'의 셰이더 캐시를 삭제할까요 ({1})?
SavesAskShaderAll=모든 셰이더 캐시를 삭제할까요 ({0})?\n\nEden이 플레이 중에 다시 만듭니다.
SavesShaderDeleted=셰이더 캐시 삭제됨: {0}
ChkSaveAuto=Eden 업데이트 전마다 세이브 백업
WSavesBackup=세이브 백업 중...
WSavesBacked=세이브 백업됨 (변경된 게임 {0}개).
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
$contentSync = [hashtable]::Synchronized(@{
    Done     = $false
    Result   = $null
    Args     = $null
    Status   = ""
    Progress = -1
})
$savesSync = [hashtable]::Synchronized(@{
    Done   = $false
    Result = $null
    Args   = $null
})
$fwSync = [hashtable]::Synchronized(@{
    Done   = $false
    Result = $null
    Args   = $null
    Cur    = 0
    Total  = 0
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
                if ($f.Extension -notmatch '^\.(nsp|nsz|xci|xcz|nro)$') { continue }
                if ($seen.ContainsKey($f.FullName)) { continue }
                $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
                # Updates/DLCs ueberspringen (Title-ID endet nicht auf 000)
                $tidM = [regex]::Match($base, '(?i)\b(01[0-9a-f]{14})\b')
                $tidS = if ($tidM.Success) { $tidM.Value.ToUpperInvariant() } elseif ($f.Extension -eq ".nsp" -or $f.Extension -eq ".nsz") { Get-NspTid $f.FullName } else { $null }
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

# Updates/DLC: NSP/NSZ/XCI/XCZ in Edens externen Inhaltsordnern (+ Spieleordnern) finden
# und neue Dateien in den eigenen Ordner <Eden-Daten>\external_content\<TitleID>\ kopieren.
# Title-IDs: Spiel = ...000, Update = Spiel + 0x800, DLC = Spiel + 0x1000 + Nummer
$jobContent = {
    $a = $sync.Args
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
    function Get-ContentId([string]$path) {
        $base = [IO.Path]::GetFileNameWithoutExtension($path)
        $m = [regex]::Match($base, '(?i)\b(01[0-9a-f]{14})\b')
        $tid = if ($m.Success) { $m.Groups[1].Value.ToUpperInvariant() } elseif ($path -match '(?i)\.(nsp|nsz)$') { Get-NspTid $path } else { $null }
        $ver = $null
        $vm = [regex]::Match($base, '(?i)\[v(\d+)\]')
        if (-not $vm.Success) { $vm = [regex]::Match($base, '(?i)(?<![\w.])v(\d{5,10})(?!\d)') }
        if ($vm.Success) { $ver = [int64]$vm.Groups[1].Value }
        return @{ Tid = $tid; Version = $ver }
    }
    function Get-Kind([string]$tid) {
        $low = [Convert]::ToInt32($tid.Substring(12), 16) -band 0x1FFF
        if ($low -eq 0) { return "base" }
        if ($low -eq 0x800) { return "update" }
        if ($low -ge 0x1000) { return "dlc" }
        return "other"
    }
    function Get-BaseTid([string]$tid) { return $tid.Substring(0, 12) + (([Convert]::ToInt32($tid.Substring(12), 16)) -band 0xE000).ToString("X4") }
    # --- Ueber Eden in den NAND installierte Inhalte: Meta-NCA entschluesseln (Header: AES-XTS mit
    # header_key und Nintendo-Tweak; Abschnitt: AES-CTR mit Schluessel aus dem Key-Area) und das CNMT lesen.
    function Read-ProdKeys([string]$path) {
        $k = @{}
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $k }
        foreach ($line in [IO.File]::ReadAllLines($path)) {
            if ($line -notmatch '^\s*([A-Za-z0-9_]+)\s*=\s*([0-9A-Fa-f]+)\s*$') { continue }
            $hex = $Matches[2]
            if ($hex.Length % 2) { continue }
            $b = New-Object byte[] ($hex.Length / 2)
            for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($hex.Substring(2 * $i, 2), 16) }
            $k[$Matches[1].ToLowerInvariant()] = $b
        }
        return $k
    }
    function New-EcbTransform([byte[]]$key, [bool]$encrypt) {
        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Mode = [Security.Cryptography.CipherMode]::ECB
        $aes.Padding = [Security.Cryptography.PaddingMode]::None
        $aes.Key = $key
        if ($encrypt) { return $aes.CreateEncryptor() }
        return $aes.CreateDecryptor()
    }
    function Invoke-XtsDecrypt([byte[]]$data, [byte[]]$key, [int64]$sector) {
        $k1 = New-Object byte[] 16; $k2 = New-Object byte[] 16
        [Array]::Copy($key, 0, $k1, 0, 16); [Array]::Copy($key, 16, $k2, 0, 16)
        $dec = New-EcbTransform $k1 $false
        $enc = New-EcbTransform $k2 $true
        $out = New-Object byte[] $data.Length
        $tw = New-Object byte[] 0x200
        $x = New-Object byte[] 0x200
        for ($s = 0; $s -lt [int]($data.Length / 0x200); $s++) {
            $t = New-Object byte[] 16
            $n = $sector + $s
            for ($i = 15; $i -ge 0; $i--) { $t[$i] = [byte]($n -band 0xFF); $n = $n -shr 8 }
            $T = $enc.TransformFinalBlock($t, 0, 16)
            for ($j = 0; $j -lt 32; $j++) {
                [Array]::Copy($T, 0, $tw, $j * 16, 16)
                $c = 0
                for ($i = 0; $i -lt 16; $i++) { $nc = ($T[$i] -shr 7) -band 1; $T[$i] = [byte]((($T[$i] -shl 1) -band 0xFF) -bor $c); $c = $nc }
                if ($c) { $T[0] = [byte]($T[0] -bxor 0x87) }
            }
            $o = $s * 0x200
            for ($i = 0; $i -lt 0x200; $i++) { $x[$i] = $data[$o + $i] -bxor $tw[$i] }
            $y = $dec.TransformFinalBlock($x, 0, 0x200)
            for ($i = 0; $i -lt 0x200; $i++) { $out[$o + $i] = $y[$i] -bxor $tw[$i] }
        }
        return , $out
    }
    function Invoke-CtrDecrypt([byte[]]$data, [byte[]]$key, [byte[]]$upper, [int64]$offset) {
        $ctr = New-Object byte[] $data.Length
        $blk = [int64]($offset / 16)
        for ($b = 0; $b -lt [int]($data.Length / 16); $b++) {
            [Array]::Copy($upper, 0, $ctr, $b * 16, 8)
            $v = $blk + $b
            for ($i = 15; $i -ge 8; $i--) { $ctr[$b * 16 + $i] = [byte]($v -band 0xFF); $v = $v -shr 8 }
        }
        $ks = (New-EcbTransform $key $true).TransformFinalBlock($ctr, 0, $ctr.Length)
        $out = New-Object byte[] $data.Length
        for ($i = 0; $i -lt $data.Length; $i++) { $out[$i] = $data[$i] -bxor $ks[$i] }
        return , $out
    }
    # Liefert @{ Tid; Type (0x81 Update, 0x82 DLC); Version; Contents = @(@{ Id; Size }) } oder $null (keine Meta-NCA)
    function Read-NcaMeta($item, $keys) {
        $path = if ($item.PSIsContainer) { Join-Path $item.FullName "00" } else { $item.FullName }
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        $fs = $null
        try {
            $fs = [IO.File]::OpenRead($path)
            if ($fs.Length -lt 0xC00) { return $null }
            $raw = New-Object byte[] 0x600
            [void]$fs.Read($raw, 0, 0x600)
            # Sektor 1 enthaelt Magic und Inhaltstyp: reicht, um alle Nicht-Meta-NCAs schnell auszusortieren
            $s1 = New-Object byte[] 0x200
            [Array]::Copy($raw, 0x200, $s1, 0, 0x200)
            $p1 = Invoke-XtsDecrypt $s1 $keys["header_key"] 1
            if ([Text.Encoding]::ASCII.GetString($p1, 0, 4) -ne "NCA3" -or $p1[5] -ne 1) { return $null }
            $h = Invoke-XtsDecrypt $raw $keys["header_key"] 0
            $r = @{ Tid = [BitConverter]::ToUInt64($h, 0x210).ToString("X16"); Type = 0; Version = $null; Contents = @() }
            $gen = [Math]::Max([int]$h[0x206], [int]$h[0x220])
            $mk = [Math]::Max($gen, 1) - 1
            $kakType = @("application", "ocean", "system")[[Math]::Min([int]$h[0x207], 2)]
            $kak = $keys[("key_area_key_{0}_{1:x2}" -f $kakType, $mk)]
            $fh = 0x400
            $encType = $h[$fh + 4]
            $layers = [BitConverter]::ToInt32($h, $fh + 0x2C)
            if (-not $kak -or $layers -lt 1 -or $layers -gt 5 -or ($encType -ne 1 -and $encType -ne 3)) { return $r }
            $rOff  = [BitConverter]::ToInt64($h, $fh + 0x30 + 0x10 * ($layers - 1))
            $rSize = [BitConverter]::ToInt64($h, $fh + 0x38 + 0x10 * ($layers - 1))
            $abs = [int64][BitConverter]::ToUInt32($h, 0x240) * 0x200 + $rOff
            $len = [int][Math]::Min($rSize, 256KB)
            $start = $abs - ($abs % 16)
            $pre = [int]($abs - $start)
            $total = $pre + $len
            if ($total % 16) { $total += 16 - ($total % 16) }
            $buf = New-Object byte[] $total
            $fs.Position = $start
            $got = $fs.Read($buf, 0, $total)
            if ($got -lt $pre + $len) { return $r }
            if ($encType -eq 3) {
                $encKey = New-Object byte[] 16
                [Array]::Copy($h, 0x320, $encKey, 0, 16)
                $ctrKey = (New-EcbTransform $kak $false).TransformFinalBlock($encKey, 0, 16)
                $upper = New-Object byte[] 8
                for ($i = 0; $i -lt 8; $i++) { $upper[$i] = $h[$fh + 0x140 + 7 - $i] }
                $buf = Invoke-CtrDecrypt $buf $ctrKey $upper $start
            }
            # PFS0 mit der .cnmt-Datei
            if ([Text.Encoding]::ASCII.GetString($buf, $pre, 4) -ne "PFS0") { return $r }
            $n = [BitConverter]::ToInt32($buf, $pre + 4)
            $strSize = [BitConverter]::ToInt32($buf, $pre + 8)
            if ($n -lt 1 -or $n -gt 64) { return $r }
            $strBase = $pre + 0x10 + 24 * $n
            $dataBase = $strBase + $strSize
            for ($e = 0; $e -lt $n; $e++) {
                $eo = $pre + 0x10 + 24 * $e
                $dOff = [int][BitConverter]::ToInt64($buf, $eo)
                $nOff = [BitConverter]::ToInt32($buf, $eo + 16)
                $end = [Array]::IndexOf($buf, [byte]0, $strBase + $nOff)
                $name = [Text.Encoding]::ASCII.GetString($buf, $strBase + $nOff, $end - $strBase - $nOff)
                if (-not $name.EndsWith(".cnmt")) { continue }
                $c = $dataBase + $dOff
                if ($c + 0x20 -gt $buf.Length) { return $r }
                $r.Tid = [BitConverter]::ToUInt64($buf, $c).ToString("X16")
                $r.Version = [int64][BitConverter]::ToUInt32($buf, $c + 8)
                $r.Type = [int]$buf[$c + 0xC]
                $tbl = [BitConverter]::ToUInt16($buf, $c + 0xE)
                $cnt = [BitConverter]::ToUInt16($buf, $c + 0x10)
                $list = @()
                for ($k = 0; $k -lt $cnt; $k++) {
                    $ro = $c + 0x20 + $tbl + 0x38 * $k
                    if ($ro + 0x38 -gt $buf.Length) { break }
                    $id = ([BitConverter]::ToString($buf, $ro + 0x20, 16)).Replace("-", "").ToLowerInvariant()
                    $sz = [int64]0
                    for ($i = 5; $i -ge 0; $i--) { $sz = $sz * 256 + $buf[$ro + 0x30 + $i] }
                    $list += @{ Id = $id; Size = $sz }
                }
                $r.Contents = $list
                break
            }
            return $r
        } catch {
            return $null
        } finally {
            if ($fs) { $fs.Close() }
        }
    }
    function Get-ItemSize($it) {
        if (-not $it.PSIsContainer) { return [int64]$it.Length }
        $s = [int64]0
        foreach ($f in Get-ChildItem -LiteralPath $it.FullName -File -Force -ErrorAction SilentlyContinue) { $s += $f.Length }
        return $s
    }

    function Get-CleanName([string]$file) {
        $n = [IO.Path]::GetFileNameWithoutExtension($file)
        $n = [regex]::Replace($n, '\[[^\]]*\]|\([^\)]*\)', '')
        $n = [regex]::Replace($n.Replace('_', ' '), '\s{2,}', ' ').Trim(' ', '-', '.')
        if (-not $n) { $n = $file }
        return $n
    }
    try {
        $managed = [string]$a.Managed
        if ($a.Mode -eq "add") {
            $added = @(); $other = @(); $skipped = @()
            foreach ($src in @($a.Files)) {
                $id = Get-ContentId $src
                $kind = if ($id.Tid) { Get-Kind $id.Tid } else { "unknown" }
                $name = [IO.Path]::GetFileName($src)
                if ($kind -eq "base" -or $kind -eq "other") { $skipped += $name; continue }
                $base = if ($kind -eq "update" -or $kind -eq "dlc") { Get-BaseTid $id.Tid } else { [string]$a.Base }
                $dir = Join-Path $managed $base
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                $dest = Join-Path $dir $name
                if ([IO.Path]::GetFullPath($src) -ne [IO.Path]::GetFullPath($dest)) {
                    $sync.Status = $name; $sync.Progress = 0
                    $tmp = $dest + ".eu-part"
                    $in = $null; $out = $null
                    try {
                        $in  = [IO.File]::OpenRead($src)
                        $out = [IO.File]::Create($tmp)
                        $buf = New-Object byte[] (4MB)
                        $tot = [Math]::Max(1L, $in.Length); $done = 0L
                        while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                            $out.Write($buf, 0, $n); $done += $n
                            $sync.Progress = [int](100 * $done / $tot)
                        }
                    } catch {
                        if ($out) { $out.Close(); $out = $null }
                        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                        throw
                    } finally {
                        if ($in) { $in.Close() }
                        if ($out) { $out.Close() }
                    }
                    Move-Item -LiteralPath $tmp -Destination $dest -Force
                }
                $added += $name
                if ($base -ne [string]$a.Base) { $other += ,@($name, $base) }
            }
            $sync.Result = @{ Ok = $true; Mode = "add"; Added = $added; Other = $other; Skipped = $skipped }
            return
        }

        # Edens Einstellungen: externe Inhaltsordner, Spieleordner, "Updates/DLC aus Spieleordnern laden"
        $cfg = [string]$a.Config
        $extDirs = @(); $gameDirs = @(); $fromGame = $true
        if ($cfg -and (Test-Path -LiteralPath $cfg)) {
            $txt = [IO.File]::ReadAllText($cfg)
            $mm = [regex]::Match($txt, '(?m)^ext_content_from_game_dirs=(\w+)\s*$')
            if ($mm.Success) { $fromGame = ($mm.Groups[1].Value.Trim() -eq "true") }
            foreach ($m in [regex]::Matches($txt, '(?m)^external_content_dirs\\\d+\\path=(.*)$')) {
                $pth = $m.Groups[1].Value.Trim().Trim('"').Replace('/', '\')
                if ($pth) { $extDirs += $pth }
            }
            $paths = @{}; $deep = @{}
            foreach ($m in [regex]::Matches($txt, '(?m)gamedirs\\(\d+)\\path=(.*)$'))      { $paths[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() }
            foreach ($m in [regex]::Matches($txt, '(?m)gamedirs\\(\d+)\\deep_scan=(.*)$')) { $deep[$m.Groups[1].Value]  = ($m.Groups[2].Value.Trim() -eq "true") }
            foreach ($k in $paths.Keys) {
                $pth = $paths[$k].Trim('"')
                if (-not $pth -or $pth -in @("SDMC", "UserNAND", "SysNAND")) { continue }
                $gameDirs += @{ Path = $pth.Replace('/', '\'); Deep = [bool]$deep[$k] }
            }
        }
        $norm = { param($x) ([string]$x).Replace('/', '\').TrimEnd('\').ToLowerInvariant() }
        $roots = New-Object System.Collections.ArrayList
        [void]$roots.Add(@{ Path = $managed; Deep = $true; Source = "ext" })
        foreach ($d in $extDirs) { [void]$roots.Add(@{ Path = $d; Deep = $true; Source = "ext" }) }
        if ($fromGame) { foreach ($d in $gameDirs) { [void]$roots.Add(@{ Path = $d.Path; Deep = $d.Deep; Source = "game" }) } }

        $items = New-Object System.Collections.ArrayList
        $seen = @{}
        $mRoot = (& $norm $managed) + '\'
        foreach ($r in $roots) {
            if (-not $r.Path -or -not (Test-Path -LiteralPath $r.Path)) { continue }
            $files = if ($r.Deep) { Get-ChildItem -LiteralPath $r.Path -File -Recurse -ErrorAction SilentlyContinue }
                     else         { Get-ChildItem -LiteralPath $r.Path -File -ErrorAction SilentlyContinue }
            foreach ($f in $files) {
                if ($f.Extension -notmatch '^\.(nsp|nsz|xci|xcz)$') { continue }
                $key = & $norm $f.FullName
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                $id = Get-ContentId $f.FullName
                $kind = if ($id.Tid) { Get-Kind $id.Tid } else { "unknown" }
                if ($kind -eq "base" -or $kind -eq "other") { continue }
                $base = if ($id.Tid) { Get-BaseTid $id.Tid } else { $null }
                if (-not $base) {
                    # ohne Title-ID nur zuordnen, wenn die Datei in unserem Ordner <TitleID>\ liegt
                    $par = Split-Path -Leaf (Split-Path -Parent $f.FullName)
                    if ($key.StartsWith($mRoot) -and $par -match '^[0-9A-Fa-f]{16}$') { $base = $par.ToUpperInvariant() } else { continue }
                }
                [void]$items.Add(@{
                    Base = $base; Tid = [string]$id.Tid; Kind = $kind; Version = $id.Version
                    Name = (Get-CleanName $f.Name); File = $f.Name; Path = $f.FullName; Size = $f.Length; Source = $r.Source
                    Managed = $key.StartsWith($mRoot)
                })
            }
        }
        # Ueber Eden in den NAND installierte Updates/DLCs
        $nandNoKeys = $false
        $reg = [string]$a.NandReg
        if ($reg -and (Test-Path -LiteralPath $reg)) {
            $ncas = @(Get-ChildItem -LiteralPath $reg -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)^[0-9a-f]{32}(\.cnmt)?\.nca$' })
            if ($ncas.Count) {
                $keys = Read-ProdKeys ([string]$a.KeysFile)
                if (-not $keys.ContainsKey("header_key") -or $keys["header_key"].Length -ne 32) {
                    $nandNoKeys = $true
                } else {
                    $byId = @{}
                    foreach ($n in $ncas) { $id = $n.Name.Substring(0, 32).ToLowerInvariant(); if (-not $byId.ContainsKey($id)) { $byId[$id] = $n } }
                    foreach ($n in $ncas) {
                        $meta = Read-NcaMeta $n $keys
                        if (-not $meta) { continue }
                        $kind = if ($meta.Type -eq 0x81) { "update" } elseif ($meta.Type -eq 0x82) { "dlc" } else { Get-Kind $meta.Tid }
                        if ($kind -ne "update" -and $kind -ne "dlc") { continue }
                        $paths = @($n.FullName); $size = Get-ItemSize $n
                        foreach ($c in @($meta.Contents)) {
                            if (-not $byId.ContainsKey($c.Id)) { continue }
                            $p = $byId[$c.Id]
                            if ($p.FullName -ne $n.FullName) { $paths += $p.FullName; $size += Get-ItemSize $p }
                        }
                        [void]$items.Add(@{
                            Base = (Get-BaseTid $meta.Tid); Tid = $meta.Tid; Kind = $kind; Version = $meta.Version
                            Name = ""; File = $n.Name; Path = $n.FullName; Paths = $paths; Size = $size; Source = "nand"; Managed = $false
                        })
                    }
                }
            }
        }
        $registered = @($extDirs | Where-Object { (& $norm $_) -eq (& $norm $managed) }).Count -gt 0
        $sync.Result = @{ Ok = $true; Mode = "scan"; Items = @($items); Registered = $registered; NandNoKeys = $nandNoKeys }
    } catch {
        $sync.Result = @{ Ok = $false; Mode = [string]$a.Mode; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# Spielstaende: <NAND>\user\save\0000000000000000\<Benutzer-ID>\<TitleID>\ (bzw. Edens neues Format
# save\account\<Benutzer>\<TitleID>\ und save\device\<TitleID>\). Backups sind ZIPs mit Pfaden relativ zu
# save\, damit sie genau an dieselbe Stelle zurueckgehen. Wird auch vom Eden-Update (Auto-Backup) genutzt.
$saveLib = {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Get-SaveTidDirs([string]$root) {
        $map = @{}
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { return $map }
        $cands = New-Object System.Collections.ArrayList
        foreach ($base in @((Join-Path $root "0000000000000000"), (Join-Path $root "account"))) {
            if (-not (Test-Path -LiteralPath $base)) { continue }
            foreach ($u in Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue) {
                if ($u.Name -notmatch '^[0-9A-Fa-f]{32}$') { continue }
                foreach ($t in Get-ChildItem -LiteralPath $u.FullName -Directory -ErrorAction SilentlyContinue) { [void]$cands.Add($t) }
            }
        }
        $dev = Join-Path $root "device"
        if (Test-Path -LiteralPath $dev) { foreach ($t in Get-ChildItem -LiteralPath $dev -Directory -ErrorAction SilentlyContinue) { [void]$cands.Add($t) } }
        foreach ($t in $cands) {
            if ($t.Name -notmatch '^[0-9A-Fa-f]{16}$') { continue }
            $tid = $t.Name.ToUpperInvariant()
            if ($tid.StartsWith("010000000000")) { continue }   # Systemtitel
            if (-not $map.ContainsKey($tid)) { $map[$tid] = New-Object System.Collections.ArrayList }
            [void]$map[$tid].Add($t.FullName)
        }
        return $map
    }

    function Get-DirStats($dirs) {
        $r = @{ Size = 0L; Files = 0; Newest = [DateTime]::MinValue }
        foreach ($d in @($dirs)) {
            if (-not (Test-Path -LiteralPath $d)) { continue }
            foreach ($f in Get-ChildItem -LiteralPath $d -File -Recurse -Force -ErrorAction SilentlyContinue) {
                $r.Size += $f.Length; $r.Files++
                if ($f.LastWriteTimeUtc -gt $r.Newest) { $r.Newest = $f.LastWriteTimeUtc }
            }
        }
        return $r
    }

    function Get-LastBackupTime([string]$backupDir, [string]$tid) {
        $d = Join-Path $backupDir $tid
        if (-not (Test-Path -LiteralPath $d)) { return [DateTime]::MinValue }
        $z = Get-ChildItem -LiteralPath $d -File -Filter *.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($z) { return $z.LastWriteTimeUtc }
        return [DateTime]::MinValue
    }

    # reason: manual | auto | restore. Rueckgabe: Pfad der ZIP oder $null (kein Spielstand)
    function New-SaveBackup([string]$root, [string]$tid, $dirs, [string]$backupDir, [string]$reason) {
        $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
        $entries = New-Object System.Collections.ArrayList
        foreach ($d in @($dirs)) {
            if (-not (Test-Path -LiteralPath $d)) { continue }
            $all = @(Get-Item -LiteralPath $d -Force) + @(Get-ChildItem -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue)
            foreach ($e in $all) {
                $rel = $e.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
                if ($e.PSIsContainer) {
                    if (-not @(Get-ChildItem -LiteralPath $e.FullName -Force -ErrorAction SilentlyContinue).Count) { [void]$entries.Add(@{ Rel = $rel + "/"; Full = $null }) }
                } else { [void]$entries.Add(@{ Rel = $rel; Full = $e.FullName }) }
            }
        }
        if (-not @($entries | Where-Object { $_.Full }).Count) { return $null }
        $dir = Join-Path $backupDir $tid
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $path = Join-Path $dir ($stamp + "_" + $reason + ".zip")
        $n = 2
        while (Test-Path -LiteralPath $path) { $path = Join-Path $dir ("{0}_{1}_{2}.zip" -f $stamp, $reason, $n); $n++ }
        $tmp = $path + ".part"
        $fs = [IO.File]::Create($tmp)
        $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($e in $entries) {
                if ($e.Full) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $e.Full, $e.Rel, [IO.Compression.CompressionLevel]::Optimal) }
                else { [void]$zip.CreateEntry($e.Rel) }
            }
        } finally {
            $zip.Dispose(); $fs.Close()
        }
        Move-Item -LiteralPath $tmp -Destination $path -Force
        return $path
    }

    # Aktuellen Spielstand des Spiels entfernen und das Backup an dieselben Stellen entpacken
    function Restore-SaveBackup([string]$root, [string]$tid, [string]$zipPath, $currentDirs) {
        $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        $za = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $ok = @($za.Entries | Where-Object { $_.FullName -match ('(^|/)' + $tid + '(/|$)') })
            if (-not $ok.Count) { throw "Backup enthaelt keinen Spielstand fuer $tid" }
            foreach ($d in @($currentDirs)) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force } }
            foreach ($e in $ok) {
                $target = [IO.Path]::GetFullPath((Join-Path $root $e.FullName))
                if (-not $target.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { continue }
                if ($e.FullName.EndsWith('/')) { [void][IO.Directory]::CreateDirectory($target); continue }
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
            }
        } finally {
            $za.Dispose()
        }
    }

    function Remove-OldAutoBackups([string]$backupDir, [string]$tid, [int]$keep) {
        if ($keep -lt 1) { return }
        $d = Join-Path $backupDir $tid
        if (-not (Test-Path -LiteralPath $d)) { return }
        Get-ChildItem -LiteralPath $d -File -Filter "*_auto*.zip" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -Skip $keep | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Vor einem Eden-Update: alle Spiele sichern, deren Spielstand neuer ist als ihr letztes Backup
    function Backup-ChangedSaves([string]$root, [string]$backupDir, [int]$keep) {
        $count = 0
        $map = Get-SaveTidDirs $root
        foreach ($tid in $map.Keys) {
            $st = Get-DirStats $map[$tid]
            if (-not $st.Files -or $st.Newest -le (Get-LastBackupTime $backupDir $tid)) { continue }
            if (New-SaveBackup $root $tid $map[$tid] $backupDir "auto") { $count++ }
            Remove-OldAutoBackups $backupDir $tid $keep
        }
        return $count
    }
}

$jobSaves = {
    $a = $sync.Args
    try {
        if ($a.Mode -eq "scan") {
            $map = Get-SaveTidDirs $a.Root
            $saves = foreach ($tid in $map.Keys) {
                $st = Get-DirStats $map[$tid]
                @{ Tid = $tid; Dirs = @($map[$tid]); Size = $st.Size; Files = $st.Files; Newest = $st.Newest }
            }
            $shaders = @{}
            if ($a.ShaderRoot -and (Test-Path -LiteralPath $a.ShaderRoot)) {
                foreach ($d in Get-ChildItem -LiteralPath $a.ShaderRoot -Directory -ErrorAction SilentlyContinue) {
                    if ($d.Name -notmatch '^[0-9A-Fa-f]{16}$') { continue }
                    $st = Get-DirStats @($d.FullName)
                    $shaders[$d.Name.ToUpperInvariant()] = @{ Size = $st.Size; Path = $d.FullName }
                }
            }
            $backups = New-Object System.Collections.ArrayList
            if ($a.BackupDir -and (Test-Path -LiteralPath $a.BackupDir)) {
                foreach ($td in Get-ChildItem -LiteralPath $a.BackupDir -Directory -ErrorAction SilentlyContinue) {
                    if ($td.Name -notmatch '^[0-9A-Fa-f]{16}$') { continue }
                    foreach ($z in Get-ChildItem -LiteralPath $td.FullName -File -Filter *.zip -ErrorAction SilentlyContinue) {
                        $time = $z.LastWriteTime; $reason = "manual"
                        $m = [regex]::Match($z.Name, '^(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})_(manual|auto|restore)')
                        if ($m.Success) {
                            $time = [DateTime]::ParseExact($m.Groups[1].Value, "yyyy-MM-dd_HH-mm-ss", [Globalization.CultureInfo]::InvariantCulture)
                            $reason = $m.Groups[2].Value
                        }
                        [void]$backups.Add(@{ Tid = $td.Name.ToUpperInvariant(); Path = $z.FullName; File = $z.Name; Time = $time; Reason = $reason; Size = $z.Length })
                    }
                }
            }
            $sync.Result = @{ Ok = $true; Mode = "scan"; Saves = @($saves); Shaders = $shaders; Backups = @($backups) }
        } elseif ($a.Mode -eq "backup") {
            $p = New-SaveBackup $a.Root $a.Tid @($a.Dirs) $a.BackupDir "manual"
            $sync.Result = @{ Ok = $true; Mode = "backup"; Path = $p }
        } elseif ($a.Mode -eq "restore") {
            $cur = @($a.Dirs)
            if ($cur.Count -and (Get-DirStats $cur).Files) { [void](New-SaveBackup $a.Root $a.Tid $cur $a.BackupDir "restore") }
            Restore-SaveBackup $a.Root $a.Tid $a.Zip $cur
            $sync.Result = @{ Ok = $true; Mode = "restore" }
        } elseif ($a.Mode -eq "shader") {
            foreach ($d in @($a.Dirs)) { if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -LiteralPath $d -Recurse -Force } }
            $sync.Result = @{ Ok = $true; Mode = "shader" }
        }
    } catch {
        $sync.Result = @{ Ok = $false; Mode = [string]$a.Mode; Error = $_.Exception.Message }
    } finally {
        $sync.Done = $true
    }
}

# Firmware: alle .nca aus ZIP/Ordner flach nach nand\system\Contents\registered (wie Edens "Firmware installieren").
# Die alte Firmware wird erst nach Erfolg geloescht, bei einem Fehler kommt sie zurueck.
$jobFirmware = {
    $a = $sync.Args
    try {
        $target = [string]$a.Target
        $old    = $target + ".eu-old"
        if ($a.Mode -eq "delete") {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            $sync.Result = @{ Ok = $true; Mode = "delete" }
            return
        }
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = $null
        try {
            if ($a.Zip) {
                $zip  = [IO.Compression.ZipFile]::OpenRead([string]$a.Source)
                $list = @($zip.Entries | Where-Object { $_.Name -match '(?i)\.nca$' })
            } else {
                $list = @(Get-ChildItem -LiteralPath ([string]$a.Source) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)\.nca$' })
            }
            if ($list.Count -eq 0) { $sync.Result = @{ Ok = $false; Mode = "install"; Error = "nonca" }; return }
            $sync.Total = $list.Count; $sync.Cur = 0
            if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
            $hadOld = Test-Path -LiteralPath $target
            if ($hadOld) { [IO.Directory]::Move($target, $old) }
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            try {
                $i = 0
                foreach ($e in $list) {
                    $i++
                    $dest = Join-Path $target $e.Name
                    if ($zip) { [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true) }
                    else      { [IO.File]::Copy($e.FullName, $dest, $true) }
                    $sync.Cur = $i
                }
            } catch {
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
                if ($hadOld) { [IO.Directory]::Move($old, $target) }
                throw
            }
            if ($hadOld) { Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue }
            $sync.Result = @{ Ok = $true; Mode = "install"; Count = $list.Count }
        } finally {
            if ($zip) { $zip.Dispose() }
        }
    } catch {
        $sync.Result = @{ Ok = $false; Mode = [string]$a.Mode; Error = $_.Exception.Message }
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
            try {
                [IO.Compression.ZipFile]::ExtractToDirectory([string]$a.Zip, $tmp)
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

        # Spielstaende sichern (nur Spiele mit Aenderungen seit dem letzten Backup)
        if ($a.SaveBackup -and $a.SaveLib) {
            try {
                . ([scriptblock]::Create([string]$a.SaveLib))
                $sync.Progress = -1
                $sync.Status = (T "WSavesBackup")
                $nSaves = Backup-ChangedSaves ([string]$a.SaveRoot) ([string]$a.SaveBackupDir) ([int]$a.SaveKeep)
                Add-Log (TF "WSavesBacked" $nSaves)
            } catch {
                Add-Log ((T "ErrPrefix") + " " + (T "WSavesBackup") + " " + $_.Exception.Message)
            }
        }

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
        Title="Eden Updater" UseLayoutRounding="True" Width="1120" Height="790" MinWidth="960" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="{DynamicResource BrBg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  <Window.Resources>
    <FontFamily x:Key="FontHead">Bahnschrift, Segoe UI Semibold</FontFamily>
    <FontFamily x:Key="FontIcon">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <FontFamily x:Key="FontMono">Cascadia Mono, Consolas</FontFamily>
    <SolidColorBrush x:Key="BrPanel"  Color="#171D26"/>
    <SolidColorBrush x:Key="BrPanel2" Color="#1E2632"/>
    <SolidColorBrush x:Key="BrCard"   Color="#E0171D26"/>
    <SolidColorBrush x:Key="BrLine"   Color="#2A3442"/>
    <SolidColorBrush x:Key="BrText"   Color="#E6EDF3"/>
    <SolidColorBrush x:Key="BrMuted"  Color="#8B98A9"/>
    <SolidColorBrush x:Key="BrAccent" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrAccent2" Color="#2288EE"/>
    <SolidColorBrush x:Key="BrAccentText" Color="#22D3EE"/>
    <SolidColorBrush x:Key="BrBg" Color="#0F1419"/>
    <SolidColorBrush x:Key="BrAccentFg" Color="#04222A"/>
    <SolidColorBrush x:Key="BrSel" Color="#12313A"/>
    <SolidColorBrush x:Key="BrSelStrong" Color="#164E5C"/>
    <SolidColorBrush x:Key="BrLog" Color="#0B0F14"/>
    <SolidColorBrush x:Key="BrBadgeNewBg" Color="#164E3F"/>
    <SolidColorBrush x:Key="BrBadgeNewFg" Color="#34D399"/>
    <SolidColorBrush x:Key="BrBadgeInstBg" Color="#0E3A47"/>
    <!-- Verlaeufe: werden beim Start per Code ersetzt und folgen dem Theme -->
    <LinearGradientBrush x:Key="GrAccent" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#22D3EE" Offset="0"/>
      <GradientStop Color="#2288EE" Offset="1"/>
    </LinearGradientBrush>
    <LinearGradientBrush x:Key="GrHero" StartPoint="0,0" EndPoint="1,0">
      <GradientStop Color="#3022D3EE" Offset="0"/>
      <GradientStop Color="#0022D3EE" Offset="1"/>
    </LinearGradientBrush>
    <RadialGradientBrush x:Key="GlowA">
      <GradientStop Color="#3822D3EE" Offset="0"/>
      <GradientStop Color="#0022D3EE" Offset="1"/>
    </RadialGradientBrush>
    <RadialGradientBrush x:Key="GlowB">
      <GradientStop Color="#262288EE" Offset="0"/>
      <GradientStop Color="#002288EE" Offset="1"/>
    </RadialGradientBrush>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
    </Style>

    <!-- Kleine Ueberschrift (Karten, Abschnitte) -->
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
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource BrCard}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrLine}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="16"/>
      <Setter Property="Padding" Value="20"/>
    </Style>

    <!-- Hinweisleiste (z.B. "Eden laeuft gerade") -->
    <Style x:Key="Banner" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource BrBadgeInstBg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="12"/>
      <Setter Property="Padding" Value="14,9"/>
    </Style>

    <!-- Rundes Icon-Feld als Abschnittskopf -->
    <Style x:Key="IconBadge" TargetType="Border">
      <Setter Property="Width" Value="34"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Background" Value="{DynamicResource BrSel}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="IconBadgeGlyph" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="{StaticResource FontIcon}"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentText}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
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
                <Border x:Name="fill" Background="{DynamicResource GrAccent}" CornerRadius="6" Opacity="0"/>
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
            <Grid x:Name="root" Width="42" Height="24" Background="Transparent">
              <Border x:Name="track" CornerRadius="12" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1.5"/>
              <Border x:Name="fill" CornerRadius="12" Background="{DynamicResource GrAccent}" Opacity="0"/>
              <Ellipse x:Name="knob" Width="16" Height="16" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource BrMuted}" RenderTransformOrigin="0.5,0.5">
                <Ellipse.RenderTransform>
                  <TranslateTransform x:Name="kx" X="0"/>
                </Ellipse.RenderTransform>
              </Ellipse>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="knob" Property="Fill" Value="{DynamicResource BrAccentFg}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="18" Duration="0:0:0.26"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.5"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
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

    <!-- Einstellungszeile: Text links, Schalter rechts, ganze Zeile klickbar -->
    <Style x:Key="SwitchRow" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="-10,0,-10,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid x:Name="root" Background="Transparent">
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="10" Opacity="0"/>
              <Grid Margin="10,9,10,9">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ContentPresenter VerticalAlignment="Center" RecognizesAccessKey="True" Margin="0,0,14,0">
                  <ContentPresenter.Resources>
                    <Style TargetType="TextBlock">
                      <Setter Property="TextWrapping" Value="Wrap"/>
                      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
                    </Style>
                  </ContentPresenter.Resources>
                </ContentPresenter>
                <Grid Grid.Column="1" Width="42" Height="24" VerticalAlignment="Center">
                  <Border x:Name="track" CornerRadius="12" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1.5"/>
                  <Border x:Name="fill" CornerRadius="12" Background="{DynamicResource GrAccent}" Opacity="0"/>
                  <Ellipse x:Name="knob" Width="16" Height="16" HorizontalAlignment="Left" Margin="4,0,0,0" Fill="{DynamicResource BrMuted}">
                    <Ellipse.RenderTransform>
                      <TranslateTransform x:Name="kx" X="0"/>
                    </Ellipse.RenderTransform>
                  </Ellipse>
                </Grid>
              </Grid>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="knob" Property="Fill" Value="{DynamicResource BrAccentFg}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="18" Duration="0:0:0.26"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.5"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard>
                  <DoubleAnimation Storyboard.TargetName="kx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation>
                  <DoubleAnimation Storyboard.TargetName="fill" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/>
                </Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="track" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
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
            <Border x:Name="th" Background="{DynamicResource BrMuted}" CornerRadius="3" Margin="2" Opacity="0.35"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.15"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="th" Storyboard.TargetProperty="Opacity" To="0.35" Duration="0:0:0.25"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
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
                    BorderThickness="1" CornerRadius="10" Padding="4">
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
            <Border x:Name="bd" Background="Transparent" CornerRadius="7" Padding="12,7" Margin="0,1">
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
                    BorderThickness="1" CornerRadius="8" Padding="10,6">
              <ContentPresenter/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="10"/>
      <Setter Property="MinWidth" Value="10"/>
      <Setter Property="Template" Value="{StaticResource VBar}"/>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="MinWidth" Value="0"/>
          <Setter Property="Height" Value="10"/>
          <Setter Property="MinHeight" Value="10"/>
          <Setter Property="Template" Value="{StaticResource HBar}"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Fortschritt: Verlauf in Akzentfarbe, beim Warten laeuft ein Lichtband durch -->
    <Style TargetType="ProgressBar">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid x:Name="root" ClipToBounds="True">
              <Border x:Name="PART_Track" Background="{DynamicResource BrPanel2}" CornerRadius="2"/>
              <Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{DynamicResource GrAccent}" CornerRadius="2"/>
              <Border x:Name="indet" Visibility="Collapsed" HorizontalAlignment="Left" Width="220" CornerRadius="2"
                      Background="{DynamicResource GrAccent}">
                <Border.OpacityMask>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#00000000" Offset="0"/>
                    <GradientStop Color="#FF000000" Offset="0.5"/>
                    <GradientStop Color="#00000000" Offset="1"/>
                  </LinearGradientBrush>
                </Border.OpacityMask>
                <Border.RenderTransform>
                  <TranslateTransform x:Name="itt" X="-230"/>
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
                      <DoubleAnimation Storyboard.TargetName="itt" Storyboard.TargetProperty="X" From="-230" To="1900" Duration="0:0:2.0"/>
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
            <Grid>
              <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10">
                <ScrollViewer x:Name="PART_ContentHost" Focusable="False" Padding="{TemplateBinding Padding}"
                              HorizontalScrollBarVisibility="{TemplateBinding HorizontalScrollBarVisibility}"
                              VerticalScrollBarVisibility="{TemplateBinding VerticalScrollBarVisibility}"/>
              </Border>
              <Border x:Name="focus" BorderBrush="{DynamicResource BrAccent}" BorderThickness="1.5" CornerRadius="10"
                      Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="focus" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.14"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="focus" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <ControlTemplate x:Key="CbToggle" TargetType="ToggleButton">
      <Border x:Name="bd" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="10">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="34"/>
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="arrow" Grid.Column="1" Text="&#xE70D;" FontFamily="{StaticResource FontIcon}" FontSize="11"
                     Foreground="{DynamicResource BrMuted}" HorizontalAlignment="Center" VerticalAlignment="Center"
                     RenderTransformOrigin="0.5,0.5">
            <TextBlock.RenderTransform>
              <RotateTransform x:Name="arot" Angle="0"/>
            </TextBlock.RenderTransform>
          </TextBlock>
        </Grid>
      </Border>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrMuted}"/>
        </Trigger>
        <Trigger Property="IsChecked" Value="True">
          <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
          <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="arot" Storyboard.TargetProperty="Angle" To="180" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
          <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="arot" Storyboard.TargetProperty="Angle" To="0" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
        </Trigger>
      </ControlTemplate.Triggers>
    </ControlTemplate>

    <Style TargetType="ComboBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="bd" Background="Transparent" Padding="10,7" CornerRadius="7" Margin="4,1">
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
                          CornerRadius="10" Margin="0,4,0,0" Padding="0,3">
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
                      CornerRadius="10" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}">
                  <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="14"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,9,0"/>
                  <ContentPresenter VerticalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="10" Opacity="0" IsHitTestVisible="False"/>
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
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Hauptaktion: Akzent-Verlauf mit weichem Leuchten darunter -->
    <Style x:Key="BtnPrimary" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentFg}"/>
      <Setter Property="Background" Value="{DynamicResource GrAccent}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="glow" Background="{TemplateBinding Background}" CornerRadius="10" Margin="8,10,8,-3"
                      Opacity="0.30" IsHitTestVisible="False">
                <Border.Effect>
                  <BlurEffect Radius="14" KernelType="Gaussian"/>
                </Border.Effect>
              </Border>
              <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}">
                  <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="14"
                             Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" Margin="0,0,9,0"/>
                  <ContentPresenter VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}"/>
                </StackPanel>
              </Border>
              <Border x:Name="hl" Background="White" CornerRadius="10" Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="{x:Null}">
                <Setter TargetName="ico" Property="Visibility" Value="Collapsed"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.14" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="glow" Storyboard.TargetProperty="Opacity" To="0.75" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.25"/><DoubleAnimation Storyboard.TargetName="glow" Storyboard.TargetProperty="Opacity" To="0.30" Duration="0:0:0.3"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.96" Duration="0:0:0.08"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.96" Duration="0:0:0.08"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.3"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="root" Property="Opacity" Value="0.4"/>
                <Setter TargetName="glow" Property="Visibility" Value="Collapsed"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Padding" Value="10,6"/>
    </Style>

    <!-- Getoente Variante (z.B. "Eden starten") -->
    <Style x:Key="BtnTonal" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="{DynamicResource BrSel}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrSelStrong}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrAccentText}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <!-- Seitenleiste: der aktive Eintrag bekommt per Code helle Schrift und ein Akzent-Icon (BorderBrush);
         den Hintergrund liefert die gleitende Markierung (NavPill) -->
    <Style x:Key="BtnNav" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrMuted}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BrMuted}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Height" Value="40"/>
      <Setter Property="Margin" Value="0,0,0,2"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="11" Opacity="0" IsHitTestVisible="False"/>
              <StackPanel Orientation="Horizontal" Margin="16,0,10,0" VerticalAlignment="Center">
                <TextBlock x:Name="ico" Text="{TemplateBinding Tag}" FontFamily="{StaticResource FontIcon}" FontSize="16"
                           Foreground="{TemplateBinding BorderBrush}" VerticalAlignment="Center" Margin="0,0,13,0"
                           RenderTransformOrigin="0.5,0.5">
                  <TextBlock.RenderTransform>
                    <ScaleTransform x:Name="isc" ScaleX="1" ScaleY="1"/>
                  </TextBlock.RenderTransform>
                </TextBlock>
                <ContentPresenter VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}"/>
              </StackPanel>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.05" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleX" To="1.14" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleY" To="1.14" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="isc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Listeneintrag mit Auswahl -->
    <Style x:Key="LbItem" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="12,9,12,9"/>
      <Setter Property="Margin" Value="0,0,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root">
              <Grid.RenderTransform>
                <TranslateTransform x:Name="tt" Y="0"/>
              </Grid.RenderTransform>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="11" Opacity="0"/>
              <Border x:Name="selb" Background="{DynamicResource BrSel}" BorderBrush="{DynamicResource BrSelStrong}" BorderThickness="1"
                      CornerRadius="11" Opacity="0"/>
              <ContentPresenter Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.30"/><DoubleAnimation Storyboard.TargetName="tt" Storyboard.TargetProperty="Y" From="10" To="0" Duration="0:0:0.30"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="selb" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.18"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Versionsliste: Eintraege liegen ohne Abstand aneinander, damit die Zeitleiste durchlaeuft -->
    <Style x:Key="LbItemLine" TargetType="ListBoxItem" BasedOn="{StaticResource LbItem}">
      <Setter Property="Padding" Value="8,0,12,0"/>
      <Setter Property="Margin" Value="0"/>
    </Style>

    <!-- Zeile ohne Auswahl (Mods, Inhalte, Backups): nur Hover -->
    <Style x:Key="LbRow" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Padding" Value="14,10,8,10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root" Margin="0,0,0,2">
              <Grid.RenderTransform>
                <TranslateTransform x:Name="tt" Y="0"/>
              </Grid.RenderTransform>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="11" Opacity="0"/>
              <ContentPresenter Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.28"/><DoubleAnimation Storyboard.TargetName="tt" Storyboard.TargetProperty="Y" From="8" To="0" Duration="0:0:0.28"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Spiele-Kachel: hebt sich beim Ueberfahren an, Auswahl = Akzentrahmen -->
    <Style x:Key="GameTile" TargetType="ListBoxItem">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource BrText}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Width" Value="150"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid x:Name="root" RenderTransformOrigin="0.5,0.5">
              <Grid.RenderTransform>
                <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
              </Grid.RenderTransform>
              <Border x:Name="bg" Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="16"/>
              <Border x:Name="hov" Background="{DynamicResource BrPanel2}" CornerRadius="16" Opacity="0"/>
              <Border x:Name="ring" BorderBrush="{DynamicResource BrAccent}" BorderThickness="2" CornerRadius="16" Opacity="0"/>
              <ContentPresenter Margin="9"/>
            </Grid>
            <ControlTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded"><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="root" Storyboard.TargetProperty="Opacity" From="0" To="1" Duration="0:0:0.30"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" From="0.94" To="1" Duration="0:0:0.32"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" From="0.94" To="1" Duration="0:0:0.32"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></EventTrigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Panel.ZIndex" Value="2"/>
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1.045" Duration="0:0:0.24"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.7"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1.045" Duration="0:0:0.24"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.7"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hov" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.2"/><DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.EnterActions>
                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="ring" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Spiel in den Seitenlisten (Mods, Updates/DLC, Spieldaten) -->
    <DataTemplate x:Key="GameRow">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid Width="38" Height="38" VerticalAlignment="Center">
          <Border CornerRadius="10" Background="{DynamicResource BrSelStrong}"/>
          <Border CornerRadius="10" Background="{Binding TileBrush}">
            <TextBlock Text="{Binding Initial}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="Bold"
                       Foreground="#F5FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <Border CornerRadius="10">
            <Border.Background>
              <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
            </Border.Background>
          </Border>
        </Grid>
        <StackPanel Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="13.5"
                     FontWeight="SemiBold" TextWrapping="Wrap" LineHeight="17"/>
          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Grid>
    </DataTemplate>
  </Window.Resources>

  <Grid x:Name="RootGrid" Background="{DynamicResource BrBg}">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="238"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Weiches Leuchten in den Theme-Farben hinter der Oberflaeche -->
    <Canvas Grid.ColumnSpan="2" IsHitTestVisible="False" ClipToBounds="True">
      <Ellipse Width="760" Height="760" Canvas.Left="-300" Canvas.Top="-380" Fill="{DynamicResource GlowA}"/>
      <Ellipse Width="900" Height="900" Canvas.Right="-360" Canvas.Bottom="-520" Fill="{DynamicResource GlowB}"/>
    </Canvas>

    <!-- ============ Seitenleiste ============ -->
    <Grid x:Name="SideBar" Grid.Column="0" Margin="14,18,6,18">
      <Grid.RenderTransform>
        <TranslateTransform/>
      </Grid.RenderTransform>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <StackPanel Orientation="Horizontal" Margin="10,2,0,0">
        <Grid Width="44" Height="44">
          <Border CornerRadius="13" Background="{DynamicResource GrAccent}" Margin="5,8,5,-2" Opacity="0.55" IsHitTestVisible="False">
            <Border.Effect>
              <BlurEffect Radius="14" KernelType="Gaussian"/>
            </Border.Effect>
          </Border>
          <Border CornerRadius="13" Background="{DynamicResource GrAccent}">
            <Viewbox>
              <Canvas Width="64" Height="64">
                <!-- Kreispfeil: dreht sich, solange etwas laeuft -->
                <Canvas x:Name="LogoRing" Width="64" Height="64" RenderTransformOrigin="0.5,0.5">
                  <Canvas.RenderTransform>
                    <RotateTransform Angle="0"/>
                  </Canvas.RenderTransform>
                  <Path Data="M 42.61,19.36 A 16.5,16.5 0 1 1 19.36,21.39" Stroke="{DynamicResource BrAccentFg}" StrokeThickness="5"
                        StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Path Data="M 24.5,15.26 L 14.76,17.53 L 23.96,25.25 Z" Fill="{DynamicResource BrAccentFg}"/>
                </Canvas>
                <Path Data="M 32,23 L 32,39 M 25.5,33.5 L 32,40 L 38.5,33.5" Stroke="{DynamicResource BrAccentFg}" StrokeThickness="5"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
              </Canvas>
            </Viewbox>
          </Border>
        </Grid>
        <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="EDEN" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="Bold"/>
          <TextBlock Text="UPDATER" FontFamily="{StaticResource FontHead}" FontSize="10.5" FontWeight="Bold"
                     Foreground="{DynamicResource BrAccentText}" Margin="1,-2,0,0"/>
        </StackPanel>
      </StackPanel>

      <Grid x:Name="NavHost" Grid.Row="1" Margin="0,28,0,0">
        <!-- Gleitende Markierung des aktiven Eintrags -->
        <Border x:Name="NavPill" Height="40" VerticalAlignment="Top" CornerRadius="11" Opacity="0"
                Background="{DynamicResource BrSel}" BorderBrush="{DynamicResource BrSelStrong}" BorderThickness="1">
          <Border.RenderTransform>
            <TranslateTransform Y="0"/>
          </Border.RenderTransform>
          <Border Width="3" Height="18" HorizontalAlignment="Left" Margin="-1,0,0,0" CornerRadius="2"
                  Background="{DynamicResource GrAccent}"/>
        </Border>
        <StackPanel>
          <Button x:Name="BtnNavVer"   Tag="&#xE8FD;" Content="{DynamicResource L_NavVersions}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavNotes" Tag="&#xE8A5;" Content="{DynamicResource L_NavNotes}"    Style="{StaticResource BtnNav}"/>
          <Border Height="1" Background="{DynamicResource BrLine}" Margin="16,9,16,10"/>
          <Button x:Name="BtnNavGames" Tag="&#xE7FC;" Content="{DynamicResource L_NavGames}"    Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavMods"  Tag="&#xEA86;" Content="{DynamicResource L_NavMods}"     Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavContent" Tag="&#xE7B8;" Content="{DynamicResource L_NavContent}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavSaves" Tag="&#xE74E;" Content="{DynamicResource L_NavSaves}"    Style="{StaticResource BtnNav}"/>
          <Border Height="1" Background="{DynamicResource BrLine}" Margin="16,9,16,10"/>
          <Button x:Name="BtnNavFw"    Tag="&#xE950;" Content="{DynamicResource L_NavFirmware}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavSet"   Tag="&#xE713;" Content="{DynamicResource L_NavSettings}" Style="{StaticResource BtnNav}"/>
        </StackPanel>
      </Grid>

      <!-- Installierte Version + Eden starten -->
      <Border Grid.Row="3" Style="{StaticResource Card}" Padding="14,12,14,14" Margin="0,0,8,0">
        <StackPanel>
          <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardInstalled}"/>
          <TextBlock x:Name="TxtSideVer" FontFamily="{StaticResource FontHead}" FontSize="13.5" FontWeight="SemiBold"
                     TextTrimming="CharacterEllipsis" Margin="0,3,0,0"
                     ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
          <Button x:Name="BtnLaunch" Tag="&#xE768;" Content="{DynamicResource L_BtnLaunch}"
                  Style="{StaticResource BtnTonal}" HorizontalContentAlignment="Center" Padding="12,10" Margin="0,12,0,0"/>
        </StackPanel>
      </Border>
    </Grid>

    <!-- ============ Hauptbereich ============ -->
    <Grid x:Name="MainArea" Grid.Column="1" Margin="14,18,26,18">
      <Grid.RenderTransform>
        <TranslateTransform/>
      </Grid.RenderTransform>
      <Grid.RowDefinitions>
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
        <StackPanel x:Name="HeadText" Grid.Column="0">
          <StackPanel.RenderTransform>
            <TranslateTransform/>
          </StackPanel.RenderTransform>
          <TextBlock x:Name="TxtPageTitle" FontFamily="{StaticResource FontHead}" FontSize="30" FontWeight="SemiBold"/>
          <TextBlock x:Name="TxtPageSub" Text="{DynamicResource L_AppSubtitle}" Foreground="{DynamicResource BrMuted}" Margin="1,2,0,0"
                     TextTrimming="CharacterEllipsis"/>
        </StackPanel>
        <!-- Update-Status oben rechts (Klick fuehrt zu den Versionen) -->
        <Border x:Name="ChipState" Grid.Column="1" CornerRadius="17" Padding="14,8" Margin="16,6,0,0"
                VerticalAlignment="Top" Visibility="Collapsed" BorderThickness="1" Cursor="Hand"
                Background="{DynamicResource BrBadgeNewBg}" BorderBrush="{DynamicResource BrLine}">
          <StackPanel Orientation="Horizontal">
            <Grid Width="10" Height="10" VerticalAlignment="Center">
              <Ellipse x:Name="DotRing" Fill="{Binding Fill, ElementName=DotState}" Opacity="0" RenderTransformOrigin="0.5,0.5">
                <Ellipse.RenderTransform>
                  <ScaleTransform ScaleX="1" ScaleY="1"/>
                </Ellipse.RenderTransform>
              </Ellipse>
              <Ellipse x:Name="DotState" Width="8" Height="8" Fill="{DynamicResource BrBadgeNewFg}"/>
            </Grid>
            <TextBlock x:Name="TxtChip" FontFamily="{StaticResource FontHead}" FontSize="12.5" FontWeight="Bold"
                       Margin="9,0,0,0" VerticalAlignment="Center" Foreground="{DynamicResource BrBadgeNewFg}"/>
          </StackPanel>
        </Border>
      </Grid>

      <!-- Inhalt -->
      <Grid Grid.Row="1" Margin="0,18,0,0">
        <!-- Seite: Versionen -->
        <Grid x:Name="PanelVersions">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
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

          <!-- Installiert -> Neueste -->
          <Border Grid.Row="0" Grid.ColumnSpan="2" CornerRadius="18" BorderThickness="1" Margin="0,0,0,14"
                  Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}">
            <Grid>
              <Border CornerRadius="17" Background="{DynamicResource GrHero}"/>
              <Grid Margin="24,18,20,18">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*" MinWidth="90"/>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*" MinWidth="90"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardInstalled}"/>
                  <TextBlock x:Name="TxtInstalled" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="21" FontWeight="SemiBold"
                             TextTrimming="CharacterEllipsis" Margin="0,5,0,0"/>
                </StackPanel>
                <!-- Pfeile laufen von links nach rechts, wenn ein Update wartet -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="18,16,20,0">
                  <TextBlock x:Name="Flow1" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.25" Foreground="{DynamicResource BrAccentText}"/>
                  <TextBlock x:Name="Flow2" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.5" Margin="-2,0,0,0" Foreground="{DynamicResource BrAccentText}"/>
                  <TextBlock x:Name="Flow3" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12" Opacity="0.9" Margin="-2,0,0,0" Foreground="{DynamicResource BrAccentText}"/>
                </StackPanel>
                <StackPanel Grid.Column="2" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_CardLatest}"/>
                  <TextBlock x:Name="TxtLatest" ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}" FontFamily="{StaticResource FontHead}" FontSize="21" FontWeight="SemiBold"
                             Foreground="{DynamicResource BrAccentText}" TextTrimming="CharacterEllipsis" Margin="0,5,0,0"/>
                </StackPanel>
                <Button x:Name="BtnUpdate" Grid.Column="3" Tag="&#xE896;" Content="{DynamicResource L_BtnUpdate}"
                        Style="{StaticResource BtnPrimary}" Padding="20,12" Margin="16,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Grid>
          </Border>

          <Grid Grid.Row="1" Grid.ColumnSpan="2" Margin="4,0,0,6">
            <TextBlock x:Name="TxtListInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="BtnReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnMore" Tag="&#xE70D;" Content="{DynamicResource L_BtnMore}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
            </StackPanel>
          </Grid>

          <Border Grid.Row="2" Style="{StaticResource Card}" Padding="8,10,6,10">
            <ListBox x:Name="List" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                     ItemContainerStyle="{StaticResource LbItemLine}"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
              <ListBox.ItemTemplate>
                <DataTemplate>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="26"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <!-- Zeitleiste: neueste = gruen, installiert = Akzent -->
                    <Rectangle Width="2" Fill="{DynamicResource BrLine}" HorizontalAlignment="Center"/>
                    <Ellipse Width="11" Height="11" Fill="{DynamicResource BrPanel}" Stroke="{DynamicResource BrMuted}" StrokeThickness="2"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <Ellipse Width="13" Height="13" Fill="{DynamicResource BrBadgeNewFg}" Visibility="{Binding NewBadge}"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <Ellipse Width="13" Height="13" Fill="{DynamicResource BrAccent}" Visibility="{Binding InstBadge}"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,10,0,10">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{Binding Tag}" Foreground="{DynamicResource BrText}" FontSize="14.5" FontWeight="SemiBold"
                                 TextTrimming="CharacterEllipsis"/>
                      <TextBlock Text="{Binding Date}" Foreground="{DynamicResource BrMuted}" FontSize="12" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Border Grid.Column="2" Visibility="{Binding NewBadge}" Background="{DynamicResource BrBadgeNewBg}"
                            CornerRadius="10" Padding="9,3" Margin="10,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardLatest}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrBadgeNewFg}"/>
                    </Border>
                    <Border Grid.Column="3" Visibility="{Binding InstBadge}" Background="{DynamicResource BrBadgeInstBg}"
                            CornerRadius="10" Padding="9,3" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardInstalled}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrAccentText}"/>
                    </Border>
                  </Grid>
                </DataTemplate>
              </ListBox.ItemTemplate>
            </ListBox>
          </Border>

          <Border x:Name="PanelNotesSide" Grid.Row="2" Grid.Column="1" Visibility="Collapsed" Style="{StaticResource Card}"
                  Padding="20,16" Margin="12,0,0,0"/>

          <StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,12,0,0">
            <Button x:Name="BtnInstallSel" Tag="&#xE896;" Content="{DynamicResource L_BtnInstallSel}" Style="{StaticResource Btn}"/>
            <Button x:Name="BtnRestore" Tag="&#xE81C;" Content="{DynamicResource L_BtnRestore}" Style="{StaticResource Btn}" Margin="8,0,0,0"/>
          </StackPanel>
        </Grid>

        <!-- Seite: Patchnotes -->
        <Border x:Name="PanelNotes" Visibility="Collapsed" Style="{StaticResource Card}" Padding="24,20">
          <Border.RenderTransform>
            <TranslateTransform/>
          </Border.RenderTransform>
          <Grid x:Name="NotesContent">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <StackPanel Margin="0,0,12,0">
                <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_NotesHeader}"/>
                <TextBlock FontFamily="{StaticResource FontHead}" x:Name="TxtNotesTitle" FontSize="20" FontWeight="SemiBold"
                           TextTrimming="CharacterEllipsis" Margin="0,4,0,0"/>
                <TextBlock x:Name="TxtNotesHint" Text="{DynamicResource L_NotesHintPage}" Style="{StaticResource Hint}" Margin="0,3,0,0"/>
              </StackPanel>
              <Button x:Name="BtnNotesWeb" Grid.Column="1" Tag="&#xE774;" Content="{DynamicResource L_NotesWeb}" Style="{StaticResource Btn}"
                      Padding="12,7" VerticalAlignment="Top"/>
            </Grid>
            <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
            <TextBox x:Name="TxtNotes" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" Margin="0,14,0,0"
                     VerticalScrollBarVisibility="Auto" Background="Transparent" BorderThickness="0"
                     Padding="0" FontSize="14"/>
          </Grid>
        </Border>

        <!-- Seite: Spiele (Kacheln) -->
        <Grid x:Name="PanelGames" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="0,0,0,14">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="3*" MaxWidth="300"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Grid>
              <TextBox x:Name="TxtGameSearch" Padding="36,8,10,8"/>
              <TextBlock Text="&#xE721;" FontFamily="{StaticResource FontIcon}" FontSize="13" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="13,0,0,0" IsHitTestVisible="False"/>
              <TextBlock x:Name="TxtGameSearchHint" Text="{DynamicResource L_GamesSearch}" Foreground="{DynamicResource BrMuted}"
                         VerticalAlignment="Center" Margin="37,0,0,0" IsHitTestVisible="False"/>
            </Grid>
            <!-- Reihenfolge: nach Name oder zuletzt gespielt -->
            <ComboBox x:Name="CmbGameSort" Grid.Column="1" SelectedValuePath="Tag" MinWidth="170" Margin="10,0,0,0" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
              <TextBlock x:Name="TxtGamesInfo" Style="{StaticResource Label}" VerticalAlignment="Center" Margin="12,0,8,0"/>
              <Button x:Name="BtnGamesReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}"/>
            </StackPanel>
          </Grid>

          <!-- Weiterspielen: das zuletzt gestartete Spiel (aus Edens launched.json) -->
          <Border x:Name="GameContinue" Grid.Row="1" Visibility="Collapsed" CornerRadius="16" BorderThickness="1" Margin="0,0,0,14"
                  Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}">
            <Grid>
              <Border CornerRadius="15" Background="{DynamicResource GrHero}"/>
              <Grid Margin="12,12,16,12">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Grid Width="58" Height="58">
                  <Border x:Name="ContTile" CornerRadius="12">
                    <Viewbox StretchDirection="DownOnly" Margin="7,0">
                      <TextBlock x:Name="ContAbbr" FontFamily="{StaticResource FontHead}" FontSize="24" FontWeight="Bold" Foreground="#F5FFFFFF"/>
                    </Viewbox>
                  </Border>
                  <Border x:Name="ContImg" CornerRadius="12"/>
                </Grid>
                <StackPanel Grid.Column="1" Margin="14,0,12,0" VerticalAlignment="Center">
                  <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GamesSortRecent}"/>
                  <TextBlock x:Name="TxtContName" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"
                             ToolTip="{Binding Text, RelativeSource={RelativeSource Self}}"/>
                  <TextBlock x:Name="TxtContInfo" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
                </StackPanel>
                <Button x:Name="BtnGameContinue" Grid.Column="2" Tag="&#xE768;" Content="{DynamicResource L_GamesContinue}"
                        Style="{StaticResource BtnPrimary}" Padding="18,11" VerticalAlignment="Center"/>
              </Grid>
            </Grid>
          </Border>

          <Grid Grid.Row="2">
            <ListBox x:Name="ListGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0" Padding="0"
                     ItemContainerStyle="{StaticResource GameTile}" Margin="-2,0,-8,0"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.CanContentScroll="False">
              <ListBox.ItemsPanel>
                <ItemsPanelTemplate>
                  <WrapPanel Margin="4,6,0,0"/>
                </ItemsPanelTemplate>
              </ListBox.ItemsPanel>
              <ListBox.ItemTemplate>
                <DataTemplate>
                  <StackPanel ToolTip="{Binding PlayedTip}" Background="Transparent">
                    <Grid Height="130">
                      <!-- Ohne Cover: Kuerzel aus dem Namen auf einer Farbe, die fuer jedes Spiel anders ist -->
                      <Border CornerRadius="10" Background="{Binding TileBrush}">
                        <Viewbox StretchDirection="DownOnly" Margin="12,0">
                          <TextBlock Text="{Binding Abbr}" FontFamily="{StaticResource FontHead}" FontSize="48" FontWeight="Bold"
                                     Foreground="#F5FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Viewbox>
                      </Border>
                      <Border CornerRadius="10">
                        <Border.Background>
                          <ImageBrush ImageSource="{Binding IconImg}" Stretch="UniformToFill"/>
                        </Border.Background>
                      </Border>
                      <!-- Favorit: Stern oben rechts, Klick schaltet um (Handler am ListGames, erkannt ueber Tag="fav") -->
                      <Button Tag="fav" Focusable="False" Cursor="Hand" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,6,6,0"
                              ToolTip="{DynamicResource L_GamesFavTip}">
                        <Button.Template>
                          <ControlTemplate TargetType="Button">
                            <Grid x:Name="g" Width="30" Height="30" Opacity="0" RenderTransformOrigin="0.5,0.5">
                              <Grid.RenderTransform>
                                <ScaleTransform x:Name="fsc" ScaleX="1" ScaleY="1"/>
                              </Grid.RenderTransform>
                              <Ellipse Fill="#B0101216"/>
                              <TextBlock x:Name="st" Text="&#xE734;" FontFamily="{StaticResource FontIcon}" FontSize="14"
                                         Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Grid>
                            <ControlTemplate.Triggers>
                              <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                <Setter TargetName="g" Property="Opacity" Value="0.9"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding IsFav}" Value="True">
                                <Setter TargetName="st" Property="Text" Value="&#xE735;"/>
                                <Setter TargetName="st" Property="Foreground" Value="#FFD166"/>
                                <Setter TargetName="g" Property="Opacity" Value="1"/>
                              </DataTrigger>
                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="g" Property="Opacity" Value="1"/>
                                <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleX" To="1.18" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleY" To="1.18" Duration="0:0:0.18"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.9"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                                <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.16"/><DoubleAnimation Storyboard.TargetName="fsc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.16"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Button.Template>
                      </Button>
                    </Grid>
                    <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="13.5" FontWeight="SemiBold"
                               TextWrapping="Wrap" LineHeight="17" Margin="2,9,2,0"/>
                    <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="2,2,2,1" TextTrimming="CharacterEllipsis"/>
                  </StackPanel>
                </DataTemplate>
              </ListBox.ItemTemplate>
            </ListBox>
            <TextBlock x:Name="TxtGamesEmpty" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                       HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="420" Visibility="Collapsed"/>
          </Grid>

          <Border Grid.Row="3" Style="{StaticResource Card}" Padding="12,10,18,10" Margin="0,10,0,0">
            <StackPanel Orientation="Horizontal">
              <Button x:Name="BtnGameStart" Tag="&#xE768;" Content="{DynamicResource L_GamesStart}" Style="{StaticResource BtnPrimary}" IsEnabled="False"/>
              <CheckBox x:Name="ChkGamesFull" Content="{DynamicResource L_GamesFull}" VerticalAlignment="Center" Margin="18,0,0,0"/>
              <CheckBox x:Name="ChkGamesClose" Content="{DynamicResource L_GamesClose}" VerticalAlignment="Center" Margin="20,0,0,0"/>
            </StackPanel>
          </Border>
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

          <Border x:Name="ModsBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
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
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,16,14">
                  <TextBlock x:Name="TxtModGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock x:Name="TxtModGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                             FontFamily="{StaticResource FontMono}" Margin="0,2,0,12"/>
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnModAdd" Tag="&#xE710;" Content="{DynamicResource L_ModsAdd}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnModFolder" Tag="&#xE838;" Content="{DynamicResource L_ModsFolder}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
                <ListBox x:Name="ListMods" Grid.Row="1" Margin="8,8,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                         ItemContainerStyle="{StaticResource LbRow}" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
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

        <!-- Seite: Updates/DLC (externe Inhaltsordner von Eden) -->
        <Grid x:Name="PanelContent" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <TextBlock x:Name="TxtContentInfo" Style="{StaticResource Label}" VerticalAlignment="Center"/>
            <Button x:Name="BtnContentReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" HorizontalAlignment="Right"/>
          </Grid>

          <Border x:Name="ContentBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListContentGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,16,14">
                  <TextBlock x:Name="TxtContentGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                  <TextBlock x:Name="TxtContentGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                             FontFamily="{StaticResource FontMono}" Margin="0,2,0,12"/>
                  <StackPanel Orientation="Horizontal">
                    <Button x:Name="BtnContentAdd" Tag="&#xE710;" Content="{DynamicResource L_ContentAdd}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnContentFolder" Tag="&#xE838;" Content="{DynamicResource L_ContentFolder}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}" VerticalAlignment="Top"/>
                <ListBox x:Name="ListContent" Grid.Row="1" Margin="8,8,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                         ItemContainerStyle="{StaticResource LbRow}" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                  <ListBox.ItemTemplate>
                    <DataTemplate>
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="Auto"/>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Uid="toggle" IsChecked="{Binding Enabled, Mode=OneWay}" VerticalAlignment="Center">
                          <CheckBox.Style>
                            <Style TargetType="CheckBox" BasedOn="{StaticResource Switch}">
                              <Style.Triggers>
                                <DataTrigger Binding="{Binding CanToggle}" Value="False">
                                  <Setter Property="Visibility" Value="Hidden"/>
                                </DataTrigger>
                              </Style.Triggers>
                            </Style>
                          </CheckBox.Style>
                        </CheckBox>
                        <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                          <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                     FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                          <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextWrapping="Wrap"/>
                        </StackPanel>
                        <Button Grid.Column="2" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_ContentDelete}" Style="{StaticResource BtnGhost}"
                                VerticalAlignment="Center"/>
                      </Grid>
                    </DataTemplate>
                  </ListBox.ItemTemplate>
                </ListBox>
                <TextBlock x:Name="TxtContentEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                           HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Visibility="Collapsed"/>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Spieldaten (Spielstaende + Shader-Cache) -->
        <Grid x:Name="PanelSaves" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="4,0,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtSavesInfo" Style="{StaticResource Label}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
              <Button x:Name="BtnShaderAll" Tag="&#xE74D;" Content="{DynamicResource L_SavesShaderAll}" Style="{StaticResource BtnGhost}" ToolTip="{DynamicResource L_SavesShaderHint}"/>
              <Button x:Name="BtnSaveBackupDir" Tag="&#xE838;" Content="{DynamicResource L_SavesBackupDir}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
              <Button x:Name="BtnSavesReload" Tag="&#xE72C;" Content="{DynamicResource L_BtnReload}" Style="{StaticResource BtnGhost}" Margin="4,0,0,0"/>
            </StackPanel>
          </Grid>

          <Border x:Name="SavesBanner" Grid.Row="1" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="290"/>
              <ColumnDefinition Width="12"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource Card}" Padding="8">
              <ListBox x:Name="ListSaveGames" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                       ItemContainerStyle="{StaticResource LbItem}" ItemTemplate="{StaticResource GameRow}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource Card}" Padding="0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border CornerRadius="15,15,0,0" Background="{DynamicResource GrHero}"/>
                <StackPanel Margin="20,16,14,10">
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center">
                      <TextBlock x:Name="TxtSaveGameTitle" FontFamily="{StaticResource FontHead}" FontSize="19" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                      <TextBlock x:Name="TxtSaveGameSub" Style="{StaticResource Hint}" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                                 FontFamily="{StaticResource FontMono}" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnSaveBackup" Grid.Column="1" Tag="&#xE74E;" Content="{DynamicResource L_SavesBackupNow}" Style="{StaticResource BtnPrimary}"
                            Padding="14,8" VerticalAlignment="Center" Margin="10,0,0,0"/>
                  </Grid>
                  <!-- Spielstand -->
                  <Grid Margin="0,12,0,0">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="&#xE74E;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TxtSaveState" Grid.Column="1" Foreground="{DynamicResource BrText}" FontSize="12.5" Margin="10,0,8,0"
                               VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                    <Button x:Name="BtnSaveFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_SavesOpenFolder}" Style="{StaticResource BtnGhost}"/>
                  </Grid>
                  <!-- Shader-Cache -->
                  <Grid Margin="0,2,0,0" ToolTip="{DynamicResource L_SavesShaderHint}" Background="Transparent">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Text="&#xE950;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                    <TextBlock x:Name="TxtShaderState" Grid.Column="1" Foreground="{DynamicResource BrText}" FontSize="12.5" Margin="10,0,8,0"
                               VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                    <Button x:Name="BtnShaderDelete" Grid.Column="2" Tag="&#xE74D;" Content="{DynamicResource L_SavesShaderDelete}" Style="{StaticResource BtnGhost}"/>
                  </Grid>
                </StackPanel>
                <Border Grid.Row="1" Height="1" Background="{DynamicResource BrLine}"/>
                <Grid Grid.Row="2">
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                  </Grid.RowDefinitions>
                  <TextBlock Text="{DynamicResource L_SavesBackupsTitle}" Style="{StaticResource Label}" Margin="20,12,0,2"/>
                  <ListBox x:Name="ListSaveBackups" Grid.Row="1" Margin="8,4,8,8" Foreground="{DynamicResource BrText}" Background="Transparent" BorderThickness="0"
                           ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                    <ListBox.ItemContainerStyle>
                      <Style TargetType="ListBoxItem" BasedOn="{StaticResource LbRow}">
                        <Setter Property="Padding" Value="12,8,8,8"/>
                      </Style>
                    </ListBox.ItemContainerStyle>
                    <ListBox.ItemTemplate>
                      <DataTemplate>
                        <Grid>
                          <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                          </Grid.ColumnDefinitions>
                          <TextBlock Text="&#xE81C;" FontFamily="{StaticResource FontIcon}" FontSize="16" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                          <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                            <TextBlock Text="{Binding Name}" Foreground="{DynamicResource BrText}" FontFamily="{StaticResource FontHead}" FontSize="14"
                                       FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                            <TextBlock Text="{Binding Info}" Foreground="{DynamicResource BrMuted}" FontSize="11.5" Margin="0,2,0,0" TextWrapping="Wrap"/>
                          </StackPanel>
                          <Button Grid.Column="2" Uid="restore" Tag="&#xE777;" Content="{DynamicResource L_SavesRestore}" Style="{StaticResource BtnGhost}"
                                  VerticalAlignment="Center"/>
                          <Button Grid.Column="3" Uid="delete" Tag="&#xE74D;" Content="{DynamicResource L_SavesDelete}" Style="{StaticResource BtnGhost}"
                                  VerticalAlignment="Center" Margin="4,0,0,0"/>
                        </Grid>
                      </DataTemplate>
                    </ListBox.ItemTemplate>
                  </ListBox>
                  <TextBlock x:Name="TxtSaveBackupsEmpty" Grid.Row="1" Style="{StaticResource Hint}" FontSize="13" TextAlignment="Center"
                             HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="360" Margin="0,0,0,20" Visibility="Collapsed"/>
                </Grid>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- Seite: Firmware und Schluessel -->
        <Grid x:Name="PanelFirmware" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Border x:Name="FwBanner" Grid.Row="0" Visibility="Collapsed" Style="{StaticResource Banner}" Margin="0,0,0,10">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
              <TextBlock Text="{DynamicResource L_SysEdenRunning}" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
              <!-- Firmware -->
              <Border Style="{StaticResource Card}">
                <StackPanel>
                  <Grid Margin="0,0,0,14">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}" Width="44" Height="44" CornerRadius="13">
                      <TextBlock Text="&#xE950;" Style="{StaticResource IconBadgeGlyph}" FontSize="20"/>
                    </Border>
                    <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_FwTitle}"/>
                      <TextBlock x:Name="TxtFwState" Style="{StaticResource FieldTitle}" FontSize="18" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnFwFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_FwFolder}" Style="{StaticResource BtnGhost}"
                            VerticalAlignment="Top"/>
                  </Grid>
                  <TextBlock x:Name="TxtFwSub" Style="{StaticResource Hint}"/>
                  <Border x:Name="FwWarn" Visibility="Collapsed" Style="{StaticResource Banner}" Padding="12,8" Margin="0,12,0,0">
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="&#xE7BA;" FontFamily="{StaticResource FontIcon}" FontSize="14" Foreground="{DynamicResource BrAccentText}" VerticalAlignment="Center"/>
                      <TextBlock x:Name="TxtFwWarn" Foreground="{DynamicResource BrText}" Margin="10,0,0,0" VerticalAlignment="Center" TextWrapping="Wrap"/>
                    </StackPanel>
                  </Border>
                  <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                    <Button x:Name="BtnFwZip" Tag="&#xE896;" Content="{DynamicResource L_FwInstallZip}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnFwDir" Tag="&#xE8B7;" Content="{DynamicResource L_FwInstallDir}" Style="{StaticResource Btn}" Padding="14,8" Margin="8,0,0,0"/>
                    <Button x:Name="BtnFwDelete" Tag="&#xE74D;" Content="{DynamicResource L_FwDelete}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                  <TextBlock Text="{DynamicResource L_FwHint}" Style="{StaticResource Hint}" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>

              <!-- Schluessel -->
              <Border Style="{StaticResource Card}" Margin="0,14,0,6">
                <StackPanel>
                  <Grid Margin="0,0,0,14">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}" Width="44" Height="44" CornerRadius="13">
                      <TextBlock Text="&#xE8D7;" Style="{StaticResource IconBadgeGlyph}" FontSize="20"/>
                    </Border>
                    <StackPanel Grid.Column="1" Margin="14,0,10,0" VerticalAlignment="Center">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_KeysTitle}"/>
                      <TextBlock x:Name="TxtKeysState" Style="{StaticResource FieldTitle}" FontSize="18" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnKeysFolder" Grid.Column="2" Tag="&#xE838;" Content="{DynamicResource L_FwFolder}" Style="{StaticResource BtnGhost}"
                            VerticalAlignment="Top"/>
                  </Grid>
                  <TextBlock x:Name="TxtKeysSub" Style="{StaticResource Hint}"/>
                  <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                    <Button x:Name="BtnKeysInstall" Tag="&#xE896;" Content="{DynamicResource L_KeysInstall}" Style="{StaticResource BtnPrimary}" Padding="14,8"/>
                    <Button x:Name="BtnKeysDelete" Tag="&#xE74D;" Content="{DynamicResource L_KeysDelete}" Style="{StaticResource BtnGhost}" Margin="8,0,0,0"/>
                  </StackPanel>
                  <TextBlock Text="{DynamicResource L_KeysHint}" Style="{StaticResource Hint}" Margin="0,14,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
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
            <StackPanel Margin="0,0,10,0">

              <!-- Installation -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Border Style="{StaticResource IconBadge}">
                      <TextBlock Text="&#xE8B7;" Style="{StaticResource IconBadgeGlyph}"/>
                    </Border>
                    <TextBlock Text="{DynamicResource L_GrpInstall}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
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

                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="3*"/>
                      <ColumnDefinition Width="18"/>
                      <ColumnDefinition Width="2*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                      <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetVariant}"/>
                      <ComboBox x:Name="CmbVariant" SelectedValuePath="Tag" Margin="0,7,0,4"/>
                      <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetVariantHint}"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                      <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPages}"/>
                      <TextBox x:Name="TxtPages" Width="90" HorizontalAlignment="Left" Margin="0,7,0,0"/>
                    </StackPanel>
                  </Grid>

                  <StackPanel x:Name="PanelPattern" Visibility="Collapsed" Margin="0,18,0,0">
                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetPattern}"/>
                    <TextBox x:Name="TxtPattern" Margin="0,7,0,0" FontFamily="{StaticResource FontMono}"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <Grid Margin="0,0,0,14">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Darstellung -->
                <Border Grid.Column="0" Style="{StaticResource Card}">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                      <Border Style="{StaticResource IconBadge}">
                        <TextBlock Text="&#xE790;" Style="{StaticResource IconBadgeGlyph}"/>
                      </Border>
                      <TextBlock Text="{DynamicResource L_GrpLook}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetTheme}"/>
                    <!-- Aktuelles Theme als kleine Vorschau; Klick oeffnet die Auswahl -->
                    <Button x:Name="BtnThemePick" Cursor="Hand" Margin="0,7,0,18" FocusVisualStyle="{x:Null}" HorizontalContentAlignment="Stretch">
                      <Button.Template>
                        <ControlTemplate TargetType="Button">
                          <Grid>
                            <Border x:Name="bd" Background="{DynamicResource BrPanel2}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="12" Padding="10">
                              <Grid>
                                <Grid.ColumnDefinitions>
                                  <ColumnDefinition Width="Auto"/>
                                  <ColumnDefinition Width="*"/>
                                  <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Border Width="62" Height="42" CornerRadius="9" Background="{DynamicResource BrBg}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1">
                                  <Grid>
                                    <Border Width="28" Height="9" CornerRadius="4.5" Background="{DynamicResource GrAccent}" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,9,0,0"/>
                                    <Border Width="40" Height="4" CornerRadius="2" Background="{DynamicResource BrText}" Opacity="0.8" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,25,0,0"/>
                                  </Grid>
                                </Border>
                                <ContentPresenter Grid.Column="1" Margin="13,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock x:Name="chev" Grid.Column="2" Text="&#xE76C;" FontFamily="{StaticResource FontIcon}" FontSize="12"
                                           Foreground="{DynamicResource BrMuted}" VerticalAlignment="Center" Margin="0,0,6,0">
                                  <TextBlock.RenderTransform>
                                    <TranslateTransform x:Name="cx" X="0"/>
                                  </TextBlock.RenderTransform>
                                </TextBlock>
                              </Grid>
                            </Border>
                            <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="12" Opacity="0" IsHitTestVisible="False"/>
                          </Grid>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                              <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BrAccent}"/>
                              <Setter TargetName="chev" Property="Foreground" Value="{DynamicResource BrAccentText}"/>
                              <Trigger.EnterActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0.04" Duration="0:0:0.15"/><DoubleAnimation Storyboard.TargetName="cx" Storyboard.TargetProperty="X" To="4" Duration="0:0:0.2"><DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction></DoubleAnimation></Storyboard></BeginStoryboard></Trigger.EnterActions>
                              <Trigger.ExitActions><BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="hl" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.22"/><DoubleAnimation Storyboard.TargetName="cx" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard></Trigger.ExitActions>
                            </Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </Button.Template>
                      <StackPanel>
                        <TextBlock x:Name="TxtThemeName" FontFamily="{StaticResource FontHead}" FontWeight="SemiBold" FontSize="14" TextTrimming="CharacterEllipsis"/>
                        <TextBlock Text="{DynamicResource L_SetThemePick}" Foreground="{DynamicResource BrAccentText}" FontSize="12" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                      </StackPanel>
                    </Button>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetLanguage}"/>
                    <ComboBox x:Name="CmbLang" SelectedValuePath="Tag" Margin="0,7,0,4" MaxDropDownHeight="380"/>
                    <TextBlock Style="{StaticResource Hint}" Text="{DynamicResource L_SetLanguageHint}" Margin="0,0,0,18"/>

                    <TextBlock Style="{StaticResource FieldTitle}" Text="{DynamicResource L_SetNotes}"/>
                    <ComboBox x:Name="CmbNotes" SelectedValuePath="Tag" Margin="0,7,0,0"/>
                  </StackPanel>
                </Border>

                <!-- Verhalten -->
                <Border Grid.Column="2" Style="{StaticResource Card}" Padding="20,20,20,12">
                  <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                      <Border Style="{StaticResource IconBadge}">
                        <TextBlock Text="&#xE9F5;" Style="{StaticResource IconBadgeGlyph}"/>
                      </Border>
                      <TextBlock Text="{DynamicResource L_GrpBehavior}" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>
                    <CheckBox x:Name="ChkBackup" Content="{DynamicResource L_ChkBackup}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkSaveAuto" Content="{DynamicResource L_ChkSaveAuto}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkStart" Content="{DynamicResource L_ChkStart}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkClose" Content="{DynamicResource L_ChkClose}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkAuto" Content="{DynamicResource L_ChkAuto}" Style="{StaticResource SwitchRow}"/>
                    <CheckBox x:Name="ChkAutoInstall" Content="{DynamicResource L_ChkAutoInstall}" Style="{StaticResource SwitchRow}"/>
                  </StackPanel>
                </Border>
              </Grid>

              <!-- Updater selbst -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,6" Padding="20,20,20,12">
                <StackPanel>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                      <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border Style="{StaticResource IconBadge}">
                      <TextBlock Text="&#xE895;" Style="{StaticResource IconBadgeGlyph}"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0,12,0">
                      <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpUpdater}"/>
                      <TextBlock x:Name="TxtSelfVersion" FontFamily="{StaticResource FontHead}" FontSize="16" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
                      <TextBlock x:Name="TxtSelfState" Style="{StaticResource Hint}" Margin="0,2,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                      <Button x:Name="BtnSelfNotes" Tag="&#xE774;" Content="{DynamicResource L_SelfBtnNotes}" Style="{StaticResource BtnGhost}"
                              Visibility="Collapsed" Margin="0,0,6,0"/>
                      <Button x:Name="BtnSelfCheck" Tag="&#xE72C;" Content="{DynamicResource L_SelfBtnCheck}" Style="{StaticResource Btn}" Padding="14,8"/>
                      <Button x:Name="BtnSelfInstall" Tag="&#xE896;" Content="{DynamicResource L_SelfBtnInstall}" Style="{StaticResource BtnPrimary}"
                              Padding="14,8" Margin="8,0,0,0" Visibility="Collapsed"/>
                    </StackPanel>
                  </Grid>
                  <CheckBox x:Name="ChkSelfUpdate" Content="{DynamicResource L_SelfChkStart}" Style="{StaticResource SwitchRow}" Margin="-10,12,-10,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </ScrollViewer>
          <Button x:Name="BtnSave" Grid.Row="1" Tag="&#xE74E;" Content="{DynamicResource L_Save}" Style="{StaticResource BtnPrimary}"
                  HorizontalAlignment="Left" Padding="22,10" Margin="0,12,0,0"/>
        </Grid>
      </Grid>

      <!-- Aktivitaet: Status, Fortschritt, aufklappbares Log -->
      <Border Grid.Row="2" Style="{StaticResource Card}" Padding="0" CornerRadius="14" Margin="0,14,0,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid Margin="16,7,8,7">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Ellipse x:Name="DotBusy" Width="8" Height="8" Fill="{DynamicResource BrMuted}" VerticalAlignment="Center"/>
            <TextBlock x:Name="TxtStatus" Grid.Column="1" Text="{DynamicResource L_StReady}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="11,0,0,0"/>
            <Button x:Name="BtnCancel" Grid.Column="2" Tag="&#xE711;" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"
                    Padding="12,5" Margin="8,0,0,0" Visibility="Collapsed"/>
            <Button x:Name="BtnLogToggle" Grid.Column="3" Tag="&#xE70D;" Content="{DynamicResource L_LogTitle}" Style="{StaticResource BtnGhost}"
                    Margin="8,0,0,0"/>
          </Grid>
          <ProgressBar x:Name="Pb" Grid.Row="1" Height="4" Minimum="0" Maximum="100" Value="0" Margin="16,0,16,10"
                       BorderThickness="0"/>
          <TextBox x:Name="TxtLog" Grid.Row="2" Height="130" Margin="12,0,12,12" IsReadOnly="True" Visibility="Collapsed"
                   FontFamily="{StaticResource FontMono}" FontSize="12" Background="{DynamicResource BrLog}"
                   VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
        </Grid>
      </Border>
    </Grid>

    <!-- Foto des alten Themes waehrend eines Theme-Wechsels (siehe New-ThemeReveal) -->
    <Image x:Name="ThemeFx" Grid.ColumnSpan="2" Visibility="Collapsed" IsHitTestVisible="False" Stretch="Fill"/>
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
    # Vorlagen mit eigenem Verlauf (Accent -> Accent2); ohne Accent2 wird die zweite Farbe berechnet
    "dark-aurora"   = @{ Base = "ThBaseDark";  Color = "ThColAurora"; Bg = "#0A1017"; Panel = "#111A24"; Text = "#E6EEF5"; Accent = "#2DD4BF"; Accent2 = "#8B5CF6" }
    "dark-sunset"   = @{ Base = "ThBaseDark";  Color = "ThColSunset"; Bg = "#140E12"; Panel = "#1F161B"; Text = "#F5EAEC"; Accent = "#FB923C"; Accent2 = "#EC4899" }
    "dark-synth"    = @{ Base = "ThBaseDark";  Color = "ThColSynth";  Bg = "#0F0B1A"; Panel = "#181228"; Text = "#EDE9F7"; Accent = "#F472B6"; Accent2 = "#22D3EE" }
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
# Einfarbige Pinsel und Verlaeufe, die dem Theme folgen (werden auch an Dialoge weitergegeben)
$script:ThemeSolid = @("BrBg","BrPanel","BrPanel2","BrCard","BrLine","BrText","BrMuted","BrAccent","BrAccent2","BrAccentFg","BrSel","BrSelStrong","BrLog","BrBadgeNewBg","BrBadgeNewFg","BrBadgeInstBg","BrAccentText")
$script:ThemeKeys  = $script:ThemeSolid + @("GrAccent","GrHero","GlowA","GlowB")
$script:ThemeAnimate = $false   # ab dem ersten Bild wird ein Theme-Wechsel animiert
$script:ThemeInstant = $false   # ohne Animation (z.B. beim Ziehen im Farbwaehler)
$script:ThemeFxOrigin = $null   # Punkt im Theme-Fenster, von dem aus sich das neue Theme ausbreitet
$script:ThemeFxGen = 0

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

function Get-AlphaColor($c, [int]$alpha) {
    return [System.Windows.Media.Color]::FromArgb([byte]$alpha, $c.R, $c.G, $c.B)
}

# Zweite Akzentfarbe fuer Verlaeufe: gleicher Ton, im Farbkreis ein Stueck weiter
# (warme Farben wandern Richtung Rot, kalte Richtung Blau/Violett)
function Get-Accent2($c) {
    $h = ConvertTo-Hsv $c
    if ($h.S -lt 0.08) { return (Merge-Color $c ([System.Windows.Media.Colors]::Gray) 0.35) }
    $shift = if ($h.H -lt 75 -or $h.H -ge 345) { -28 } else { 32 }
    return (ConvertFrom-Hsv ($h.H + $shift) $h.S $h.V)
}

# Pinsel werden bei jedem Theme-Wechsel neu angelegt und eingefroren
# (WPF friert Pinsel ein, sobald eine Vorlage sie nutzt - sie lassen sich danach nicht mehr aendern).
function Set-ThemeResource([string]$key, $value) {
    $window.Resources[$key] = $value
    if ($script:ThemeWin) { $script:ThemeWin.Resources[$key] = $value }
}

function Set-ThemeBrush([string]$key, $color) {
    $b = [System.Windows.Media.SolidColorBrush]::new($color)
    $b.Freeze()
    Set-ThemeResource $key $b
}

# Verlauf aus (Farbe, Position)-Paaren; $radial = kreisfoermig, sonst von links oben nach ($ex,$ey)
function Set-ThemeGradient([string]$key, [bool]$radial, [double]$ex, [double]$ey, $stops) {
    if ($radial) { $b = [System.Windows.Media.RadialGradientBrush]::new() }
    else {
        $b = [System.Windows.Media.LinearGradientBrush]::new()
        $b.StartPoint = [System.Windows.Point]::new(0, 0)
        $b.EndPoint   = [System.Windows.Point]::new($ex, $ey)
    }
    foreach ($st in $stops) { $b.GradientStops.Add([System.Windows.Media.GradientStop]::new($st[0], [double]$st[1])) }
    $b.Freeze()
    Set-ThemeResource $key $b
}

# Theme-Wechsel als "Welle": das Fenster wird mit dem alten Theme fotografiert, das Foto liegt kurz
# ueber der Oberflaeche und bekommt ein wachsendes Loch - darunter erscheint das neue Theme.
function New-ThemeReveal($win, $origin) {
    try {
        if (-not $win -or -not $win.IsVisible) { return $null }
        $root = $win.Content
        $img  = $win.FindName("ThemeFx")
        if (-not $img -or -not $root) { return $null }
        $w = [double]$root.ActualWidth; $h = [double]$root.ActualHeight
        if ($w -lt 2 -or $h -lt 2) { return $null }
        $scale = 1.0
        try {
            $src = [System.Windows.PresentationSource]::FromVisual($win)
            if ($src) { $scale = [double]$src.CompositionTarget.TransformToDevice.M11 }
        } catch {}
        $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new([int][Math]::Ceiling($w * $scale), [int][Math]::Ceiling($h * $scale), 96 * $scale, 96 * $scale, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($root)
        $rtb.Freeze()
        if (-not $origin) { $origin = [System.Windows.Point]::new($w / 2, $h / 2) }
        $hole = [System.Windows.Media.EllipseGeometry]::new($origin, 0, 0)
        $full = [System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0, 0, $w, $h))
        $img.Clip   = [System.Windows.Media.CombinedGeometry]::new([System.Windows.Media.GeometryCombineMode]::Exclude, $full, $hole)
        $img.Source = $rtb
        $img.Visibility = "Visible"
        $dx = [Math]::Max($origin.X, $w - $origin.X); $dy = [Math]::Max($origin.Y, $h - $origin.Y)
        return @{ Img = $img; Hole = $hole; Radius = [Math]::Sqrt($dx * $dx + $dy * $dy) + 4 }
    } catch { return $null }
}

function Start-ThemeReveal($fx) {
    if (-not $fx) { return }
    $script:ThemeFxGen++
    $img = $fx.Img
    $gen = $script:ThemeFxGen
    $img.Tag = $gen
    $a = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, [double]$fx.Radius, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(560)))
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseInOut
    $a.EasingFunction = $ease
    # Aufraeumen nur, wenn inzwischen kein neuerer Wechsel gestartet wurde
    $a.Add_Completed({
        if ($img.Tag -eq $gen) { $img.Visibility = "Collapsed"; $img.Source = $null; $img.Clip = $null }
    }.GetNewClosure())
    $fx.Hole.BeginAnimation([System.Windows.Media.EllipseGeometry]::RadiusXProperty, $a)
    $fx.Hole.BeginAnimation([System.Windows.Media.EllipseGeometry]::RadiusYProperty, $a)
}

# Aus 4 Grundfarben werden alle weiteren Farben abgeleitet.
# Lesbarkeit wird erzwungen: Text >= 4.5:1, gedaempfter Text und Akzent-Text >= 3:1.
$script:ThemeSig = $null
function Set-Theme($t) {
    $sig = "{0}|{1}|{2}|{3}|{4}" -f $t.Bg, $t.Panel, $t.Text, $t.Accent, $t.Accent2
    if ($sig -eq $script:ThemeSig) {
        $script:ThemeFxOrigin = $null
        if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
        return
    }
    $script:ThemeSig = $sig
    # altes Aussehen festhalten (nur wenn animiert werden soll)
    $fx = @()
    if ($script:ThemeAnimate -and -not $script:ThemeInstant -and -not $script:Snapshot) {
        $fx += New-ThemeReveal $window $null
        if ($script:ThemeWin) { $fx += New-ThemeReveal $script:ThemeWin $script:ThemeFxOrigin }
    }
    $script:ThemeFxOrigin = $null
    $bg     = ConvertTo-WpfColor $t.Bg     "#0F1419"
    $panel  = ConvertTo-WpfColor $t.Panel  "#171D26"
    $text   = ConvertTo-WpfColor $t.Text   "#E6EDF3"
    $accent = ConvertTo-WpfColor $t.Accent "#22D3EE"
    $black  = [System.Windows.Media.Colors]::Black
    $white  = [System.Windows.Media.Colors]::White
    $light  = ((Get-RelLum $panel) -gt 0.18)
    $amoled = ((Get-RelLum $bg) -lt 0.002)

    $text       = Get-Readable (Get-Readable $text $panel 4.5) $bg 4.5
    $panel2     = Merge-Color $panel $text 0.045
    $line       = Merge-Color $panel $text $(if ($light) { 0.16 } else { 0.14 })
    $muted      = Get-Readable (Merge-Color $text $panel 0.42) $panel 3.0
    $accentText = Get-Readable $accent $panel 3.0
    $accent2    = if ($t.Accent2) { ConvertTo-WpfColor $t.Accent2 "#22D3EE" } else { Get-Accent2 $accent }
    $sel        = Merge-Color $panel $accent 0.18
    $selStrong  = Merge-Color $panel2 $accent 0.32
    $log        = if ($light) { Merge-Color $panel $text 0.03 } else { Merge-Color $bg $black 0.35 }
    # Schrift auf dem Akzent-Verlauf muss auf beiden Enden lesbar sein
    $darkFg     = Merge-Color $accent $black 0.88
    $cWhite     = [Math]::Min((Get-Contrast $white $accent), (Get-Contrast $white $accent2))
    $cDark      = [Math]::Min((Get-Contrast $darkFg $accent), (Get-Contrast $darkFg $accent2))
    $accentFg   = if ($cWhite -ge $cDark) { $white } else { $darkFg }
    $green      = ConvertTo-WpfColor "#34D399" "#34D399"
    $greenBg    = Merge-Color $panel $green 0.20
    $greenFg    = Get-Readable $green $greenBg 3.0

    Set-ThemeBrush "BrBg"          $bg
    Set-ThemeBrush "BrPanel"       $panel
    Set-ThemeBrush "BrPanel2"      $panel2
    Set-ThemeBrush "BrCard"        (Get-AlphaColor $panel $(if ($light) { 0xEB } else { 0xD9 }))
    Set-ThemeBrush "BrLine"        $line
    Set-ThemeBrush "BrText"        $text
    Set-ThemeBrush "BrMuted"       $muted
    Set-ThemeBrush "BrAccent"      $accent
    Set-ThemeBrush "BrAccent2"     $accent2
    Set-ThemeBrush "BrAccentText"  $accentText
    Set-ThemeBrush "BrAccentFg"    $accentFg
    Set-ThemeBrush "BrSel"         $sel
    Set-ThemeBrush "BrSelStrong"   $selStrong
    Set-ThemeBrush "BrLog"         $log
    Set-ThemeBrush "BrBadgeNewBg"  $greenBg
    Set-ThemeBrush "BrBadgeNewFg"  $greenFg
    Set-ThemeBrush "BrBadgeInstBg" (Merge-Color $panel $accent 0.20)

    # Verlaeufe: Akzent -> zweite Akzentfarbe, dazu das Leuchten im Hintergrund (auf reinem Schwarz dezenter)
    $aGlowA = if ($amoled) { 0x24 } elseif ($light) { 0x30 } else { 0x36 }
    $aGlowB = if ($amoled) { 0x18 } elseif ($light) { 0x22 } else { 0x26 }
    $aHero  = if ($light) { 0x24 } else { 0x2C }
    Set-ThemeGradient "GrAccent" $false 1 1 @(@($accent, 0), @($accent2, 1))
    Set-ThemeGradient "GrHero"   $false 1 0 @(@((Get-AlphaColor $accent $aHero), 0), @((Get-AlphaColor $accent2 ([int]($aHero * 0.3))), 0.55), @((Get-AlphaColor $accent2 0), 1))
    Set-ThemeGradient "GlowA"    $true  0 0 @(@((Get-AlphaColor $accent $aGlowA), 0), @((Get-AlphaColor $accent 0), 1))
    Set-ThemeGradient "GlowB"    $true  0 0 @(@((Get-AlphaColor $accent2 $aGlowB), 0), @((Get-AlphaColor $accent2 0), 1))

    $script:ThemeColors = @{ Bg = $bg; Text = $text; Line = $line; Dark = (-not $light) }
    Set-TitleBar $window
    if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
    if (-not $window.Icon) { try { $window.Icon = New-AppIcon } catch {} }
    foreach ($f in $fx) { Start-ThemeReveal $f }
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
    $c = @{ Bg = $p.Bg; Panel = $p.Panel; Text = $p.Text; Accent = $p.Accent }
    if ($p.Accent2) { $c.Accent2 = $p.Accent2 }
    return $c
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
  <Grid Background="{DynamicResource BrBg}">
  <Canvas IsHitTestVisible="False" ClipToBounds="True">
    <Ellipse Width="620" Height="620" Canvas.Left="-260" Canvas.Top="-340" Fill="{DynamicResource GlowA}"/>
    <Ellipse Width="700" Height="700" Canvas.Right="-300" Canvas.Bottom="-420" Fill="{DynamicResource GlowB}"/>
  </Canvas>
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
                <Border Background="{DynamicResource BrCard}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="2"
                        CornerRadius="13" Padding="12,10">
                  <ContentPresenter/>
                </Border>
                <Border x:Name="hl" Background="{DynamicResource BrText}" CornerRadius="13" Opacity="0" IsHitTestVisible="False"/>
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
      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_ThemeTitle}" FontSize="26" FontWeight="SemiBold" Margin="0,2,0,3"/>
      <TextBlock x:Name="TxtDlgHint" Style="{StaticResource Hint}"/>
    </StackPanel>

    <Border Grid.Row="1" Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1"
            CornerRadius="14" Padding="4" HorizontalAlignment="Left" Margin="0,16,0,16">
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
        <Border Background="{DynamicResource BrCard}" BorderBrush="{DynamicResource BrLine}" BorderThickness="1" CornerRadius="13"
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
  <Image x:Name="ThemeFx" Visibility="Collapsed" IsHitTestVisible="False" Stretch="Fill"/>
  </Grid>
</Window>
'@

$themeCardXaml = @'
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Tag="@@KEY@@" Width="164" Height="120" Margin="0,0,12,12" Padding="0" Cursor="Hand" FocusVisualStyle="{x:Null}"
        BorderThickness="2" BorderBrush="Transparent" Background="Transparent">
  <Button.Template>
    <ControlTemplate TargetType="Button">
      <Grid RenderTransformOrigin="0.5,0.5">
        <Grid.RenderTransform>
          <ScaleTransform x:Name="sc" ScaleX="1" ScaleY="1"/>
        </Grid.RenderTransform>
        <Border Background="@@BG@@" CornerRadius="14" BorderBrush="#38808080" BorderThickness="1"/>
        <Grid Margin="10,10,10,8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="28"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Margin="1,3,0,0">
              <Border Width="15" Height="15" CornerRadius="5" HorizontalAlignment="Left">
                <Border.Background>
                  <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="@@ACCENT@@" Offset="0"/>
                    <GradientStop Color="@@ACCENT2@@" Offset="1"/>
                  </LinearGradientBrush>
                </Border.Background>
              </Border>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@ACCENT@@" Margin="0,9,0,0" HorizontalAlignment="Left"/>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@TEXT@@" Opacity="0.3" Margin="0,6,0,0" HorizontalAlignment="Left"/>
              <Border Width="17" Height="3" CornerRadius="1.5" Background="@@TEXT@@" Opacity="0.3" Margin="0,6,0,0" HorizontalAlignment="Left"/>
            </StackPanel>
            <Border Grid.Column="1" Background="@@PANEL@@" CornerRadius="8" Padding="9,8,8,7" BorderBrush="#20808080" BorderThickness="1">
              <StackPanel>
                <Border Background="@@TEXT@@" Height="5" Width="52" CornerRadius="2.5" HorizontalAlignment="Left" Opacity="0.9"/>
                <Border Background="@@TEXT@@" Height="3" Width="80" CornerRadius="1.5" HorizontalAlignment="Left" Margin="0,7,0,0" Opacity="0.4"/>
                <Border Background="@@TEXT@@" Height="3" Width="60" CornerRadius="1.5" HorizontalAlignment="Left" Margin="0,5,0,0" Opacity="0.4"/>
                <Border Height="11" Width="46" CornerRadius="5.5" HorizontalAlignment="Left" Margin="0,9,0,0">
                  <Border.Background>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                      <GradientStop Color="@@ACCENT@@" Offset="0"/>
                      <GradientStop Color="@@ACCENT2@@" Offset="1"/>
                    </LinearGradientBrush>
                  </Border.Background>
                </Border>
              </StackPanel>
            </Border>
          </Grid>
          <TextBlock FontFamily="{DynamicResource FontHead}" Grid.Row="1" Text="@@LABEL@@" Foreground="@@TEXT@@" FontSize="11.5" FontWeight="SemiBold"
                     Margin="2,7,0,0" TextTrimming="CharacterEllipsis"/>
        </Grid>
        <Border CornerRadius="14" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"/>
      </Grid>
      <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Panel.ZIndex" Value="2"/>
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1.05" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1.05" Duration="0:0:0.22"><DoubleAnimation.EasingFunction><BackEase EasingMode="EaseOut" Amplitude="0.8"/></DoubleAnimation.EasingFunction></DoubleAnimation>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
          <Trigger.ExitActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="1" Duration="0:0:0.16"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="1" Duration="0:0:0.16"/>
            </Storyboard></BeginStoryboard>
          </Trigger.ExitActions>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleX" To="0.97" Duration="0:0:0.08"/>
              <DoubleAnimation Storyboard.TargetName="sc" Storyboard.TargetProperty="ScaleY" To="0.97" Duration="0:0:0.08"/>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
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
        $script:Draft.Remove("Accent2")
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
        $script:ThemeInstant = $true
        try { Set-Theme $script:Draft } finally { $script:ThemeInstant = $false }
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
        $cx = $themeCardXaml.Replace('@@KEY@@', $k).Replace('@@BG@@', $p.Bg).Replace('@@PANEL@@', $p.Panel).Replace('@@TEXT@@', $p.Text).Replace('@@ACCENT@@', $p.Accent).Replace('@@ACCENT2@@', $(if ($p.Accent2) { $p.Accent2 } else { $p.Accent })).Replace('@@LABEL@@', [System.Security.SecurityElement]::Escape((T $p.Color)))
        $btn = [Windows.Markup.XamlReader]::Parse($cx)
        $btn.Add_Click({
            param($sender, $e)
            try {
                $script:ThemePick = [string]$sender.Tag
                $script:Draft = Get-ThemeColors $script:ThemePick
                try { $script:ThemeFxOrigin = $sender.TranslatePoint([System.Windows.Point]::new($sender.ActualWidth / 2, $sender.ActualHeight / 2), $script:ThemeWin.Content) } catch {}
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
    if ($tab -eq "custom" -and $script:ThemePick -ne "custom") { $script:Draft.Remove("Accent2"); $script:ThemePick = "custom"; Update-ThemeCards }
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
        Title="Eden Updater" Width="480" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" Foreground="{DynamicResource BrText}">
  __RES__
  <Grid>
    <Canvas IsHitTestVisible="False" ClipToBounds="True">
      <Ellipse Width="460" Height="460" Canvas.Left="-230" Canvas.Top="-300" Fill="{DynamicResource GlowA}"/>
    </Canvas>
    <Grid Margin="24,24,22,20">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="MsgBar" Width="44" Height="44" CornerRadius="14" VerticalAlignment="Top" Margin="0,0,16,0"
              Background="{DynamicResource BrSel}">
        <TextBlock x:Name="MsgGlyph" Text="&#xE897;" FontFamily="{StaticResource FontIcon}" FontSize="20"
                   Foreground="{DynamicResource BrAccentText}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <StackPanel Grid.Column="1">
        <TextBlock x:Name="MsgTitle" FontFamily="{StaticResource FontHead}" FontSize="18" FontWeight="SemiBold" Margin="0,1,0,8"/>
        <TextBlock x:Name="MsgText" TextWrapping="Wrap" Foreground="{DynamicResource BrText}"/>
        <StackPanel x:Name="MsgButtons" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,24,0,0"/>
      </StackPanel>
    </Grid>
  </Grid>
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
    # Icon-Feld: Akzentfarbe, bei Warnung gelb, bei Fehler rot
    $bar   = $d.FindName("MsgBar")
    $glyph = $d.FindName("MsgGlyph")
    $glyphs = @{ Warning = 0xE7BA; Error = 0xE783; Question = 0xE897; Information = 0xE946 }
    if ($glyph -and $glyphs.ContainsKey($icon)) { $glyph.Text = [string][char]$glyphs[$icon] }
    $tone = if ($icon -eq "Warning") { "#F59E0B" } elseif ($icon -eq "Error") { "#EF4444" } else { $null }
    if ($tone) {
        $tc = ConvertTo-WpfColor $tone $tone
        $bar.Background = [System.Windows.Media.SolidColorBrush]::new((Get-AlphaColor $tc 0x38))
        if ($glyph) { $glyph.Foreground = [System.Windows.Media.SolidColorBrush]::new($tc) }
    }

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

# Ordnerauswahl (WinForms) mit dem Updater-Fenster als Besitzer, sonst kann sie hinter dem Fenster aufgehen
function Show-FolderDialog([string]$desc, [string]$start) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $desc
    if ($start -and (Test-Path -LiteralPath $start)) { $dlg.SelectedPath = $start }
    $own = New-Object System.Windows.Forms.NativeWindow
    try {
        $h = [IntPtr]::Zero
        try { if ($window) { $h = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle } } catch {}
        if ($h -ne [IntPtr]::Zero) { $own.AssignHandle($h); $res = $dlg.ShowDialog($own) } else { $res = $dlg.ShowDialog() }
        if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
        return $null
    } finally {
        try { $own.ReleaseHandle() } catch {}
        $dlg.Dispose()
    }
}

function Show-Msg([string]$text, [string]$icon = "Warning") {
    [void](Show-Dialog $text "OK" $icon)
}

$script:LogOpen = $false
function Set-LogVisible([bool]$show) {
    $hp   = [System.Windows.FrameworkElement]::HeightProperty
    $full = 130.0
    if ($show -and $script:LogOpen -and $ui.TxtLog.Visibility -eq "Visible") { return }
    $script:LogOpen = $show
    $ui.BtnLogToggle.Tag = [string][char]$(if ($show) { 0xE70E } else { 0xE70D })
    if ($script:Snapshot -or -not $script:Initialized) {
        $ui.TxtLog.BeginAnimation($hp, $null)
        $ui.TxtLog.Height = $full
        $ui.TxtLog.Visibility = if ($show) { "Visible" } else { "Collapsed" }
        if ($show) { $ui.TxtLog.ScrollToEnd() }
        return
    }
    $ease = [System.Windows.Media.Animation.CubicEase]::new()
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    if ($show) {
        $from = if ($ui.TxtLog.Visibility -eq "Visible") { $ui.TxtLog.ActualHeight } else { 0.0 }
        $ui.TxtLog.Visibility = "Visible"
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new($from, $full, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(260)))
        $a.EasingFunction = $ease
        $ui.TxtLog.BeginAnimation($hp, $a)
        $ui.TxtLog.ScrollToEnd()
    } else {
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new($ui.TxtLog.ActualHeight, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220)))
        $a.EasingFunction = $ease
        $a.Add_Completed({ if (-not $script:LogOpen) { $ui.TxtLog.Visibility = "Collapsed" } })
        $ui.TxtLog.BeginAnimation($hp, $a)
    }
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
    $sc   = $ui.DotRing.RenderTransform
    $sx   = [System.Windows.Media.ScaleTransform]::ScaleXProperty
    $sy   = [System.Windows.Media.ScaleTransform]::ScaleYProperty
    if ($on -and -not $script:Snapshot) {
        $forever = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $a = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 0.45, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(800)))
        $a.AutoReverse = $true; $a.RepeatBehavior = $forever
        $ui.DotState.BeginAnimation($prop, $a)
        $dur = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1600))
        $grow = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 3.0, $dur); $grow.RepeatBehavior = $forever
        $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(0.55, 0.0, $dur); $fade.RepeatBehavior = $forever
        $sc.BeginAnimation($sx, $grow); $sc.BeginAnimation($sy, $grow)
        $ui.DotRing.BeginAnimation($prop, $fade)
    } else {
        $ui.DotState.BeginAnimation($prop, $null)
        $ui.DotState.Opacity = 1
        $sc.BeginAnimation($sx, $null); $sc.BeginAnimation($sy, $null)
        $ui.DotRing.BeginAnimation($prop, $null)
    }
}

# Solange etwas laeuft: Logo-Pfeil dreht sich, Statuspunkt unten pulsiert in Akzentfarbe
$script:BusyShown = $null
function Set-BusyVisual([bool]$busy) {
    if ($null -ne $script:BusyShown -and $script:BusyShown -eq $busy) { return }
    $script:BusyShown = $busy
    $rot  = $ui.LogoRing.RenderTransform
    $ap   = [System.Windows.Media.RotateTransform]::AngleProperty
    $op   = [System.Windows.UIElement]::OpacityProperty
    $fill = [System.Windows.Shapes.Shape]::FillProperty
    if ($busy) {
        $ui.DotBusy.SetResourceReference($fill, "BrAccent")
        if ($script:Snapshot) { return }
        $forever = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $spin = [System.Windows.Media.Animation.DoubleAnimation]::new(0.0, 360.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1100)))
        $spin.RepeatBehavior = $forever
        $rot.BeginAnimation($ap, $spin)
        $pulse = [System.Windows.Media.Animation.DoubleAnimation]::new(1.0, 0.3, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(600)))
        $pulse.AutoReverse = $true; $pulse.RepeatBehavior = $forever
        $ui.DotBusy.BeginAnimation($op, $pulse)
    } else {
        $ui.DotBusy.SetResourceReference($fill, "BrMuted")
        $ui.DotBusy.BeginAnimation($op, $null)
        if ($script:Snapshot) { return }
        # Drehung sauber bis zur vollen Runde auslaufen lassen
        $cur = [double]$rot.Angle % 360
        $end = [System.Windows.Media.Animation.DoubleAnimation]::new($cur, 360.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(520)))
        $ease = [System.Windows.Media.Animation.CubicEase]::new()
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $end.EasingFunction = $ease
        $end.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
        $rot.BeginAnimation($ap, $end)
    }
}

# Pfeile zwischen "installiert" und "neueste" laufen, solange ein Update wartet
$script:FlowOn = $null
function Set-FlowAnim([bool]$on) {
    if ($null -ne $script:FlowOn -and $script:FlowOn -eq $on) { return }
    $script:FlowOn = $on
    $op = [System.Windows.UIElement]::OpacityProperty
    $i = 0
    foreach ($f in @($ui.Flow1, $ui.Flow2, $ui.Flow3)) {
        if ($on -and -not $script:Snapshot) {
            $a = [System.Windows.Media.Animation.DoubleAnimation]::new(0.15, 1.0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(520)))
            $a.AutoReverse = $true
            $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $a.BeginTime = [TimeSpan]::FromMilliseconds(180 * $i)
            $f.BeginAnimation($op, $a)
        } else {
            $f.BeginAnimation($op, $null)
        }
        $i++
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
    $ui.TxtSideVer.Text = $ui.TxtInstalled.Text
    try { Set-BusyVisual ([bool]$busy); Set-FlowAnim ([bool]$script:UpdateAvailable) } catch {}
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
    try { Move-NavPill $false } catch {}
    if (Test-NotesVisible) { try { Show-Notes } catch {} }
}

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
                    $bi.DecodePixelWidth = 192
                    $bi.UriSource        = [Uri]::new([string]$g.Icon)
                    $bi.EndInit()
                    $bi.Freeze()
                    $img = $bi
                } catch {}
            }
            $g | Add-Member -NotePropertyName IconImg -NotePropertyValue $img -Force
            $g | Add-Member -NotePropertyName IsFav -NotePropertyValue (Test-GameFav $g) -Force
            Add-GameTileProps $g
        }
        $script:Games     = @($r.Games)
        Read-LaunchData
        Set-GameLaunchProps
        if ($r.CacheNames) { $script:CacheNames = $r.CacheNames }
        $script:GamesDirs = [int]$r.Dirs
    } else {
        $script:Games = @()
        $script:GamesDirs = 0
        if ($r) { Add-UiLog ((T "ErrPrefix") + " " + $r.Error) }
    }
    Update-GameList
    if ($script:ModsLoaded) { Update-ModGames }
    if ($script:ContentLoaded) { Update-ContentGames }
    if ($script:SavesLoaded) { Update-SaveGames }
}

# Kuerzel fuer Spiele ohne Cover: Anfangsbuchstaben der Woerter, Zahlen bleiben erhalten
# ("Xenoblade Chronicles 3" -> "XC3", "Mario and Luigi Brothership" -> "MLB")
function Get-GameAbbr([string]$name) {
    $out = ""
    foreach ($m in [regex]::Matches([string]$name, '[\p{L}\p{N}]+')) {
        $w = $m.Value
        if ($w -match '^\d+$') { $out += $w.Substring(0, [Math]::Min(2, $w.Length)) }
        elseif ($w -cmatch '^(and|the|of|for|und|der|die|das|no|de|la|le)$') { continue }
        else { $out += $w.Substring(0, 1).ToUpper() }
        if ($out.Length -ge 4) { break }
    }
    if (-not $out) { return "?" }
    return $out.Substring(0, [Math]::Min(4, $out.Length))
}

# Farbverlauf, der sich aus dem Namen ergibt: gleiches Spiel = immer gleiche Farbe
$script:TileBrushes = @{}
function Get-GameTileBrush([string]$name) {
    # Pruefsumme breit streuen, damit sich auch "... 2" und "... 3" deutlich unterscheiden
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { $sum = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes(([string]$name).ToLowerInvariant())) } finally { $md5.Dispose() }
    $h = (([int]$sum[0] * 256) + [int]$sum[1]) % 360
    if (-not $script:TileBrushes.ContainsKey($h)) {
        $b = [System.Windows.Media.LinearGradientBrush]::new()
        $b.StartPoint = [System.Windows.Point]::new(0, 0)
        $b.EndPoint   = [System.Windows.Point]::new(1, 1)
        $b.GradientStops.Add([System.Windows.Media.GradientStop]::new((ConvertFrom-Hsv $h 0.60 0.66), 0))
        $b.GradientStops.Add([System.Windows.Media.GradientStop]::new((ConvertFrom-Hsv ($h + 38) 0.72 0.36), 1))
        $b.Freeze()
        $script:TileBrushes[$h] = $b
    }
    return $script:TileBrushes[$h]
}

function Add-GameTileProps($g) {
    $g | Add-Member -NotePropertyName Abbr      -NotePropertyValue (Get-GameAbbr $g.Name) -Force
    $g | Add-Member -NotePropertyName TileBrush -NotePropertyValue (Get-GameTileBrush $g.Name) -Force
}

# Liegt das angeklickte Element in einem Listeneintrag (und nicht im leeren Bereich der Liste)?
function Test-InListItem($src) {
    $d = $src
    while ($d) {
        if ($d -is [System.Windows.Controls.ListBoxItem]) { return $true }
        $d = if ($d -is [System.Windows.Media.Visual]) { [System.Windows.Media.VisualTreeHelper]::GetParent($d) } else { $null }
    }
    return $false
}

# ---- Zuletzt gespielt: Eden fuehrt in <Daten>\cache\launched.json pro Title-ID Startzahl und Zeitpunkt ----
$script:LaunchData  = @{}
$script:LaunchStamp = $null
function Get-LaunchFile { return (Join-Path (Get-EdenDataDir) "cache\launched.json") }

function Read-LaunchData {
    $d = @{}
    $stamp = $null
    try {
        $p = Get-LaunchFile
        if (Test-Path -LiteralPath $p) {
            $stamp = (Get-Item -LiteralPath $p).LastWriteTimeUtc
            $j = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($pr in $j.PSObject.Properties) {
                $ts = 0L
                try { $ts = [long]$pr.Value.timestamp } catch {}
                $n = 0
                try { $n = [int]$pr.Value.launch_count } catch {}
                $d[$pr.Name.ToUpperInvariant()] = @{ Count = $n; Time = $(if ($ts -gt 0) { [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime } else { $null }) }
            }
        }
    } catch {}
    $script:LaunchData  = $d
    $script:LaunchStamp = $stamp
}

# "08.11.2026  ·  202× gestartet" (Datum in der Schreibweise der gewaehlten Sprache)
function Get-PlayedText($g) {
    $parts = @()
    if ($g.LastPlayed) {
        $cul = $null
        try { $cul = [Globalization.CultureInfo]::GetCultureInfo([string]$script:LangCulture) } catch {}
        $parts += $(if ($cul) { $g.LastPlayed.ToString("d", $cul) } else { $g.LastPlayed.ToString("d") })
    }
    if ([int]$g.LaunchCount -gt 0) { $parts += (TF "GamesLaunches" ([int]$g.LaunchCount)) }
    return ($parts -join "  ·  ")
}

# Startdaten an die Spiele haengen (Zuordnung ueber die Title-ID)
function Set-GameLaunchProps {
    foreach ($g in @($script:Games)) {
        $e = $null
        if ($g.Tid) { $e = $script:LaunchData[([string]$g.Tid).ToUpperInvariant()] }
        $g | Add-Member -NotePropertyName LastPlayed  -NotePropertyValue $(if ($e) { $e.Time } else { $null }) -Force
        $g | Add-Member -NotePropertyName LaunchCount -NotePropertyValue $(if ($e) { [int]$e.Count } else { 0 }) -Force
        $txt = Get-PlayedText $g
        $g | Add-Member -NotePropertyName PlayedTip -NotePropertyValue $(if ($g.LastPlayed) { TF "GamesLastPlayed" $txt } elseif ($txt) { $txt } else { $null }) -Force
    }
}

# Hat Eden seit dem letzten Lesen etwas gestartet? Dann Liste und "Weiterspielen" auffrischen
function Update-LaunchDataIfChanged {
    if (-not $script:GamesLoaded -or $script:Snapshot) { return }
    $stamp = $null
    try { $p = Get-LaunchFile; if (Test-Path -LiteralPath $p) { $stamp = (Get-Item -LiteralPath $p).LastWriteTimeUtc } } catch {}
    if ($stamp -eq $script:LaunchStamp) { return }
    Read-LaunchData
    Set-GameLaunchProps
    $selKey = Get-GameKey $ui.ListGames.SelectedItem
    Update-GameList
    if ($selKey) {
        foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
    }
}

# Karte "Weiterspielen": das zuletzt gestartete Spiel, nur ohne Suchtext und wenn Eden vorhanden ist
$script:ContinueGame = $null
function Update-GameContinue([bool]$show) {
    $g = $null
    if ($show) {
        foreach ($x in @($script:Games)) { if ($x.LastPlayed -and (-not $g -or $x.LastPlayed -gt $g.LastPlayed)) { $g = $x } }
    }
    $script:ContinueGame = $g
    if (-not $g) { $ui.GameContinue.Visibility = "Collapsed"; return }
    $ui.ContTile.Background = $g.TileBrush
    $ui.ContAbbr.Text       = [string]$g.Abbr
    if ($g.IconImg) {
        $ib = [System.Windows.Media.ImageBrush]::new($g.IconImg)
        $ib.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        $ui.ContImg.Background = $ib
    } else { $ui.ContImg.Background = $null }
    $ui.TxtContName.Text = [string]$g.Name
    $ui.TxtContInfo.Text = Get-PlayedText $g
    $ui.GameContinue.Visibility = "Visible"
}

function Update-GameList {
    $q = $ui.TxtGameSearch.Text.Trim()
    $ui.TxtGameSearchHint.Visibility = if ($ui.TxtGameSearch.Text) { "Collapsed" } else { "Visible" }
    if (-not $script:GamesLoaded) { return }
    $list = if ($q) { @($script:Games | Where-Object { $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 }) } else { @($script:Games) }
    # Favoriten zuerst; danach alphabetisch oder - je nach Auswahl - zuletzt gespielt zuerst (nie gespielte am Ende)
    if ([string]$script:Settings.GamesSort -eq "recent") {
        $list = @($list | Sort-Object -Property @{ Expression = { if ($_.IsFav) { 0 } else { 1 } } },
                                                @{ Expression = { if ($_.LastPlayed) { [long]::MaxValue - $_.LastPlayed.Ticks } else { [long]::MaxValue } } }, Name)
    } else {
        $list = @($list | Sort-Object -Property @{ Expression = { if ($_.IsFav) { 0 } else { 1 } } }, Name)
    }
    $ui.ListGames.ItemsSource = $list
    $hasEden = Test-Path (Join-Path $script:Settings.EdenPath "eden.exe")
    Update-GameContinue ([bool](($hasEden -or $script:Snapshot) -and -not $q))
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

# Favoriten: Schluessel ist die Title-ID (bleibt beim Verschieben/Umbenennen gleich), sonst der Dateipfad
function Get-GameKey($g) {
    if (-not $g) { return "" }
    if ($g.Tid) { return ([string]$g.Tid).ToUpperInvariant() }
    return [string]$g.Path
}

function Test-GameFav($g) {
    $k = Get-GameKey $g
    if (-not $k) { return $false }
    foreach ($f in @($script:Settings.FavoriteGames)) { if ([string]$f -eq $k) { return $true } }
    return $false
}

function Switch-GameFav($g) {
    $k = Get-GameKey $g
    if (-not $k) { return }
    $on = -not [bool]$g.IsFav
    foreach ($x in $script:Games) { if ((Get-GameKey $x) -eq $k) { $x.IsFav = $on } }
    $favs = @(@($script:Settings.FavoriteGames) | Where-Object { $_ -and ([string]$_ -ne $k) } | ForEach-Object { [string]$_ })
    if ($on) { $favs += $k }
    $script:Settings.FavoriteGames = $favs
    if (-not $script:Snapshot) { try { Save-Settings } catch { Add-UiLog ((T "ErrPrefix") + " " + $_.Exception.Message) } }
    # Auswahl beibehalten, obwohl die Liste neu sortiert wird
    $selKey = Get-GameKey $ui.ListGames.SelectedItem
    Update-GameList
    if ($selKey) {
        foreach ($x in @($ui.ListGames.ItemsSource)) { if ((Get-GameKey $x) -eq $selKey) { $ui.ListGames.SelectedItem = $x; break } }
    }
}

# Liegt das angeklickte Element im Stern-Button? (dann kein Spielstart per Doppelklick)
function Test-InFavButton($src) {
    $d = $src
    while ($d -and -not ($d -is [System.Windows.Controls.ListBoxItem])) {
        if ($d -is [System.Windows.Controls.Button] -and [string]$d.Tag -eq "fav") { return $true }
        if ($d -is [System.Windows.Media.Visual] -or $d -is [System.Windows.Media.Media3D.Visual3D]) { $d = [System.Windows.Media.VisualTreeHelper]::GetParent($d) }
        else { $d = [System.Windows.LogicalTreeHelper]::GetParent($d) }
    }
    return $false
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
foreach ($n in @("BtnNavVer","BtnNavNotes","BtnNavSet","PanelNotes","PanelNotesSide","NotesContent","TxtNotesHint","ColList","ColNotes","CmbNotes","BtnRestore","ChkClose","TxtThemeName","BtnThemePick","CmbLang","RootGrid","TxtPageTitle","TxtPageSub","ChipState","TxtChip","DotState","BtnLogToggle","TxtSelfVersion","TxtSelfState","BtnSelfCheck","BtnSelfInstall","BtnSelfNotes","ChkSelfUpdate","BtnNavGames","PanelGames","BtnNavMods","PanelMods","BtnNavContent","PanelContent","TxtContentInfo","BtnContentReload","ContentBanner","ListContentGames","TxtContentGameTitle","TxtContentGameSub","BtnContentAdd","BtnContentFolder","ListContent","TxtContentEmpty","BtnNavFw","PanelFirmware","BtnNavSaves","PanelSaves","TxtSavesInfo","BtnShaderAll","BtnSaveBackupDir","BtnSavesReload","SavesBanner","ListSaveGames","TxtSaveGameTitle","TxtSaveGameSub","TxtSaveState","BtnSaveFolder","BtnSaveBackup","TxtShaderState","BtnShaderDelete","ListSaveBackups","TxtSaveBackupsEmpty","FwBanner","TxtFwState","TxtFwSub","FwWarn","TxtFwWarn","BtnFwZip","BtnFwDir","BtnFwDelete","BtnFwFolder","TxtKeysState","TxtKeysSub","BtnKeysInstall","BtnKeysDelete","BtnKeysFolder","TxtModsInfo","BtnModsReload","ModsBanner","ListModGames","TxtModGameTitle","TxtModGameSub","BtnModAdd","BtnModFolder","ListMods","TxtModsEmpty","TxtGameSearch","TxtGameSearchHint","BtnGamesReload","ChkGamesFull","ChkGamesClose","ListGames","TxtGamesInfo","TxtGamesEmpty","BtnGameStart","SettingsScroll","TxtSettingsFile","TxtInstalled","TxtLatest","BtnUpdate","BtnLaunch",
                 "PanelVersions","PanelSettings","List","BtnInstallSel","BtnMore","BtnReload","TxtListInfo",
                 "TxtPath","BtnBrowse","CmbVariant","PanelPattern","TxtPattern","TxtPages","ChkBackup","ChkSaveAuto","ChkStart","ChkAuto","ChkAutoInstall","BtnSave",
                 "TxtStatus","BtnCancel","Pb","TxtLog","TxtNotesTitle","BtnNotesWeb","TxtNotes",
                 "GameContinue","ContTile","ContAbbr","ContImg","TxtContName","TxtContInfo","BtnGameContinue","CmbGameSort",
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
$ui.ListGames.Add_SelectionChanged({ Update-GameButton })
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
            SelfUpdateCheck = [bool]$ui.ChkSelfUpdate.IsChecked
            GamesFullscreen = [bool]$ui.ChkGamesFull.IsChecked
            GamesCloseOnStart = [bool]$ui.ChkGamesClose.IsChecked
            GamesSort    = $(if ([string]$old.GamesSort -eq "recent") { "recent" } else { "name" })
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
[void]$window.ShowDialog()
