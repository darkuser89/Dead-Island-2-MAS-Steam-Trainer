# Am Trainer mitarbeiten

Das Projekt verwendet Objective-C/AppKit und GPL-3.0-only. Änderungen sollen
Mac App Store und Steam berücksichtigen, ohne Original-Spieldateien zu verändern.

## Lokal prüfen

```sh
export DI2_TRAINER_BUILD_DIR="$HOME/Library/Developer/DeadIsland2Trainer"
./script/build_and_run.sh --build-only
```

Der Build verlangt Apple Silicon, macOS 14+, Xcode/Command Line Tools und Python 3.
Er behandelt Compilerwarnungen als Fehler und führt die synthetischen Tests aus.
Ein Spielstart erfolgt ausschließlich über eine ausdrückliche Launcher-Aktion.
Für einen Ersatzbuild während einer Sitzung `--update-only` verwenden; geladene
Module bleiben bis zum nächsten regulären Spielstart unverändert.

Builds, App-Bundles, Caches und Laufzeitlogs außerhalb des Quellordners halten.
Keine Originalspiele, Saves, Zugangsdaten oder Signierschlüssel einchecken.
Die Icon-Quelldatei ist versioniert; `.icns` und Iconsets entstehen nur im Build.

## GitHub Actions und Veröffentlichung

`.github/workflows/macos.yml` verwendet den gleichen Build mit allen synthetischen
Tests auf `macos-15` (arm64). Actions sind auf konkrete Commit-SHAs festgelegt.
Pushes auf `main`, Pull Requests und manuelle Läufe liefern ein kurzlebiges
Download-Artefakt. Nur gepushte `v*`-Tags lösen den Release-Job mit Schreibrecht aus.
Tag und `CFBundleShortVersionString` müssen übereinstimmen. Versionshinweise unter
`RELEASE_NOTES.md` vor dem Taggen aktualisieren; die Release-Dateien werden über
`script/package_release.py` erstellt und geprüft. Veröffentlichte Versionen werden
nicht überschrieben. Keine Spiele oder Zugangsdaten für die CI hinterlegen.

## Native Anbindungen ändern

- Neue Spiel-Builds nicht allein anhand ihrer Versionsnummer freigeben.
  Bundle-ID, Architektur, UUID und tatsächlich verwendete native Anbindungen prüfen.
- `Resources/GameABI.json` und `Sources/GameAccess.m` gemeinsam aktualisieren.
  `Tests/verify_game_abi.py` gleicht vorhandene Original-Builds ausschließlich lesend ab.
  Eigene Installationspfade über `DI2_ABI_MAS_APP` bzw. `DI2_ABI_STEAM_APP` übergeben.
- Unreal-Zugriffe auf dem GameThread ausführen. Klassen, lokale Besitzer und
  Weak-Referenzen vor nativen Aufrufen validieren.
- Wiederherstellung, Objektwechsel, Ladepausen und Netzwerksperre erhalten.
  Einmalaktionen dürfen nach einem Kontextwechsel nicht erneut abgespielt werden.
- GameThread-/AppKit-Grenzen beachten. Im Spielfenster kein Auto Layout einführen;
  das Spiel kann seine Fenster auch vom GameThread verändern.
- Regressionstests sollen Fehler und Grenzen prüfen. Synthetische Tests und
  echte Ingame-Beobachtungen im Änderungsbericht ausdrücklich unterscheiden.

## Fehler melden

Bitte Trainer-Version, macOS-Version, Edition, Spielversion und reproduzierbare
Schritte nennen. Bei einem orangefarbenen Schalter auch den Tooltip und die
verwendete Waffenart angeben. Keine vollständigen Saves oder Original-Binaries
hochladen. Benutzernamen und private Pfade aus Diagnoseausschnitten entfernen.

Ein Pull Request sollte das Problem, das resultierende Verhalten, ausgeführte
Prüfungen und noch offene Ingame-Tests knapp beschreiben. Der Build verwendet
lokale Ad-hoc-Signaturen; Developer-ID-Signatur und Notarisierung sind kein
Bestandteil dieses Workflows.
