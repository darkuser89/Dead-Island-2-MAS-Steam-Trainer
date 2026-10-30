# Materialien und Darstellung

Die Bausteine aus Mac Trainer Template 1.1 sind für die 26 Dead-Island-2-Funktionen
angepasst. Spielanbindung, GameThread-Taktung, Kontextprüfung, Einmalaktionen und
die kurzen konfliktgeprüften Tastenkürzel bleiben davon unabhängig.

`DI2TrainerMaterial` hält eine stabile `contentView`. macOS 26+ verwendet natives
Liquid Glass, ältere Systeme native Vibrancy. Reduzierte Transparenz oder erhöhter
Kontrast wählen eine deckende Fläche. Workspace-Mitteilungen aktualisieren diese
Darstellung zur Laufzeit, ohne Inhalt, Bearbeitungszustand oder Klickhandler neu
anzulegen. Neue APIs bleiben versionsgeschützt und schwach verlinkt. `tintColor`
bewahrt die orange/rote Kennzeichnung der Startaktionen auch im deckenden Modus.

`DI2OverlayRoot.panel` liefert die physische Materialfläche. `panelContent` liefert
den Inhalt mit logischen 540-Punkte-Koordinaten. Nur dessen Bounds werden über
`logicalContentSize` skaliert. Die native Materialhierarchie selbst erhält gleiche
Frame-/Bounds-Abmessungen; ihre internen Unteransichten werden nicht verändert.
Eigene Zeilen und Root-Geometrie bleiben manuell. Frameworkinternes Layout gehört
ausschließlich dem nativen AppKit-Material.

Die Materialfläche leitet Hit-Tests direkt an den bestehenden Inhalt weiter.
Es gibt keinen zweiten Handler für denselben Klick. Verbergen und Anzeige ohne
Maus bleiben durchlässig für Spielklicks. Eine begonnene Mausfolge wird bis Mouse-up
genau einmal konsumiert, auch beim Schließen oder Ziehen außerhalb des Panels.

Verborgene UI behält den letzten Gesamtzustand, aktualisiert jedoch keine
Zeilendarstellung. Beim Öffnen wird er sofort übernommen. Sichtbare Zeilen halten
unabhängige Kopien von Verfügbarkeit, Auswahl, Anwendung, Zahlenwert und Notiz.
Dadurch bleiben Änderungen am selben Bridge-Objekt erkennbar. Unveränderte Zeilen
behalten ihre Darstellung und Accessibility-Texte. Aktionen und Hotkeys greifen
stets auf den aktuellen Gesamtzustand zu, nicht auf die Darstellungskopien.

`Tests/PresentationTests.m` prüft Materialien, simulierten Legacy-/Kontrastpfad,
Laufzeitmitteilungen, 1.000 verborgene/sichtbare Aktualisierungen, In-place-
Änderungen, vollständige Zeilen nach nativem Layout, Skalierung, Klicks, Ziehen und
Zahleneingabe. Der gemeinsame Build führt diese zusätzlich zu den vorhandenen
Trainer-, Maus-, Hotkey- und Editionsprüfungen aus. Diese Tests sind keine
Ingame-Beobachtung, FPS-Messung oder Ausführung auf einem älteren macOS.

Die Startoption „Cheat-Auswahl beim nächsten Start laden“ im Hauptfenster ist
unabhängig von der Overlay-Sichtbarkeit. `SelectionSettings` validiert die
26 Schalter und Zahlenwerte; Einmalaktionen werden immer herausgefiltert.
Der Launcher speichert nur Berichte der gestarteten Sitzung, Edition und PID.
Er muss dafür während des Spiels geöffnet bleiben. Die Bridge übernimmt
Startwerte vor dem ersten GameThread-Poll und wendet sie erst im Einzelspieler
an. Initiale Ladezustände überschreiben keine Auswahl; Netzwerksperre und
explizites Ausschalten während des Ladens werden gespeichert.
