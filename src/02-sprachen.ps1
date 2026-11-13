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
ChkOnlineMeta=Cover und Spielnamen aus dem Internet laden (api.nlib.cc)
OnlineAskTitle=Cover und Spielnamen aus dem Internet laden?
OnlineAskText=Eden liefert Cover und Spielnamen nicht mehr mit. Der Updater kann beides einmal pro Spiel bei api.nlib.cc abrufen und auf diesem PC speichern.\n\nVorteile\n• Echte Cover statt Kürzel auf den Kacheln\n• Saubere Spielnamen statt Dateinamen – auch bei Mods, Updates & DLC und Spieldaten\n• Jedes Spiel wird nur einmal abgefragt, danach kommt alles vom PC\n\nNachteile und Risiken\n• Der Betreiber von api.nlib.cc sieht deine IP-Adresse und die Title-IDs deiner Spiele – also, welche Spiele du hast\n• api.nlib.cc ist ein privates Hobbyprojekt ohne Garantie: Es kann ausfallen, verschwinden oder falsche Namen und Bilder liefern\n• Geladene Bilder und Namen kommen von einem fremden Server. Der Updater nimmt nur JPEG-Bilder und Text an und führt nichts davon aus\n• Die Cover belegen etwas Speicherplatz (etwa 15–45 KB pro Spiel)\n\nMehr wird nicht übertragen: keine Dateien, keine Spielstände, keine Kontodaten. Mit „Nein“ arbeitet der Updater genauso, nur mit Kürzeln und Dateinamen.\n\nDu kannst das jederzeit in den Einstellungen unter „Verhalten“ ändern.
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
DetPlayTime=Spielzeit
DetUpdate=Installiertes Update
DetModsVal={0} aktiv, {1} aus
DetFile=Datei
DetShow=Im Explorer anzeigen
DetHint=Update, DLC und Mods: Stand der letzten Spieleliste von Eden
SelfNotesNew=Neu in Version {0}
SelfNotesThis=Neu in dieser Version ({0})
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
ChkOnlineMeta=Load covers and game names from the internet (api.nlib.cc)
OnlineAskTitle=Load covers and game names from the internet?
OnlineAskText=Eden no longer provides covers and game names. The updater can fetch both once per game from api.nlib.cc and store them on this PC.\n\nBenefits\n• Real covers instead of initials on the tiles\n• Clean game names instead of file names – also for mods, updates & DLC and save data\n• Each game is requested only once; after that everything comes from this PC\n\nDrawbacks and risks\n• The operator of api.nlib.cc sees your IP address and the title IDs of your games – in other words, which games you have\n• api.nlib.cc is a private hobby project without any guarantee: it may be down, disappear or deliver wrong names and images\n• Downloaded images and names come from a third-party server. The updater only accepts JPEG images and text and never executes any of it\n• The covers use some disk space (about 15–45 KB per game)\n\nNothing else is transmitted: no files, no save data, no account data. With “No” the updater works the same, just with initials and file names.\n\nYou can change this at any time in the settings under “Behavior”.
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
DetPlayTime=Play time
DetUpdate=Installed update
DetModsVal={0} on, {1} off
DetFile=File
DetShow=Show in Explorer
DetHint=Update, DLC and mods: as of Eden’s last game list
SelfNotesNew=New in version {0}
SelfNotesThis=New in this version ({0})
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
ChkOnlineMeta=Cargar carátulas y nombres de juegos desde internet (api.nlib.cc)
OnlineAskTitle=¿Cargar carátulas y nombres de juegos desde internet?
OnlineAskText=Eden ya no proporciona carátulas ni nombres de juegos. El actualizador puede obtener ambos una vez por juego desde api.nlib.cc y guardarlos en este PC.\n\nVentajas\n• Carátulas reales en lugar de iniciales en las fichas\n• Nombres de juego limpios en lugar de nombres de archivo, también en mods, actualizaciones y DLC y datos de guardado\n• Cada juego se consulta una sola vez; después todo sale de este PC\n\nInconvenientes y riesgos\n• El operador de api.nlib.cc ve tu dirección IP y los Title ID de tus juegos, es decir, qué juegos tienes\n• api.nlib.cc es un proyecto privado de aficionados sin garantía: puede fallar, desaparecer o entregar nombres e imágenes incorrectos\n• Las imágenes y los nombres descargados proceden de un servidor ajeno. El actualizador solo acepta imágenes JPEG y texto y no ejecuta nada de ello\n• Las carátulas ocupan algo de espacio (unos 15–45 KB por juego)\n\nNo se transmite nada más: ni archivos, ni partidas guardadas, ni datos de cuenta. Con «No» el actualizador funciona igual, solo con iniciales y nombres de archivo.\n\nPuedes cambiarlo en cualquier momento en los ajustes, en «Comportamiento».
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
DetPlayTime=Tiempo de juego
DetUpdate=Actualización instalada
DetModsVal={0} activos, {1} desactivados
DetFile=Archivo
DetShow=Mostrar en el Explorador
DetHint=Actualización, DLC y mods: según la última lista de juegos de Eden
SelfNotesNew=Novedades de la versión {0}
SelfNotesThis=Novedades de esta versión ({0})
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
ChkOnlineMeta=Charger les jaquettes et les noms des jeux depuis Internet (api.nlib.cc)
OnlineAskTitle=Charger les jaquettes et les noms des jeux depuis Internet ?
OnlineAskText=Eden ne fournit plus les jaquettes ni les noms des jeux. Le programme peut récupérer les deux une fois par jeu auprès d’api.nlib.cc et les enregistrer sur ce PC.\n\nAvantages\n• De vraies jaquettes à la place des initiales sur les tuiles\n• Des noms de jeux propres à la place des noms de fichiers – aussi pour les mods, les mises à jour et DLC et les données de jeu\n• Chaque jeu n’est demandé qu’une seule fois ; ensuite tout vient de ce PC\n\nInconvénients et risques\n• L’exploitant d’api.nlib.cc voit votre adresse IP et les Title ID de vos jeux – autrement dit, quels jeux vous possédez\n• api.nlib.cc est un projet amateur privé, sans garantie : il peut être en panne, disparaître ou fournir des noms et images erronés\n• Les images et noms téléchargés proviennent d’un serveur tiers. Le programme n’accepte que des images JPEG et du texte et n’en exécute rien\n• Les jaquettes occupent un peu d’espace disque (environ 15–45 Ko par jeu)\n\nRien d’autre n’est transmis : ni fichiers, ni sauvegardes, ni données de compte. Avec « Non », le programme fonctionne de la même façon, simplement avec des initiales et des noms de fichiers.\n\nVous pouvez modifier ce choix à tout moment dans les paramètres, sous « Comportement ».
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
DetPlayTime=Temps de jeu
DetUpdate=Mise à jour installée
DetModsVal={0} actifs, {1} désactivés
DetFile=Fichier
DetShow=Afficher dans l’Explorateur
DetHint=Mise à jour, DLC et mods : d’après la dernière liste de jeux d’Eden
SelfNotesNew=Nouveautés de la version {0}
SelfNotesThis=Nouveautés de cette version ({0})
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
ChkOnlineMeta=Carica copertine e nomi dei giochi da Internet (api.nlib.cc)
OnlineAskTitle=Caricare copertine e nomi dei giochi da Internet?
OnlineAskText=Eden non fornisce più copertine e nomi dei giochi. L’updater può recuperarli una volta per gioco da api.nlib.cc e salvarli su questo PC.\n\nVantaggi\n• Copertine vere al posto delle sigle sui riquadri\n• Nomi dei giochi puliti al posto dei nomi dei file, anche per mod, aggiornamenti e DLC e dati di gioco\n• Ogni gioco viene richiesto una sola volta; poi tutto arriva da questo PC\n\nSvantaggi e rischi\n• Il gestore di api.nlib.cc vede il tuo indirizzo IP e i Title ID dei tuoi giochi, cioè quali giochi possiedi\n• api.nlib.cc è un progetto amatoriale privato senza garanzie: può non funzionare, sparire o fornire nomi e immagini sbagliati\n• Immagini e nomi scaricati provengono da un server esterno. L’updater accetta solo immagini JPEG e testo e non esegue nulla di ciò che riceve\n• Le copertine occupano un po’ di spazio (circa 15–45 KB per gioco)\n\nNon viene trasmesso altro: né file, né salvataggi, né dati dell’account. Con «No» l’updater funziona allo stesso modo, solo con sigle e nomi dei file.\n\nPuoi cambiare questa scelta in qualsiasi momento nelle impostazioni, alla voce «Comportamento».
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
DetPlayTime=Tempo di gioco
DetUpdate=Aggiornamento installato
DetModsVal={0} attive, {1} disattivate
DetFile=File
DetShow=Mostra in Esplora file
DetHint=Aggiornamento, DLC e mod: in base all’ultimo elenco giochi di Eden
SelfNotesNew=Novità della versione {0}
SelfNotesThis=Novità di questa versione ({0})
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
ChkOnlineMeta=Carregar capas e nomes dos jogos da Internet (api.nlib.cc)
OnlineAskTitle=Carregar capas e nomes dos jogos da Internet?
OnlineAskText=O Eden já não fornece capas nem nomes dos jogos. O atualizador pode obter ambos uma vez por jogo em api.nlib.cc e guardá-los neste PC.\n\nVantagens\n• Capas reais em vez de iniciais nos mosaicos\n• Nomes de jogos limpos em vez de nomes de ficheiros – também em mods, atualizações e DLC e dados de jogo\n• Cada jogo é consultado apenas uma vez; depois tudo vem deste PC\n\nDesvantagens e riscos\n• O operador de api.nlib.cc vê o seu endereço IP e os Title ID dos seus jogos – ou seja, que jogos tem\n• api.nlib.cc é um projeto amador privado sem garantia: pode falhar, desaparecer ou fornecer nomes e imagens errados\n• As imagens e os nomes descarregados vêm de um servidor de terceiros. O atualizador só aceita imagens JPEG e texto e não executa nada disso\n• As capas ocupam algum espaço em disco (cerca de 15–45 KB por jogo)\n\nNada mais é transmitido: nem ficheiros, nem jogos guardados, nem dados de conta. Com «Não» o atualizador funciona da mesma forma, apenas com iniciais e nomes de ficheiros.\n\nPode alterar isto a qualquer momento nas definições, em «Comportamento».
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
DetPlayTime=Tempo de jogo
DetUpdate=Atualização instalada
DetModsVal={0} ativos, {1} desativados
DetFile=Ficheiro
DetShow=Mostrar no Explorador
DetHint=Atualização, DLC e mods: segundo a última lista de jogos do Eden
SelfNotesNew=Novidades da versão {0}
SelfNotesThis=Novidades desta versão ({0})
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
ChkOnlineMeta=Covers en gamenamen van internet laden (api.nlib.cc)
OnlineAskTitle=Covers en gamenamen van internet laden?
OnlineAskText=Eden levert geen covers en gamenamen meer mee. De updater kan beide één keer per game ophalen bij api.nlib.cc en op deze pc opslaan.\n\nVoordelen\n• Echte covers in plaats van afkortingen op de tegels\n• Nette gamenamen in plaats van bestandsnamen – ook bij mods, updates & DLC en speldata\n• Elke game wordt maar één keer opgevraagd; daarna komt alles van deze pc\n\nNadelen en risico’s\n• De beheerder van api.nlib.cc ziet je IP-adres en de Title-ID’s van je games – dus welke games je hebt\n• api.nlib.cc is een particulier hobbyproject zonder garantie: het kan uitvallen, verdwijnen of verkeerde namen en afbeeldingen leveren\n• Gedownloade afbeeldingen en namen komen van een server van derden. De updater accepteert alleen JPEG-afbeeldingen en tekst en voert daar niets van uit\n• De covers nemen wat schijfruimte in (ongeveer 15–45 kB per game)\n\nVerder wordt er niets verzonden: geen bestanden, geen savegames, geen accountgegevens. Met ‘Nee’ werkt de updater hetzelfde, alleen met afkortingen en bestandsnamen.\n\nJe kunt dit altijd wijzigen in de instellingen onder ‘Gedrag’.
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
DetPlayTime=Speeltijd
DetUpdate=Geïnstalleerde update
DetModsVal={0} aan, {1} uit
DetFile=Bestand
DetShow=In Verkenner tonen
DetHint=Update, DLC en mods: volgens de laatste gamelijst van Eden
SelfNotesNew=Nieuw in versie {0}
SelfNotesThis=Nieuw in deze versie ({0})
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
ChkOnlineMeta=Pobieraj okładki i nazwy gier z internetu (api.nlib.cc)
OnlineAskTitle=Pobierać okładki i nazwy gier z internetu?
OnlineAskText=Eden nie dostarcza już okładek ani nazw gier. Updater może pobrać jedno i drugie raz na grę z api.nlib.cc i zapisać na tym komputerze.\n\nZalety\n• Prawdziwe okładki zamiast skrótów na kafelkach\n• Czytelne nazwy gier zamiast nazw plików – także w modach, aktualizacjach i DLC oraz danych gier\n• Każda gra jest sprawdzana tylko raz; potem wszystko pochodzi z tego komputera\n\nWady i ryzyko\n• Operator api.nlib.cc widzi Twój adres IP oraz Title ID Twoich gier – czyli to, jakie gry posiadasz\n• api.nlib.cc to prywatny projekt hobbystyczny bez gwarancji: może nie działać, zniknąć albo podawać błędne nazwy i obrazy\n• Pobrane obrazy i nazwy pochodzą z obcego serwera. Updater przyjmuje wyłącznie obrazy JPEG i tekst i niczego z nich nie uruchamia\n• Okładki zajmują trochę miejsca na dysku (około 15–45 KB na grę)\n\nNic więcej nie jest przesyłane: żadnych plików, zapisów gier ani danych konta. Po wybraniu „Nie” updater działa tak samo, tylko ze skrótami i nazwami plików.\n\nMożesz to zmienić w każdej chwili w ustawieniach, w sekcji „Zachowanie”.
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
DetPlayTime=Czas gry
DetUpdate=Zainstalowana aktualizacja
DetModsVal={0} wł., {1} wył.
DetFile=Plik
DetShow=Pokaż w Eksploratorze
DetHint=Aktualizacja, DLC i mody: według ostatniej listy gier Eden
SelfNotesNew=Nowości w wersji {0}
SelfNotesThis=Nowości w tej wersji ({0})
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
ChkOnlineMeta=Kapakları ve oyun adlarını internetten yükle (api.nlib.cc)
OnlineAskTitle=Kapaklar ve oyun adları internetten yüklensin mi?
OnlineAskText=Eden artık kapakları ve oyun adlarını sağlamıyor. Güncelleyici her ikisini de oyun başına bir kez api.nlib.cc adresinden alıp bu bilgisayara kaydedebilir.\n\nAvantajlar\n• Kutucuklarda kısaltma yerine gerçek kapaklar\n• Dosya adları yerine düzgün oyun adları – modlar, güncellemeler ve DLC ile oyun verilerinde de\n• Her oyun yalnızca bir kez sorgulanır; sonrasında her şey bu bilgisayardan gelir\n\nDezavantajlar ve riskler\n• api.nlib.cc işletmecisi IP adresinizi ve oyunlarınızın Title ID’lerini, yani hangi oyunlara sahip olduğunuzu görür\n• api.nlib.cc garantisi olmayan özel bir hobi projesidir: çalışmayabilir, kapanabilir veya yanlış ad ve görseller verebilir\n• İndirilen görseller ve adlar yabancı bir sunucudan gelir. Güncelleyici yalnızca JPEG görsellerini ve metni kabul eder, bunların hiçbirini çalıştırmaz\n• Kapaklar biraz disk alanı kaplar (oyun başına yaklaşık 15–45 KB)\n\nBaşka hiçbir şey aktarılmaz: dosya, kayıt verisi veya hesap bilgisi gönderilmez. “Hayır” derseniz güncelleyici aynı şekilde çalışır, yalnızca kısaltmalar ve dosya adlarıyla.\n\nBunu istediğiniz zaman ayarlardaki “Davranış” bölümünden değiştirebilirsiniz.
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
DetPlayTime=Oynama süresi
DetUpdate=Yüklü güncelleme
DetModsVal={0} açık, {1} kapalı
DetFile=Dosya
DetShow=Explorer’da göster
DetHint=Güncelleme, DLC ve modlar: Eden’in son oyun listesine göre
SelfNotesNew={0} sürümündeki yenilikler
SelfNotesThis=Bu sürümdeki yenilikler ({0})
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
ChkOnlineMeta=Загружать обложки и названия игр из интернета (api.nlib.cc)
OnlineAskTitle=Загружать обложки и названия игр из интернета?
OnlineAskText=Eden больше не предоставляет обложки и названия игр. Программа может один раз для каждой игры получить их с api.nlib.cc и сохранить на этом компьютере.\n\nПреимущества\n• Настоящие обложки вместо сокращений на плитках\n• Аккуратные названия игр вместо имён файлов – в том числе в модах, обновлениях и DLC и данных игр\n• Каждая игра запрашивается только один раз; дальше всё берётся с этого компьютера\n\nНедостатки и риски\n• Владелец api.nlib.cc видит ваш IP-адрес и Title ID ваших игр, то есть какие игры у вас есть\n• api.nlib.cc – частный любительский проект без гарантий: он может не работать, исчезнуть или выдавать неверные названия и изображения\n• Загруженные изображения и названия приходят со стороннего сервера. Программа принимает только изображения JPEG и текст и ничего из этого не запускает\n• Обложки занимают немного места на диске (примерно 15–45 КБ на игру)\n\nБольше ничего не передаётся: ни файлы, ни сохранения, ни данные учётной записи. При ответе «Нет» программа работает так же, только с сокращениями и именами файлов.\n\nЭто можно изменить в любой момент в настройках, в разделе «Поведение».
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
DetPlayTime=Время в игре
DetUpdate=Установленное обновление
DetModsVal={0} вкл., {1} выкл.
DetFile=Файл
DetShow=Показать в Проводнике
DetHint=Обновление, DLC и моды: по последнему списку игр Eden
SelfNotesNew=Новое в версии {0}
SelfNotesThis=Новое в этой версии ({0})
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
ChkOnlineMeta=カバー画像とゲーム名をインターネットから取得 (api.nlib.cc)
OnlineAskTitle=カバー画像とゲーム名をインターネットから取得しますか？
OnlineAskText=Eden はカバー画像とゲーム名を提供しなくなりました。アップデーターは、ゲームごとに一度だけ api.nlib.cc から両方を取得し、この PC に保存できます。\n\nメリット\n• タイルに略称ではなく本物のカバー画像を表示\n• ファイル名ではなく正式なゲーム名を表示（MOD、アップデートと DLC、ゲームデータでも）\n• 各ゲームの問い合わせは一度だけで、以降はすべてこの PC から読み込みます\n\nデメリットとリスク\n• api.nlib.cc の運営者に、あなたの IP アドレスとゲームの Title ID（どのゲームを持っているか）が伝わります\n• api.nlib.cc は個人の趣味プロジェクトで保証はありません。停止や終了、誤った名前や画像が返される可能性があります\n• 取得する画像と名前は外部サーバーから届きます。アップデーターは JPEG 画像とテキストのみを受け取り、実行は一切しません\n• カバー画像は少しディスク容量を使います（1 ゲームあたり約 15〜45 KB）\n\nそれ以外は送信されません（ファイル、セーブデータ、アカウント情報は送信しません）。「いいえ」を選んでもアップデーターは同じように動作し、略称とファイル名が表示されるだけです。\n\nこの設定は、設定の「動作」からいつでも変更できます。
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
DetPlayTime=プレイ時間
DetUpdate=インストール済みアップデート
DetModsVal=有効 {0}、無効 {1}
DetFile=ファイル
DetShow=エクスプローラーで表示
DetHint=アップデート、DLC、MOD：Eden の最新のゲームリストに基づく
SelfNotesNew=バージョン {0} の新機能
SelfNotesThis=このバージョンの新機能 ({0})
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
ChkOnlineMeta=从互联网加载封面和游戏名称 (api.nlib.cc)
OnlineAskTitle=要从互联网加载封面和游戏名称吗？
OnlineAskText=Eden 不再提供封面和游戏名称。更新器可以为每个游戏从 api.nlib.cc 获取一次，并保存在这台电脑上。\n\n优点\n• 磁贴上显示真实封面，而不是缩写\n• 显示规范的游戏名称，而不是文件名（模组、更新与 DLC、游戏数据中同样适用）\n• 每个游戏只查询一次，之后全部从本机读取\n\n缺点和风险\n• api.nlib.cc 的运营者可以看到你的 IP 地址和游戏的 Title ID，也就是你拥有哪些游戏\n• api.nlib.cc 是私人爱好项目，没有任何保证：它可能无法访问、停止运营，或返回错误的名称和图片\n• 下载的图片和名称来自第三方服务器。更新器只接受 JPEG 图片和文本，不会执行其中任何内容\n• 封面会占用少量磁盘空间（每个游戏约 15–45 KB）\n\n除此之外不会传输任何内容：没有文件、存档或账号数据。选择“否”时更新器照常工作，只是显示缩写和文件名。\n\n你可以随时在设置的“行为”中更改此选项。
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
DetPlayTime=游戏时长
DetUpdate=已安装的更新
DetModsVal=已启用 {0}，已停用 {1}
DetFile=文件
DetShow=在资源管理器中显示
DetHint=更新、DLC 和模组：以 Eden 最近一次的游戏列表为准
SelfNotesNew=版本 {0} 的新内容
SelfNotesThis=此版本的新内容 ({0})
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
ChkOnlineMeta=인터넷에서 커버와 게임 이름 불러오기 (api.nlib.cc)
OnlineAskTitle=인터넷에서 커버와 게임 이름을 불러올까요?
OnlineAskText=Eden은 더 이상 커버와 게임 이름을 제공하지 않습니다. 업데이터가 게임마다 한 번씩 api.nlib.cc에서 둘 다 가져와 이 PC에 저장할 수 있습니다.\n\n장점\n• 타일에 약어 대신 실제 커버 표시\n• 파일 이름 대신 깔끔한 게임 이름 표시 (모드, 업데이트 및 DLC, 게임 데이터에도 적용)\n• 게임마다 한 번만 조회하며, 이후에는 모두 이 PC에서 불러옵니다\n\n단점과 위험\n• api.nlib.cc 운영자가 사용자의 IP 주소와 게임의 Title ID, 즉 어떤 게임을 가지고 있는지 알 수 있습니다\n• api.nlib.cc는 보증이 없는 개인 취미 프로젝트입니다. 접속이 안 되거나 사라지거나 잘못된 이름과 이미지를 줄 수 있습니다\n• 내려받은 이미지와 이름은 외부 서버에서 옵니다. 업데이터는 JPEG 이미지와 텍스트만 받으며 그 어떤 것도 실행하지 않습니다\n• 커버는 디스크 공간을 조금 사용합니다 (게임당 약 15–45KB)\n\n그 밖에는 아무것도 전송되지 않습니다. 파일, 세이브 데이터, 계정 정보는 보내지 않습니다. “아니요”를 선택해도 업데이터는 똑같이 동작하며 약어와 파일 이름만 표시됩니다.\n\n이 설정은 설정의 “동작”에서 언제든지 바꿀 수 있습니다.
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
DetPlayTime=플레이 시간
DetUpdate=설치된 업데이트
DetModsVal=켜짐 {0}, 꺼짐 {1}
DetFile=파일
DetShow=탐색기에서 보기
DetHint=업데이트, DLC, 모드: Eden의 마지막 게임 목록 기준
SelfNotesNew=버전 {0}의 새로운 기능
SelfNotesThis=이 버전의 새로운 기능 ({0})
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
                # die letzten Releases (neueste zuerst) - so lassen sich die Patchnotes aller uebersprungenen Versionen zeigen
                $url  = "https://api.github.com/repos/" + $a.Repo + "/releases?per_page=15"
                $code = & curl.exe -s -L --max-time 20 -A $UA -H "Accept: application/vnd.github+json" -o $tmp -w "%{http_code}" $url 2>$null
                if ("$code" -eq "404") { $sync.Result = @{ Ok = $true; Mode = "check"; Tag = ""; Releases = @() }; return }
                if ("$code" -ne "200") { throw ("GitHub HTTP " + $code) }
                $all = @([IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8) | ConvertFrom-Json)
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
            $rels = @($all | Where-Object { $_ -and $_.tag_name -and -not $_.draft -and -not $_.prerelease })
            if (-not $rels.Count) { $sync.Result = @{ Ok = $true; Mode = "check"; Tag = ""; Releases = @() }; return }

            # Patchnotes aufbereiten: passende Sprache waehlen (Abschnitte "### Deutsch" / "### English"),
            # automatisch erzeugte GitHub-Zeilen entfernen, Markdown in lesbaren Text wandeln
            function Get-SelfNotes([string]$body, [string]$lang) {
                if (-not $body) { return "" }
                $heads = [regex]::Matches($body, '(?m)^\s{0,3}#{2,4}\s*(Deutsch|English)\s*$')
                if ($heads.Count -gt 0) {
                    $want = if ($lang -eq "de") { "Deutsch" } else { "English" }
                    $pick = $null
                    foreach ($h in $heads) { if ($h.Groups[1].Value -eq $want) { $pick = $h; break } }
                    if (-not $pick) { $pick = $heads[0] }
                    $from = $pick.Index + $pick.Length
                    $to = $body.Length
                    foreach ($h in $heads) { if ($h.Index -gt $pick.Index -and $h.Index -lt $to) { $to = $h.Index } }
                    $body = $body.Substring($from, $to - $from)
                }
                $keep = foreach ($line in ($body -split "\r?\n")) {
                    if ($line -match '^\s*\*\*Full Changelog\*\*' -or $line -match "^\s*#+\s*What's Changed\s*$" -or $line -match '^\s*#+\s*New Contributors\s*$') { continue }
                    [regex]::Replace($line, '\s+by @\S+ in https?://\S+\s*$', '')
                }
                return (Format-Notes ($keep -join "`n"))
            }
            $list = foreach ($r in $rels) { @{ Tag = [string]$r.tag_name; Notes = (Get-SelfNotes ([string]$r.body) ([string]$a.Lang)) } }
            $j = $rels[0]
            $asset = @($j.assets) | Where-Object { $_.name -eq "EdenUpdater.exe" } | Select-Object -First 1
            $sync.Result = @{
                Ok   = $true; Mode = "check"
                Tag  = [string]$j.tag_name
                Page = [string]$j.html_url
                Url  = $(if ($asset) { [string]$asset.browser_download_url } else { "" })
                Size = $(if ($asset) { [long]$asset.size } else { [long]0 })
                Releases = @($list)
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

