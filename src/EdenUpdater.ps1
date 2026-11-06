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
    EdenPath     = "G:\Emulator\Eden"
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
      "EdenUpdater.ico", "Build-Exe.ps1", "Build-Exe.bat")
}

$script:Settings       = Get-Settings
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
ThDarkCyan=Dunkel (Cyan)
ThDarkViolet=Dunkel (Violett)
ThDarkGreen=Dunkel (Grün)
ThDarkOrange=Dunkel (Orange)
ThAmoled=Schwarz (AMOLED)
ThLight=Hell (Cyan)
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
ThDarkCyan=Dark (Cyan)
ThDarkViolet=Dark (Violet)
ThDarkGreen=Dark (Green)
ThDarkOrange=Dark (Orange)
ThAmoled=Black (AMOLED)
ThLight=Light (Cyan)
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
ThDarkCyan=Oscuro (cian)
ThDarkViolet=Oscuro (violeta)
ThDarkGreen=Oscuro (verde)
ThDarkOrange=Oscuro (naranja)
ThAmoled=Negro (AMOLED)
ThLight=Claro (cian)
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
ThDarkCyan=Sombre (cyan)
ThDarkViolet=Sombre (violet)
ThDarkGreen=Sombre (vert)
ThDarkOrange=Sombre (orange)
ThAmoled=Noir (AMOLED)
ThLight=Clair (cyan)
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
ThDarkCyan=Scuro (ciano)
ThDarkViolet=Scuro (viola)
ThDarkGreen=Scuro (verde)
ThDarkOrange=Scuro (arancione)
ThAmoled=Nero (AMOLED)
ThLight=Chiaro (ciano)
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
ThDarkCyan=Escuro (ciano)
ThDarkViolet=Escuro (violeta)
ThDarkGreen=Escuro (verde)
ThDarkOrange=Escuro (laranja)
ThAmoled=Preto (AMOLED)
ThLight=Claro (ciano)
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
ThDarkCyan=Donker (cyaan)
ThDarkViolet=Donker (violet)
ThDarkGreen=Donker (groen)
ThDarkOrange=Donker (oranje)
ThAmoled=Zwart (AMOLED)
ThLight=Licht (cyaan)
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
ThDarkCyan=Ciemny (cyjan)
ThDarkViolet=Ciemny (fiolet)
ThDarkGreen=Ciemny (zielony)
ThDarkOrange=Ciemny (pomarańczowy)
ThAmoled=Czarny (AMOLED)
ThLight=Jasny (cyjan)
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
ThDarkCyan=Koyu (camgöbeği)
ThDarkViolet=Koyu (mor)
ThDarkGreen=Koyu (yeşil)
ThDarkOrange=Koyu (turuncu)
ThAmoled=Siyah (AMOLED)
ThLight=Açık (camgöbeği)
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
ThDarkCyan=Тёмная (бирюзовая)
ThDarkViolet=Тёмная (фиолетовая)
ThDarkGreen=Тёмная (зелёная)
ThDarkOrange=Тёмная (оранжевая)
ThAmoled=Чёрная (AMOLED)
ThLight=Светлая (бирюзовая)
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
ThDarkCyan=ダーク (シアン)
ThDarkViolet=ダーク (バイオレット)
ThDarkGreen=ダーク (グリーン)
ThDarkOrange=ダーク (オレンジ)
ThAmoled=ブラック (AMOLED)
ThLight=ライト (シアン)
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
ThDarkCyan=深色 (青色)
ThDarkViolet=深色 (紫色)
ThDarkGreen=深色 (绿色)
ThDarkOrange=深色 (橙色)
ThAmoled=黑色 (AMOLED)
ThLight=浅色 (青色)
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
ThDarkCyan=다크 (시안)
ThDarkViolet=다크 (바이올렛)
ThDarkGreen=다크 (그린)
ThDarkOrange=다크 (오렌지)
ThAmoled=블랙 (AMOLED)
ThLight=라이트 (시안)
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
$notesSync = [hashtable]::Synchronized(@{
    Log    = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]')
    Done   = $false
    Result = $null
    Args   = $null
})

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
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13">
  <Window.Resources>
    <FontFamily x:Key="FontHead">Bahnschrift, Segoe UI Semibold</FontFamily>
    <FontFamily x:Key="FontIcon">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <SolidColorBrush x:Key="BrPanel"  Color="#171D26"/>
    <SolidColorBrush x:Key="BrPanel2" Color="#1E2632"/>
    <SolidColorBrush x:Key="BrLine"   Color="#2A3442"/>
    <SolidColorBrush x:Key="BrText"   Color="#E6EDF3"/>
    <SolidColorBrush x:Key="BrMuted"  Color="#8B98A9"/>
    <SolidColorBrush x:Key="BrAccent" Color="#22D3EE"/>
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
                       Foreground="{DynamicResource BrAccent}" Margin="0,-1,0,0"/>
          </StackPanel>
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="0,34,0,0">
          <Button x:Name="BtnNavVer"   Tag="&#xE8FD;" Content="{DynamicResource L_NavVersions}" Style="{StaticResource BtnNav}"/>
          <Button x:Name="BtnNavNotes" Tag="&#xE8A5;" Content="{DynamicResource L_NavNotes}"    Style="{StaticResource BtnNav}"/>
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
                       Foreground="{DynamicResource BrAccent}" TextTrimming="CharacterEllipsis" Margin="0,4,0,0"/>
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
            <ListBox x:Name="List" Background="Transparent" BorderThickness="0"
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
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{Binding Tag}" FontSize="14.5" FontWeight="SemiBold"
                                 TextTrimming="CharacterEllipsis"/>
                      <TextBlock Text="{Binding Date}" Foreground="{DynamicResource BrMuted}" FontSize="12" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Border Grid.Column="1" Visibility="{Binding NewBadge}" Background="{DynamicResource BrBadgeNewBg}"
                            CornerRadius="10" Padding="9,3" Margin="10,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardLatest}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrBadgeNewFg}"/>
                    </Border>
                    <Border Grid.Column="2" Visibility="{Binding InstBadge}" Background="{DynamicResource BrBadgeInstBg}"
                            CornerRadius="10" Padding="9,3" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_CardInstalled}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrAccent}"/>
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

        <!-- Seite: Einstellungen -->
        <Grid x:Name="PanelSettings" Visibility="Collapsed">
          <Grid.RenderTransform>
            <TranslateTransform/>
          </Grid.RenderTransform>
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,8,0">

              <!-- Installation -->
              <Border Style="{StaticResource Card}" Margin="0,0,0,14">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
                    <TextBlock Text="&#xE8B7;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccent}" VerticalAlignment="Center"/>
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
                    <TextBlock Text="&#xE790;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccent}" VerticalAlignment="Center"/>
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
              <Border Style="{StaticResource Card}" Margin="0,0,0,6">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                    <TextBlock Text="&#xE9F5;" FontFamily="{StaticResource FontIcon}" FontSize="15" Foreground="{DynamicResource BrAccent}" VerticalAlignment="Center"/>
                    <TextBlock Style="{StaticResource Label}" Text="{DynamicResource L_GrpBehavior}" FontSize="11.5" Margin="10,0,0,0" VerticalAlignment="Center"/>
                  </StackPanel>
                  <CheckBox x:Name="ChkBackup" Content="{DynamicResource L_ChkBackup}"/>
                  <CheckBox x:Name="ChkStart" Content="{DynamicResource L_ChkStart}"/>
                  <CheckBox x:Name="ChkClose" Content="{DynamicResource L_ChkClose}"/>
                  <CheckBox x:Name="ChkAuto" Content="{DynamicResource L_ChkAuto}"/>
                  <CheckBox x:Name="ChkAutoInstall" Content="{DynamicResource L_ChkAutoInstall}"/>
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
                       Foreground="{DynamicResource BrAccent}" Background="{DynamicResource BrPanel2}"
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
$ThemePresets = [ordered]@{
    "dark-cyan"   = @{ Label = "Dunkel (Cyan)";    Bg = "#0F1419"; Panel = "#171D26"; Text = "#E6EDF3"; Accent = "#22D3EE" }
    "dark-violet" = @{ Label = "Dunkel (Violett)"; Bg = "#110F1A"; Panel = "#1A1726"; Text = "#ECE8F5"; Accent = "#A78BFA" }
    "dark-green"  = @{ Label = "Dunkel (Grün)";    Bg = "#0E1512"; Panel = "#15201B"; Text = "#E4F0EA"; Accent = "#34D399" }
    "dark-orange" = @{ Label = "Dunkel (Orange)";  Bg = "#15110E"; Panel = "#1F1915"; Text = "#F3EBE4"; Accent = "#FB923C" }
    "amoled"      = @{ Label = "Schwarz (AMOLED)"; Bg = "#000000"; Panel = "#0D0D0D"; Text = "#EDEDED"; Accent = "#22D3EE" }
    "light"       = @{ Label = "Hell (Cyan)";      Bg = "#F3F5F8"; Panel = "#FFFFFF"; Text = "#1B2430"; Accent = "#0891B2" }
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
$script:ThemeKeys = @("BrBg","BrPanel","BrPanel2","BrLine","BrText","BrMuted","BrAccent","BrAccentFg","BrSel","BrSelStrong","BrLog","BrBadgeNewBg","BrBadgeNewFg","BrBadgeInstBg")

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

# Aus 4 Grundfarben werden alle weiteren Farben abgeleitet
function Set-Theme($t) {
    $bg     = ConvertTo-WpfColor $t.Bg     "#0F1419"
    $panel  = ConvertTo-WpfColor $t.Panel  "#171D26"
    $text   = ConvertTo-WpfColor $t.Text   "#E6EDF3"
    $accent = ConvertTo-WpfColor $t.Accent "#22D3EE"
    $black  = [System.Windows.Media.Colors]::Black
    $white  = [System.Windows.Media.Colors]::White
    $light  = ((Get-Luma $panel) -gt 0.5)

    $panel2    = Merge-Color $panel $text 0.04
    $line      = Merge-Color $panel $text 0.14
    $muted     = Merge-Color $text $panel 0.45
    $sel       = Merge-Color $panel $accent 0.18
    $selStrong = Merge-Color $panel2 $accent 0.32
    $log       = if ($light) { Merge-Color $panel $text 0.03 } else { Merge-Color $bg $black 0.35 }
    $accentFg  = if ((Get-Luma $accent) -gt 0.55) { Merge-Color $accent $black 0.88 } else { $white }
    $green     = ConvertTo-WpfColor "#34D399" "#34D399"
    $greenFg   = if ($light) { ConvertTo-WpfColor "#0E8F62" "#0E8F62" } else { $green }

    Set-ThemeBrush "BrBg"          $bg
    Set-ThemeBrush "BrPanel"       $panel
    Set-ThemeBrush "BrPanel2"      $panel2
    Set-ThemeBrush "BrLine"        $line
    Set-ThemeBrush "BrText"        $text
    Set-ThemeBrush "BrMuted"       $muted
    Set-ThemeBrush "BrAccent"      $accent
    Set-ThemeBrush "BrAccentFg"    $accentFg
    Set-ThemeBrush "BrSel"         $sel
    Set-ThemeBrush "BrSelStrong"   $selStrong
    Set-ThemeBrush "BrLog"         $log
    Set-ThemeBrush "BrBadgeNewBg"  (Merge-Color $panel $green 0.20)
    Set-ThemeBrush "BrBadgeNewFg"  $greenFg
    Set-ThemeBrush "BrBadgeInstBg" (Merge-Color $panel $accent 0.20)

    $script:ThemeColors = @{ Bg = $bg; Text = $text; Line = $line; Dark = (-not $light) }
    Set-TitleBar $window
    if ($script:ThemeWin) { Set-TitleBar $script:ThemeWin }
    if (-not $window.Icon) { try { $window.Icon = New-AppIcon } catch {} }
}

function Get-ThemeKey {
    $k = [string]$script:Settings.ThemePreset
    if ($k -and $ThemePresets.Contains($k)) { return $k }
    return "dark-cyan"
}

function Set-ThemeByKey([string]$key) {
    $p = $ThemePresets[$key]
    Set-Theme @{ Bg = $p.Bg; Panel = $p.Panel; Text = $p.Text; Accent = $p.Accent }
}

$ThemeLabelKeys = @{
    "dark-cyan" = "ThDarkCyan"; "dark-violet" = "ThDarkViolet"; "dark-green" = "ThDarkGreen"
    "dark-orange" = "ThDarkOrange"; "amoled" = "ThAmoled"; "light" = "ThLight"
}

function Get-ThemeLabel([string]$key) {
    if ($ThemeLabelKeys.ContainsKey($key)) { return (T $ThemeLabelKeys[$key]) }
    return [string]$ThemePresets[$key].Label
}

function Update-ThemeLabel {
    $ui.TxtThemeName.Text = Get-ThemeLabel (Get-ThemeKey)
}

$themeDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="{DynamicResource L_ThemeTitle}" Width="470" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource BrBg}" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13">
  __RES__
  <StackPanel Margin="22">
    <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_ThemeTag}" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource BrMuted}"/>
    <TextBlock FontFamily="{StaticResource FontHead}" Text="{DynamicResource L_ThemeTitle}" FontSize="18" FontWeight="SemiBold" Margin="0,2,0,4"/>
    <TextBlock Text="{DynamicResource L_ThemeHint}" TextWrapping="Wrap" FontSize="12"
               Foreground="{DynamicResource BrMuted}" Margin="0,0,0,14"/>
    <WrapPanel x:Name="ThemeHost"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,6,0,0">
      <Button x:Name="BtnThemeCancel" Content="{DynamicResource L_Cancel}" Style="{StaticResource Btn}"/>
      <Button x:Name="BtnThemeOk" Content="{DynamicResource L_Apply}" Style="{StaticResource BtnPrimary}" Margin="8,0,0,0"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

$themeCardXaml = @'
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Tag="@@KEY@@" Width="130" Height="92" Margin="0,0,10,10" Padding="0" Cursor="Hand"
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
            $btn.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
            $btn.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        }
    }
}

# Kleines Fenster mit allen Themes (Klick = Vorschau, Uebernehmen = speichern)
function Show-ThemeDialog {
    $resBlock = [regex]::Match($xaml, '<Window\.Resources>.*?</Window\.Resources>', 'Singleline').Value
    $dlg = [Windows.Markup.XamlReader]::Parse($themeDlgXaml.Replace('__RES__', $resBlock))
    $dlg.Owner = $window
    Set-LangResources $dlg
    $script:ThemeWin   = $dlg
    $script:ThemePick  = Get-ThemeKey
    $script:ThemeCards = @{}

    $panelHost = $dlg.FindName("ThemeHost")
    foreach ($k in $ThemePresets.Keys) {
        $p  = $ThemePresets[$k]
        $cx = $themeCardXaml.Replace('@@KEY@@', $k).Replace('@@BG@@', $p.Bg).Replace('@@PANEL@@', $p.Panel).Replace('@@TEXT@@', $p.Text).Replace('@@ACCENT@@', $p.Accent).Replace('@@LABEL@@', [System.Security.SecurityElement]::Escape((Get-ThemeLabel $k)))
        $btn = [Windows.Markup.XamlReader]::Parse($cx)
        $btn.Add_Click({
            param($sender, $e)
            try {
                $script:ThemePick = [string]$sender.Tag
                Set-ThemeByKey $script:ThemePick
                Update-ThemeCards
            } catch {}
        })
        [void]$panelHost.Children.Add($btn)
        $script:ThemeCards[$k] = $btn
    }
    $dlg.FindName("BtnThemeOk").Add_Click({ $script:ThemeWin.Tag = "ok"; $script:ThemeWin.Close() })
    $dlg.FindName("BtnThemeCancel").Add_Click({ $script:ThemeWin.Close() })

    $dlg.Add_SourceInitialized({ Set-TitleBar $script:ThemeWin })
    $dlg.Add_ContentRendered({ try { Start-FadeIn $script:ThemeWin.Content 0 } catch {} })
    Set-ThemeByKey $script:ThemePick   # Dialog selbst bekommt das aktuelle Theme
    Update-ThemeCards
    [void]$dlg.ShowDialog()

    if ($dlg.Tag -eq "ok") {
        $script:Settings.ThemePreset = $script:ThemePick
        Save-Settings
        Add-UiLog (TF "LogThemeSaved" (Get-ThemeLabel $script:ThemePick))
    }
    Set-ThemeByKey (Get-ThemeKey)      # Vorschau verwerfen bzw. gespeichertes Theme setzen
    $script:ThemeWin = $null
    Update-ThemeLabel
}

$msgDlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eden Updater" Width="460" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" UseLayoutRounding="True"
        Background="{DynamicResource BrBg}" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13">
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
        Set-StateChip (T "BtnUpToDate") "BrBadgeInstBg" "BrAccent" $false
    } else {
        $ui.ChipState.Visibility = "Collapsed"
    }
}

function Update-Ui {
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
    if (-not $el) { return }
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
        $btn.SetResourceReference($c::ForegroundProperty,  "BrAccent")
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
    Set-NavActive $ui.BtnNavVer   ($page -eq "versions")
    Set-NavActive $ui.BtnNavNotes ($page -eq "notes")
    Set-NavActive $ui.BtnNavSet   ($page -eq "settings")
    $titleKey = switch ($page) { "notes" { "L_NavNotes" } "settings" { "L_NavSettings" } default { "L_NavVersions" } }
    $ui.TxtPageTitle.SetResourceReference([System.Windows.Controls.TextBlock]::TextProperty, $titleKey)
    if ($prev -ne $page) {
        $el = switch ($page) { "versions" { $ui.PanelVersions } "notes" { $ui.PanelNotes } "settings" { $ui.PanelSettings } }
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
        Start-Process $exe
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
foreach ($n in @("BtnNavVer","BtnNavNotes","BtnNavSet","PanelNotes","PanelNotesSide","NotesContent","TxtNotesHint","ColList","ColNotes","CmbNotes","BtnRestore","ChkClose","TxtThemeName","BtnThemePick","CmbLang","RootGrid","TxtPageTitle","ChipState","TxtChip","DotState","BtnLogToggle","TxtSettingsFile","TxtInstalled","TxtLatest","BtnUpdate","BtnLaunch",
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
}

# --- Navigation
$ui.BtnNavVer.Add_Click({ Set-Page "versions" })
$ui.BtnNavNotes.Add_Click({ Set-Page "notes" })
$ui.BtnNavSet.Add_Click({ Set-Page "settings" })

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
            AutoCheck    = [bool]$ui.ChkAuto.IsChecked
            AutoInstall  = [bool]$ui.ChkAutoInstall.IsChecked
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

$window.Add_SourceInitialized({ Set-TitleBar $window })
$window.Add_ContentRendered({
    if ($script:Initialized) { return }
    $script:Initialized = $true
    Set-SettingsControls
    Set-NotesLayout
    Set-Page "versions"
    Update-Ui
    $timer.Start()
    Start-FadeIn $ui.RootGrid 0
    if ($script:Settings.AutoCheck) { Start-Load ([int]$script:Settings.Pages) }
    else { Add-UiLog (TF "LogAutoOff" (T "BtnReload")); $script:StartupCheck = $false }
})

Set-LangResources $window
Set-ThemeByKey (Get-ThemeKey)
[void]$window.ShowDialog()
