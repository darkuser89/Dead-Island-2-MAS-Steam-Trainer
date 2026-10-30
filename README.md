# Dead Island 2 Trainer für macOS

<img src="Resources/AppIcon.png" width="128" height="128" alt="Trainer-Icon mit Schädel und orangefarbenem Schalter">

Externer Einzelspieler-Trainer **0.6.10** für **Dead Island 2 0.6.4** auf
Apple Silicon. Unterstützt die Mac-App-Store- und Steam-Version mit einem
kompakten Ingame-Overlay und 26 Bedienelementen.

Die Original-Spiele-Apps bleiben unverändert. Das Overlay läuft im gestarteten
Spielprozess; Geld, XP, Reparaturen und Inventarergänzungen können vom Spiel
normal gespeichert werden. Der Trainer ist kein Save-Editor.

## Launcher

Die Hauptansicht zeigt **Dead Island 2**, die segmentierte Auswahl **Mac App Store /
Steam**, die gefundene Installation mit Spielsymbol und einen großen orangefarbenen
Startknopf sowie einen zweiten roten Knopf **Spiel Uncut mit Trainer starten**.
Der orange Knopf lädt ausschließlich den Trainer. Der rote lädt zusätzlich den
vorhandenen externen Uncut-Helfer und ist nur bei MAS mit verfügbarem Helfer aktiv.
Über **Ändern …** wird die zur ausgewählten Edition gehörende App
zugeordnet. Das **Zahnrad** oder **⌘ + ,** öffnet die vorhandenen Overlay-Optionen
und Positionsvorgaben in einem eigenen Fenster.
Der Steam-Client bleibt über **Steam öffnen** in der Steam-Spielkarte erreichbar.

Auf macOS 26 oder neuer verwendet der Launcher native Liquid-Glass-Flächen und
Systemknöpfe; die Glasflächen teilen sich einen Container. Die Einstellungen
verwenden ebenfalls das Systemmaterial. Auf macOS 14/15 sowie bei Builds mit
älteren SDKs steht eine native Materialdarstellung bereit. Helle/dunkle Darstellung
und die Systemeinstellung zur reduzierten Transparenz werden durch AppKit behandelt.
Launcher, Einstellungen und Ingame-Overlay verwenden den gemeinsamen
Material-Wrapper aus der Mac-Trainer-Vorlage 1.1. Die native Glasfläche behält
normale Koordinaten; beim Overlay wird nur ihr Inhalt skaliert. Reduzierte
Transparenz oder erhöhter Kontrast wählen eine deckende Fläche und werden auch
bei Änderungen während der Laufzeit berücksichtigt. Der Launcher verwendet eine
normale sichtbare macOS-Titelleiste mit System-Fensterhintergrund.

Die Overlay-Anzeige aktualisiert Zeichenanforderungen und Bedienungstexte nur
bei Änderungen. Verborgene Overlays behalten ausschließlich den neuesten Zustand;
beim Öffnen wird dieser sofort dargestellt. Sichtbare Zeilen besitzen unabhängige
Darstellungskopien, damit auch Änderungen am selben Zustandsobjekt erkannt werden. Im synthetischen Test verursachen 100 unveränderte Statusabfragen
keine neuen Zeichenanforderungen; eine Geldwertänderung aktualisiert genau ihre
Zeile. Eine höhere Ingame-Bildrate wurde damit nicht nachgewiesen.

## Voraussetzungen

- Apple Silicon, macOS 14 oder neuer.
- Eine eigene Originalinstallation eines unten aufgeführten Spiel-Builds.
- Für Steam: ein laufender und angemeldeter Steam-Client.
- Zum Bauen: Xcode/Command Line Tools mit `clang`, `sips`, `iconutil`, `codesign`
  sowie Python 3. Es werden keine zusätzlichen Pakete heruntergeladen.

| Edition | Spielversion | Bundle-ID | Freigegebene Mach-O-UUID |
| --- | --- | --- | --- |
| Mac App Store | 0.6.4, arm64 | `com.plaion.DeadIsland2Usk` | `33AE24EE-5FDC-379A-BD9E-8B1BDE36B6EC` |
| Steam | 0.6.4, arm64 | `com.plaion.DeadIsland2` | `9EB36C68-45E5-3C11-B465-FFD49164B1DA` |

Eine übereinstimmende Versionsnummer allein genügt nicht. Andere UUIDs und
Architekturen werden abgewiesen. Das Projekt enthält keine Spiele, Spielstände,
Originalgrafiken oder fremden Trainer-Binaries.

## Bauen

```sh
git clone https://github.com/darkuser89/Dead-Island-2-MAS-Steam-Trainer.git
cd Dead-Island-2-MAS-Steam-Trainer
export DI2_TRAINER_BUILD_DIR="$HOME/Library/Developer/DeadIsland2Trainer"
./script/build_and_run.sh --build-only
```

Die fertige App liegt unter
`$DI2_TRAINER_BUILD_DIR/Dead Island 2 Trainer.app`. Ohne Umgebungsvariable ist
`~/Library/Developer/DeadIsland2Trainer` das Buildziel. Den gleichen Buildordner
wiederverwenden; Builds innerhalb des Quellordners werden abgewiesen.

Der Build kompiliert Launcher und Overlay, erstellt das App-Icon, signiert die
App lokal ad hoc, prüft die Signatur und führt die synthetischen Tests aus.
Es werden weder private Signierschlüssel noch Administratorrechte benötigt.
Die lokale Ad-hoc-Signatur ist keine Developer-ID-Signatur oder Notarisierung.

| Befehl | Verhalten |
| --- | --- |
| `--build-only` | App bauen und prüfen; kein Launcher- oder Spielstart |
| `--update-only` | Externe App atomar ersetzen, auch während einer laufenden Sitzung; keine Prozesse starten oder beenden |
| `run` oder `--verify` | Bauen, prüfen und den Launcher öffnen; `--verify` prüft zusätzlich dessen Prozess |
| `--test-host` | Bauen und einen synthetischen Metal-Testhost öffnen |
| `--validate-game` | Zusätzlich die Originalsignatur der ausgewählten MAS-Installation lesend prüfen; kein Spielstart |

Vor einem normalen Ersatzbuild laufende Trainer-, Spiel- und Testinstanzen
regulär schließen. `--update-only` verändert bereits geladene Module nicht.
Eine neue Overlay-Version wird erst beim nächsten regulären Spielstart über
den Trainer geladen. Temporäre Austauschbestände werden nach dem Build entfernt;
die neueste App sowie `OverlayPreview.png` und `LauncherPreview.png` bleiben im separaten Buildordner.

## Automatische Builds und Releases auf GitHub

[GitHub Actions](https://github.com/darkuser89/Dead-Island-2-MAS-Steam-Trainer/actions/workflows/macos.yml)
baut die App bei Pushes auf `main` und Pull Requests auf einem GitHub-Mac mit Apple
Silicon. Über **Run workflow** kann ein Build auch manuell gestartet werden.
Jeder erfolgreiche Lauf stellt ein Build-Artefakt mit App-ZIP, SHA256-Prüfsumme
und Versionshinweisen für sieben Tage bereit. Builds liegen auf dem Runner
außerhalb des Quellordners; Spiele und Saves werden dafür nicht benötigt.

Ein Push eines Versions-Tags veröffentlicht nach bestandenen Tests zusätzlich
ein dauerhaftes GitHub-Release:

1. App-Version und Buildnummer in `Resources/Info.plist` aktualisieren sowie
   README, Versionsanzeigen und `RELEASE_NOTES.md` anpassen.
2. Änderungen committen und auf `main` pushen.
3. Passendes Tag setzen und pushen, zum Beispiel für diesen Stand:

   ```sh
   git tag v0.6.10
   git push origin v0.6.10
   ```

Tag und App-Version müssen exakt übereinstimmen. Bereits veröffentlichte Releases
werden nicht überschrieben; für Änderungen eine neue Version verwenden.
Der Workflow lädt zuerst einen Entwurf samt geprüften Dateien hoch und
veröffentlicht ihn danach. Ein unterbrochener Upload lässt sich über **Re-run jobs**
fortsetzen, solange das Release noch ein Entwurf ist.

Benötigt werden aktivierte GitHub Actions. Der Release-Job erhält ausschließlich
für das Veröffentlichen `contents: write` über den automatisch bereitgestellten
`GITHUB_TOKEN`; eigene Tokens und Apple-Zugangsdaten sind nicht nötig. Die App ist
weiterhin ad hoc signiert und nicht notarisiert. Auf GitHub werden synthetische
Tests ausgeführt; lesende Originalspiel-Abgleiche werden dort ausdrücklich als
nicht durchgeführt gemeldet. Echte Ingame-Tests ersetzt der Workflow nicht.

Das gleiche geprüfte Paket kann lokal erstellt werden:

```sh
python3 script/package_release.py --build-dir "$DI2_TRAINER_BUILD_DIR" --expected-tag v0.6.10
```

Es entsteht im separaten Buildordner unter `Release/`. Das Skript prüft
App-Metadaten, Signatur, Architektur und einen ZIP-Rückvergleich einschließlich
Ausführungsrechten, bevor es das bisherige Paket ersetzt.

## Spiel auswählen und starten

1. Launcher öffnen und **Mac App Store** oder **Steam** auswählen.
2. Den Installationspfad prüfen; bei Bedarf **Spiele-App wählen …** verwenden.
3. Für Steam den Client öffnen und anmelden. **Steam öffnen** startet nur den Client.
4. **Spiel mit Trainer starten** wählen und den Einzelspieler laden.

MAS wird standardmäßig unter `/Applications/DeadIsland2.app` gesucht. Für Steam
werden die Standardbibliothek und die in `steamapps/libraryfolders.vdf`
eingetragenen Bibliotheken berücksichtigt, einschließlich externer Laufwerke.
Ein manuell gewählter Pfad hat Vorrang. Beide Pfade und die zuletzt gewählte
Edition werden nur in den lokalen Launcher-Einstellungen gespeichert.

Der Launcher prüft Originalsignatur, Edition und Hersteller-Teamkennung
`XSBJ2Q9R2T`. Die Steam-App-ID `934700` und die Overlay-Umgebung werden nur dem
neuen Spielprozess übergeben. Steam-Startoptionen und Spieldateien bleiben
unverändert.

Ein bereits installierter externer Helfer unter
`/Applications/Dead Island 2 Uncut.app` kann optional **nur bei MAS** mitgeladen
werden, indem der rote Startknopf gewählt wird. Er ist nicht enthalten und wird
nicht verändert; für den normalen Trainer-Start wird er nicht benötigt.
Der Trainer allein ändert keine USK-Einstellung und verspricht keine iCloud-Funktion.

## Overlay bedienen

- Beim Spielstart bleiben Panel und Badge verborgen, unabhängig von der letzten Sitzung.
- **⌘ + ^**: Overlay anzeigen/verbergen; beim Öffnen wird die Maus automatisch freigegeben. Aktive Schalter bleiben an.
- **⌘⌥ + ^**: optional Mausbedienung umschalten, ohne das Panel zu verbergen. Beim nächsten Öffnen ist die Maus wieder frei.
- **Esc** oder **×**: Panel schließen und Spielsteuerung zurückgeben.
- **Alles aus**: aktuelle Belegung im Launcher/Overlay; bei erkanntem F12-Systemkonflikt wird meist **Control (⌃) + F12** verwendet. Funktioniert auch beim Laden und während einer Zahleneingabe.
- **− / +** in der Kopfzeile: Größe ändern; **▾**: auf die Kopfzeile einklappen.
- Titelleiste ziehen: Position ändern, sofern im Launcher freigegeben.

Standardgröße: ungefähr **486 × 331 Punkte**. Position, Größe, Sichtbarkeit,
Mausbedienung und optionales Badge lassen sich im Launcher einstellen. Diese
Anzeigeoptionen werden gespeichert; jeder neue Spielprozess startet jedoch mit
verborgenem Panel und Badge und vorbereiteter Mausbedienung. Cheat-Schalter starten je nach Auswahl mit den gespeicherten Einstellungen
oder ausgeschaltet. Bei macOS-Medientasten gegebenenfalls **fn** verwenden.
**⌃** bedeutet Control, **⇧** Umschalt, **⌥** Option/Alt und **⌘** Command.

**Grün** bestätigt eine aktive Wirkung; **Orange** bedeutet eingeschaltet,
aber noch auf passende Ausrüstung, Freischaltung oder eine Bestätigung wartend.
Tooltips erklären die jeweilige Grenze. Zahlenwert anklicken, eingeben und mit
**Enter** übernehmen; **Esc** bricht die Eingabe ab. **GO** führt eine Aktion
**einmalig** aus. Bei geöffnetem Panel wird die Maus freigegeben und der
Spiel-Viewport ignoriert Bewegungs-/Schusseingaben; die Welt läuft weiter.

## Konfliktprüfung der Tastatur

Freie F1–F12-Belegungen bleiben erhalten. Beim Start und bei Rückkehr ins Spiel
liest der Trainer die aktivierten systemweiten macOS-Kürzel über
`CopySymbolicHotKeys`. Bekannte Option-F-Hardware-/Bedienungshilfen-Kürzel
werden ebenfalls ausgespart. Die macOS-Einstellungen werden nicht verändert.

Nur Konflikte erhalten kurze Ersatzbelegungen mit höchstens **einer Zusatztaste**.
Zuerst wird dieselbe Taste mit Control, Shift oder Option geprüft. Ist dort nichts
frei, folgt **Alt/Option + 1–0**, danach **Control + 1–0**. Mehrere gleichzeitig zu
haltende Zusatztasten werden für Ersatzbelegungen nicht verwendet. Freie
ursprüngliche Trainer-Tasten haben Vorrang; Ersatzbelegungen dürfen diese nicht
übernehmen. Gibt es keinen kurzen freien Ersatz, bleibt nur dieses Tastenkürzel aus.
Mausaktionen bleiben erreichbar.
Die tatsächliche Zuordnung steht direkt an der jeweiligen Overlay-Zeile; die
Einstellungen zeigen eine Liste aller Umlegungen. Die folgende Tabelle zeigt
**Basisbelegungen**, die bei Systemkonflikten automatisch ersetzt werden.

Alte konfliktbehaftete Kürzel werden nicht zusätzlich als Alias weiterverwendet.
Eine fehlgeschlagene native Registrierung wegen bereits belegter Tasten wird
auch nicht durch den AppKit-Ersatzpfad umgangen. Die Erkennung umfasst macOS-
Systemkürzel; beliebige Drittanbieter-Hotkeys und app-spezifische Menübelegungen
sind darüber nicht vollständig abfragbar. Bei nicht lesbarer Systembelegung
meldet die Anzeige die konservative Ersatzprüfung ausdrücklich.

## Funktionen

| Funktion | Taste | Umfang |
| --- | --- | --- |
| Gottmodus | F1 | Eigener nativer God-Mode-Grund |
| Gesundheit auffüllen | F6 | Auffüllen alle 0,25 Sekunden |
| Ausdauer | F2 | Abzug verhindern und auffüllen |
| Waffenhaltbarkeit | F7 | Gehaltene Nahkampfwaffe reparieren und schützen |
| KI ignoriert Spieler | ⌥F5 | Ignorierzustand der lokalen Spieler-ID |
| Spielertempo | ⇧F2 | Zeitfaktor des lokalen Spieler-Actors |
| Bewegungstempo | ⇧F3 | Eigener entfernbarer Laufgeschwindigkeits-Modifikator |
| Spieltempo | ⇧F4 | Zeitfaktor der aktuellen Einzelspieler-Welt |
| Super-Kraftschaden | ⇧F9 | Sehr hoher Nahkampf-Stabilitätsschaden |
| Kraftschaden × | ⇧F8 | Multiplikator des Nahkampf-Kraftattributs |
| One-Hit (Nahkampf) | ⇧F7 | Sehr hoher Nahkampf-Grundschaden |
| Schaden × (Nahkampf) | ⇧F6 | Multiplikator des Nahkampf-Schadensattributs |
| Verteidigung × | ⇧F5 | Eingehenden Schaden reduzieren |
| Geld setzen | ⇧F1 | Zielbetrag einmalig setzen; F4/F5 geben +1.000/+10.000 |
| Verbrauch & Materialien | ⌥F2 | Vorhandene erkannte gewöhnliche Stapel nachfüllen |
| Stapel behalten | ⌥F3 | Zusätzlich Munitionsstapel schützen |
| Crafting ohne Kosten | ⌥F4 | Geld/Material bei freigeschalteten unterstützten Rezepten |
| Munitionsreserve | F3 | Reserve-Flag der gehaltenen Schusswaffe |
| Kein Nachladen | F8 | Separates Magazin-Flag und Auffüllen |
| Präzision | ⇧F10 | Unterstützte Standard-Spread-Handler |
| Kein Rückstoß | ⇧F11 | Unterstützte Standard-Recoil-Handler |
| Curveball sofort bereit | F11 | Lokale Quick-Throw-Abklingzeiten zurücksetzen |
| Wut auffüllen | F9 | Einmalig, bei freigeschaltetem Wutgewinn |
| Wut ohne Zeitlimit | F10 | Nativen Wutabzug verhindern |
| XP bis Maximallevel | ⌥F1 | Einmalige Gabe bis zur regulären Levelschwelle |
| XP-Multiplikator | ⇧F12 | Neue XP-Zuwächse ergänzen, ohne eigene Gaben erneut zu multiplizieren |

Alle 26 Anbindungen sind im Code vorhanden. Das ist keine vollständige
Ingame-Bestätigung aller Schalter, Waffenarten oder Spielsituationen.

### Grenzen und gespeicherte Änderungen

- Gesundheit auffüllen verhindert allein keinen tödlichen Treffer zwischen zwei
  Aktualisierungen. Skriptschaden und Skript-Unverwundbarkeit sind separat zu prüfen.
- Schaden, One-Hit, Kraft und Haltbarkeit gelten für Nahkampfwaffen. Präzision
  und Rückstoß benötigen passende Standard-Handler der Schusswaffe.
- Inventarschalter schützen erkannte gewöhnliche Stapel. Questobjekte, Schlüssel,
  Sammlungen, Rezepte, Geld und Waffen werden nicht nachgefüllt. Auch Verkauf
  oder Ablegen eines geschützten gewöhnlichen Stapels kann Nachfüllen auslösen.
- Crafting unterstützt drei erkannte native Zutatentypen. Es schaltet keine
  Rezepte, Fähigkeiten oder DLCs frei.
- Ausschalten stellt eigene Flags, Faktoren und Modifikatoren wieder her.
  Bereits erhaltenes Geld, XP, Reparaturen oder Gegenstände werden nicht entfernt.
  Das Spiel kann sie regulär speichern; der Trainer erstellt keine Save-Backups.

### Gebietswechsel und Koop

Bei einem Gebietswechsel im Einzelspieler bleiben Schalter und Faktoren gewählt.
Die Wirkungen auf alte Objekte werden gelöst und nach dem Laden neu gebunden.
XP- und Inventar-Basiswerte werden neu erfasst. Einmalige Geld-, XP- oder
Wut-Aktionen werden bei einem Kontextwechsel verworfen, damit sie später nicht
versehentlich ausgeführt werden.

Eine bestätigte Netzwerksitzung sperrt die Cheats, nimmt eigene Wirkungen zurück
und löscht die Auswahl. Das gilt auch bei allein gestarteter Koop-Sitzung.
Zurück im Einzelspieler muss neu aktiviert werden. Overlay, Mausbedienung und
das aktuelle Alles-aus-Kürzel bleiben unabhängig davon verfügbar.

## Cheat-Auswahl beim nächsten Start laden

Der Schalter im Hauptfenster speichert die gewünschte Startweise. Er ist wie in
Vorlage 1.1 zunächst eingeschaltet. Schalter und Zahlenwerte werden getrennt für
Mac App Store und Steam gespeichert, solange der Launcher läuft. Die Auswahl
wird erst nach erkanntem Einzelspieler angewendet. Geld setzen, Geld hinzufügen,
Wut auffüllen und XP bis Maximallevel werden niemals automatisch ausgeführt.

Ausgeschaltet startet das Spiel ohne gespeicherte Cheat-Auswahl. Die Auswahl
im laufenden Spiel und das Wiederanwenden bei Gebietswechseln bleiben davon
unabhängig. Ein bestätigter Netzwerkmodus löscht die angeforderten Schalter;
auch „Cheats aus“ während des Ladens wird gespeichert. Das Overlay startet
weiterhin verborgen. Beide Startknöpfe verwenden dieselbe gewählte Einstellung.

Release-Builds auf GitHub wählen Xcode 26.3 ausdrücklich aus. Die Paketprüfung
verlangt schwach gebundene Liquid-Glass-Symbole in Launcher und Overlay, damit
auch der Download natives Glas auf macOS 26+ enthält. Ältere Systeme verwenden
weiterhin den Material-Fallback; das Mindestziel bleibt macOS 14.

## Tests und Kompatibilitätsprüfung

Der Build prüft synthetisch unter anderem alle 26 Anbindungen, Wiederherstellung,
Waffen- und Besitzerwechsel, tote Weak-Referenzen, numerische Grenzen,
XP-Rückkopplung, Gebietswechsel, Warteschlange und Netzwerksperre. Launcher-Tests prüfen beide Store-Auswahlen, fehlende/laufende Installationen,
Start-/Einstellungsaktionen und kompakte Abmessungen ohne Spielstart. UI-Tests prüfen
Hotkeys, alle 26 Mausaktionen in verschiedenen Größen/Positionen, Zahlenfelder,
Ziehen, Verbergen und Cursor-Wiederherstellung. Die übernommenen Darstellungstests
prüfen zusätzlich 1.000 verborgene/sichtbare Zustände, unabhängige Zeilenkopien,
Änderungen im selben Zustandsobjekt, vollständige Zeilen nach nativem Layout sowie
Material-/Kontrastwechsel zur Laufzeit. Legacy-Fallback-Tests auf einem neuen
macOS sind keine tatsächlich ausgeführten Tests auf macOS 14/15. Editionsprüfungen verwenden
selbst erzeugte kleine App-Fixtures; Originalspiele und Saves werden dafür nicht
benötigt. Der Build startet kein echtes Spiel.

`Tests/verify_game_abi.py` gleicht 95 Symbole, drei Crafting-Tabellen und drei
Abschnittshashes lesend mit vorhandenen unterstützten Original-Builds ab.
Fehlende oder unbekannte Builds werden ausdrücklich als **nicht geprüft**
ausgegeben; synthetische Tests ersetzen diesen Abgleich nicht. Für andere Pfade:

```sh
export DI2_ABI_STEAM_APP="/Pfad/zur/Steam/DeadIsland2.app"
export DI2_ABI_MAS_APP="/Pfad/zur/MAS/DeadIsland2.app"
python3 Tests/verify_game_abi.py .
```

Originalsignaturen lassen sich nach dem Bauen separat prüfen, ohne Spielstart:

```sh
"$DI2_TRAINER_BUILD_DIR/Dead Island 2 Trainer.app/Contents/MacOS/Trainer" --validate-only mas
"$DI2_TRAINER_BUILD_DIR/Dead Island 2 Trainer.app/Contents/MacOS/Trainer" --validate-only steam
```

Für Version 0.6.10 sind Build, Signatur, synthetische Tests, Launcher-Darstellung
und der lesende MAS-ABI-Abgleich geprüft. Verborgener Sitzungsstart trotz alter
Anzeigeoptionen und automatische Mausbedienung beim Öffnen/Wiederöffnen sind
synthetisch geprüft. Die getrennten Startknöpfe wurden mit
Testaktionen ohne Spielstart geprüft. Der Steam-ABI-Abgleich war für Version
0.6.3 erfolgreich; für 0.6.10 wurde er mangels erreichbarer Installation nicht
wiederholt. Steam-Betrieb einschließlich Waffenfunktionen sowie Mausbedienung wurden
vom Nutzer als funktionierend gemeldet. Es liegt weiterhin keine vollständige
Ingame-Testmatrix für alle 26 Funktionen, Gebiete, Waffenarten, langen Sitzungen,
Koop-Übergänge und iCloud-Synchronisierung vor.

## Projektaufbau

| Pfad | Inhalt |
| --- | --- |
| `Sources/Launcher.m`, `Sources/LauncherView.*` | Editionswahl, kompakter Launcher, Einstellungen, Originalprüfung und Spielstart |
| `Sources/Runtime.m` | Prozessbegrenzung, Fenster- und Ereignisanbindung |
| `Sources/TrainerMaterial.*`, `docs/UI.md` | Gemeinsame Glas-/Vibrancy-/Kontrast-Flächen und Skalierungsregeln |
| `Sources/Overlay*` | Panel, Maus/Tasten, Anzeigeoptionen und Cursor-Modus |
| `Sources/TrainerFeatures.*` | Gemeinsamer Funktions- und Tastenkatalog |
| `Sources/GameAccess.*` | Versionsgebundene native Anbindungen und begrenzte Datenzugriffe |
| `Sources/GameBridge.*`, `Sources/ExtraFeatures.*` | GameThread-Aufträge, Effekte und Wiederherstellung |
| `Sources/GameEdition.*` | Build-Identität und Installationssuche |
| `Resources/` | App-Metadaten, ABI-Definition und eigenes Icon samt Generierungsprompt |
| `Tests/` | Synthetische Engine-/UI-Tests und lesender ABI-Abgleich |
| `script/` | Gemeinsamer Build-Einstieg |

Alle Unreal-Zugriffe laufen asynchron auf dem GameThread, höchstens ein Auftrag
zugleich. Die Anbindung berücksichtigt ASLR und validiert Objektklassen,
Besitzer und Weak-Referenzen. Es werden Daten bereits schreibbarer Seiten
verändert; Code-Instruktionen und Speicherzugriffsrechte bleiben unangetastet.
Crafting verwendet private Dispatch-Tabellen einzelner Instanzen und verändert
keine Originaltabellen. Details für Änderungen: [CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

Copyright © 2026 darkuser89. **GPL-3.0-only**, siehe [LICENSE](LICENSE).
Das eigene Icon wurde mit integrierter Bildgenerierung erstellt; der verwendete
Prompt liegt in [Resources/AppIcon.prompt.txt](Resources/AppIcon.prompt.txt).

Unabhängiges Community-Projekt; keine Verbindung zu PLAION, Deep Silver, Dambuster
Studios, Valve oder Apple. Namen und Marken gehören ihren jeweiligen Inhabern.
