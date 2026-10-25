# Dead Island 2 Trainer

Erste lokale Trainer-Grundlage für die **Mac-App-Store-Version** von Dead Island 2
auf Apple Silicon. Version **0.1.0** enthält das direkt im Spielprozess laufende
Overlay und den zugehörigen externen Launcher. Cheat-Funktionen sind noch nicht
implementiert.

## Starten

1. Eine bereits laufende App-Store-Spielinstanz regulär beenden.
2. `Dead Island 2 Trainer.app` öffnen.
3. **Spiel mit Overlay starten** wählen.
4. Das Panel mit **F8** oder **⌘⇧T** ein-/ausblenden. Falls macOS die F-Tasten als
   Medientasten verwendet, **fn + F8** drücken.

Die Spiele-App muss für diese erste Version unter
`/Applications/DeadIsland2.app` liegen. Der Launcher prüft die originale
App-Store-Codeidentität und die signierte Hersteller-Teamkennung.
Die Steam-Version ist kein Ziel dieses Trainers.

Ein vorhandener `Dead Island 2 Uncut.app`-Starthelfer unter `/Applications` kann
zusätzlich mitgeladen werden. Die entsprechende Option ist nur bei erkannter
Installation verfügbar. Beide externen Module werden ausschließlich in der
Umgebung des neu gestarteten Spielprozesses gesetzt. Der vorhandene Uncut-Helfer
wird nicht verändert oder in dieses Projekt kopiert.

## Was das Overlay ist

Das externe Modul wird über `DYLD_INSERT_LIBRARIES` beim Start des Originalspiels
geladen. Es fügt eine transparente eigene Ansicht direkt in dessen Spielfenster
ein. Es entsteht kein zusätzliches schwebendes Overlay-Fenster. Die Zeichnung
wird von AppKit/Core Animation über der vorhandenen Metal-Fläche zusammengesetzt;
der Metal-Renderpfad des Spiels wird nicht gepatcht.

Die Ansicht benutzt bewusst **kein Auto Layout**, keine `NSStackView` und keine
Layout-Constraints. Die Unreal-Cocoa-Anbindung kann Fenster-/Layoutänderungen vom
Game-Thread aus auslösen. Das Panel zeichnet seine Inhalte deshalb direkt mit
festen Rahmen. Tastatureingaben werden nur für die beiden eigenen Kürzel abgefangen;
außerhalb des Panels liefert dessen Hit-Test kein Eingabeziel zurück.

Das große Panel zeigt die tatsächliche Prozess-ID, Spielversion und Overlayversion.
Im ausgeblendeten Zustand bleibt ein kleines **Trainer · F8**-Badge stehen.
In der ersten Version werden keine Gesundheits-, Ausdauer-, Munitions- oder
anderen Cheat-Schalter vorgetäuscht.

## Grenzen

Darstellung und beide Hotkeys wurden im Hauptmenü der MAS-Version 0.6.4 geprüft.
Es wurde dafür kein Charakterspielstand im Einzelspieler geladen. Verhalten im
laufenden Gameplay, Koop und längere Spielsitzungen müssen separat geprüft werden.
Die Mausbedienung der gezeichneten Buttons im eigentlichen Spiel ist noch nicht
abschließend verifiziert; die Tastenkürzel funktionieren unabhängig davon.

Der Trainer greift selbst nicht auf Spielstände zu. Das gestartete Spiel führt
seine normalen Speicher- und Cloud-Vorgänge weiterhin selbst aus. Eine Überprüfung
der Uncut-Spielmechanik oder der geräteübergreifenden iCloud-Synchronisierung ist
kein Bestandteil dieser Overlay-Prüfung.

Die Original-Spiele-App wird weder kopiert noch neu signiert oder auf dem Datenträger
gepatcht. Es werden keine globalen DYLD-Einstellungen oder Systemschutzfunktionen
geändert. Laufende Spielprozesse werden nicht automatisch beendet. Zum Beenden
des Overlays das Spiel regulär schließen; beim nächsten normalen Spielstart wird
es ohne Trainer-Modul gestartet.

## Bauen

Benötigt werden macOS 14 oder neuer auf Apple Silicon, Xcode beziehungsweise
Command Line Tools sowie Python 3. Es gibt keine herunterzuladenden Abhängigkeiten
und keinen Bedarf für einen privaten Signierschlüssel oder ein Entwicklerkonto.

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --validate-game
./script/build_and_run.sh --verify
```

Standard-Buildordner:
`~/Library/Developer/DeadIsland2Trainer`. Eine andere feste Ablage außerhalb des
Quellcodes lässt sich über `DI2_TRAINER_BUILD_DIR` auswählen. Für weitere Builds
denselben Ordner wiederverwenden:

```sh
export DI2_TRAINER_BUILD_DIR="$HOME/Library/Developer/DeadIsland2Trainer"
./script/build_and_run.sh run
```

Der Build prüft Sichtbarkeit, Click-through außerhalb des Panels, Größenänderung,
Hotkey-Erkennung und die Abwesenheit von Auto Layout im Overlay. Er prüft außerdem
die Ad-hoc-Signatur des aktuellen Trainers. `--validate-game` ergänzt die lesende
Originalsignatur-Prüfung.

Ein eigener animierter Metal-Testprozess lässt sich starten mit:

```sh
./script/build_and_run.sh --test-host
```

Dieser Test lädt eine eigens für den synthetischen Host gebaute Modulvariante.
Das Produktionsmodul akzeptiert diesen Testprozess nicht. Die Test-App besitzt
einen normalen Beenden-Menüeintrag und unterstützt Vollbild.

Alle Apps, Module, Testprogramme und temporären Austauschbestände werden nur im
separaten Buildordner erzeugt. Vor einem Ersatzbuild laufende Trainer-/Spiel- oder
Testinstanzen regulär beenden. Der Build beendet diese Prozesse nicht selbst.

## Aufbau

```text
Sources/Launcher.m   Originalprüfung und Spielstart mit externem Modul
Sources/Runtime.m    Prozessbegrenzung, Fensteranbindung und Hotkeys
Sources/Overlay.m    Direkt gezeichnetes Panel ohne Auto Layout
Tests/MetalHost.m    Synthetische Metal-Fläche und Overlay-Regressionstests
Resources/          Eigene App-Metadaten
script/             Build- und Start-Einstieg
```

## Lizenz

Copyright © 2026 darkuser89. Projektcode: **GPL-3.0-only**, siehe [LICENSE](LICENSE).
Die Originalsignatur-Prüfung folgt dem eigenen GPL-3.0-Uncut-Launcher. Spielcode,
Spielgrafiken und andere Spielassets sind nicht Teil dieses Repositorys.
Unabhängiges Projekt ohne Verbindung zu PLAION, Deep Silver oder Apple.
