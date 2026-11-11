# Eden Updater

<img src="assets/icon.png" width="96" align="right" alt="Icon">

Portabler Updater für die Nightly-Builds des Eden-Emulators unter Windows.
Aktualisiert auf die neueste Version, installiert ältere Builds und zeigt die Patchnotes an.

## Features

- Neueste Nightly installieren oder beliebige ältere Version wählen
- Backup vor dem Update und Wiederherstellen per Klick
- Patchnotes als eigene Seite oder neben der Versionsliste
- Eigene Titelleiste im Design der Oberfläche; Fenstergröße und -position werden gemerkt
- Cover und saubere Spielnamen: werden einmal pro Spiel anhand der Title-ID von [api.nlib.cc](https://api.nlib.cc) geladen und unter `%LOCALAPPDATA%\EdenUpdater\covers` gemerkt. Übertragen wird nur die Title-ID. Der Updater fragt beim ersten Start, ob das gewünscht ist, und nennt dabei Vor- und Nachteile; ohne Zustimmung wird nichts geladen. Später in den Einstellungen änderbar
- Spiele-Tab: liest die Spieleordner aus Eden und zeigt sie als Kacheln mit Icon, Suche, Favoriten per Stern (stehen oben), Sortierung nach Name oder „zuletzt gespielt“, Karte „Weiterspielen“ für das zuletzt gestartete Spiel (aus Edens `launched.json`), Start per Doppelklick (optional im Vollbild)
- Mods-Tab: Mods pro Spiel ein-/ausschalten (direkt in Edens Einstellungen), löschen (Papierkorb) und aus ZIP hinzufügen
- Updates & DLC: pro Spiel Updates/DLCs (NSP, NSZ, XCI, XCZ) hinzufügen, ein-/ausschalten und löschen; über Eden in den NAND installierte Updates/DLCs werden mit den prod.keys erkannt und angezeigt – ohne NAND-Installation, über Edens externe Inhaltsordner (`user\external_content`, wird automatisch in Eden eingetragen)
- Spieldaten: Spielstände pro Spiel sichern und wiederherstellen (ZIP-Backups in `user\save-backups`, vor dem Wiederherstellen wird der aktuelle Stand gesichert), automatisches Backup vor jedem Eden-Update (nur Spiele mit Änderungen, die letzten 10 automatischen pro Spiel bleiben), Shader-Cache pro Spiel oder komplett löschen
- Firmware: aus ZIP oder Ordner installieren/aktualisieren (alte Firmware bleibt bei Fehlern erhalten), löschen, Version anzeigen
- Schlüssel: `prod.keys` (+ `title.keys`) installieren und löschen, Warnung wenn die Keys zu alt für die Firmware sind
- Auswahl der Build-Variante (Standard: PGO, Windows amd64) oder eigener Regex-Filter
- 20 Theme-Vorlagen (dunkel, AMOLED, hell – darunter Aurora, Sunset und Synthwave mit eigenem Farbverlauf) und eigenes Theme mit Farbwähler; Lesbarkeit wird automatisch sichergestellt. Akzent-Verlauf, Hintergrund-Leuchten und Logo folgen dem Theme, der Wechsel breitet sich als Welle aus
- 13 Sprachen (automatische Erkennung, sonst Deutsch)
- Update-Status oben rechts, optional automatische Suche und Installation beim Start
- Einstellungen liegen im Eden-Installationsordner (`eden-updater-settings.json`)
- Eine einzige portable `EdenUpdater.exe`, kein Konsolenfenster
- Selbst-Update: fragt beim Start nach, wenn es eine neue Updater-Version gibt (sonst kein Hinweis); in den Einstellungen manuell suchen und installieren

## Benutzung

`EdenUpdater.exe` aus den [Releases](../../releases) laden, in den Eden-Ordner legen (oder in den Ordner, in den Eden installiert werden soll) und starten.
Beim ersten Start fragt der Updater, ob Eden in diesen Ordner soll. Mit „Nein“ wählst du einen anderen Ordner.
Läuft auf Windows 10/11 ohne Installation (nutzt das eingebaute Windows PowerShell 5.1).

Weil die EXE nicht signiert ist, kann Windows SmartScreen beim ersten Start warnen:
„Weitere Informationen“ → „Trotzdem ausführen“.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `src/*.ps1` | Das eigentliche Programm (PowerShell + WPF), aufgeteilt in nummerierte Teile: Einstellungen, Sprachen, Hintergrund-Jobs, Oberfläche (XAML), Themes/Dialoge, Navigation, die einzelnen Tabs, Selbst-Update, Fenster, Screenshot-Modus |
| `build/merge.ps1` | Setzt die Teile in Namensreihenfolge zu `dist/EdenUpdater.ps1` zusammen – dieses eine Skript wird getestet, gestartet und in die EXE eingebettet |
| `launcher/` | Kleiner C#-Starter, der das Skript in die EXE einbettet |
| `assets/` | Icon |
| `build/build.ps1` | Baut `dist/EdenUpdater.exe` unter Windows |
| `build/build.sh` | Dasselbe unter Linux mit Mono |
| `tests/Test-Script.ps1` | Prüft Syntax, Übersetzungen und XAML |
| `VERSION` | Aktuelle Versionsnummer |

## Bauen

```powershell
.\tests\Test-Script.ps1
.\build\build.ps1
```

## Neue Version veröffentlichen

1. `VERSION` anpassen (z.B. `1.2.0`) und committen
2. Tag setzen und pushen: `git tag v1.2.0` → `git push origin v1.2.0`
3. GitHub Actions testet, baut die EXE und legt sie als Release ab
