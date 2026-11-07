# Eden Updater

<img src="assets/icon.png" width="96" align="right" alt="Icon">

Portabler Updater für die Nightly-Builds des Eden-Emulators unter Windows.
Aktualisiert auf die neueste Version, installiert ältere Builds und zeigt die Patchnotes an.

## Features

- Neueste Nightly installieren oder beliebige ältere Version wählen
- Backup vor dem Update und Wiederherstellen per Klick
- Patchnotes als eigene Seite oder neben der Versionsliste
- Spiele-Tab: liest die Spieleordner aus Eden, Suche, Start per Doppelklick (optional im Vollbild)
- Mods-Tab: Mods pro Spiel ein-/ausschalten (direkt in Edens Einstellungen), löschen (Papierkorb) und aus ZIP hinzufügen
- Auswahl der Build-Variante (Standard: PGO, Windows amd64) oder eigener Regex-Filter
- 17 Theme-Vorlagen (dunkel, AMOLED, hell) und eigenes Theme mit Farbwähler; Lesbarkeit wird automatisch sichergestellt
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
| `src/EdenUpdater.ps1` | Das eigentliche Programm (PowerShell + WPF) |
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
