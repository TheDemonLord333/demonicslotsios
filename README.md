# Demonic Slots

Eine Sammlung dämonisch-thematischer Slot-Spiele für iOS. Version 1 enthält
ein vollständig spielbares Spiel, **Infernal Forge** (5 Walzen, 3 Reihen, 10
feste Gewinnlinien, Wild, Scatter/Freispiele), aufgebaut auf einer
wiederverwendbaren Slot-Engine. Drei weitere Spiele (**Blood Cathedral**,
**Abyssal Crypt**, **Cursed Carnival**) sind als "Bald verfügbar" in der
Spielesammlung sichtbar, aber noch nicht implementiert.

> **Nur zur Unterhaltung. Kein Echtgeld, keine Gewinne und keine Auszahlung
> möglich.** Alle Einsätze/Gewinne bestehen ausschließlich aus virtuellen
> Soul Coins ohne realen Geldwert. Kein Login, kein Backend, keine
> In-App-Käufe, keine Werbung, keine Lootboxen, vollständig offline.

## Technische Eckdaten

- Swift 5 / SwiftUI, Minimum Deployment Target iOS 17.0
- SwiftData für Persistenz, SpriteKit (`SpriteView`) für Partikel-Effekte,
  AVFoundation für Audio, native UIKit-Feedback-Generatoren für Haptik
- Keine Drittanbieter-Abhängigkeiten
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (App-Target): UI-Code ist
  implizit `@MainActor`. Reine Daten-/Logiktypen (`Core/Models`,
  `Core/Engine`, `Games/*`, `Shared/DemonicPalette`) sind explizit
  `nonisolated`, damit sie ohne Actor-Hopping in Tests und im
  RTP-Simulator verwendet werden können.

## Architektur

```
DemonicSlots/
  App/                    App-Einstiegspunkt (DemonicSlotsApp.swift)
  Core/
    Models/                SlotGameDefinition + alle Werttypen (Codable, validierbar)
    Engine/                RNG-Wrapper, ReelSpinner, PaylineEvaluator, ScatterEvaluator,
                            SlotEngine, SlotSimulator (DEBUG)
    Persistence/            SwiftData-Modelle (PlayerProfile, GameProgress,
                            GameStatistics, PendingSpin, UserSettings) + PersistenceController
    Services/               GameRegistry, WalletService, SpinTransactionService,
                            SpinSessionController (Zustandsautomat), Haptics/Audio/DateProvider
  Features/
    Collection/             Spielhalle (Startbildschirm, liest aus GameRegistry)
    SlotMachine/             Walzenfeld, Einsatzsteuerung, Paytable-Sheet, Partikelebene
    Statistics/              Globale + Pro-Spiel-Statistiken
    Settings/                Audio/Haptik/Bewegung, Reset, RTP-Simulation (DEBUG)
  Games/
    InfernalForge/          Konkrete SlotGameDefinition für Infernal Forge
    ComingSoonGames.swift    Platzhalter-Definitionen für zukünftige Spiele
  Resources/Games/InfernalForge/  Asset-Key-Dokumentation für spätere Artwork/Audio
  Shared/                  Farbpalette, Color(hex:)-Helper
DemonicSlotsTests/
  Core/                    Unit-Tests für Engine, Wallet, Persistenz, Registry
```

**Ein neues Spiel hinzufügen**, ohne die Engine oder Navigation anzufassen:

1. Neue `SlotGameDefinition` unter `Games/<Name>` erstellen (Symbole, Walzen,
   Paylines, Paytable, Einsatzstufen, Wild/Scatter, `FreeSpinsRules`, Theme,
   Asset-/Audio-/Animations-Keys).
2. Optional: eigene Bonus-Mechanik als `SlotGameFeature`/`SlotGamePlugin`
   implementieren (siehe `Core/Models/SlotGamePlugin.swift`) - Standard-
   mechaniken (Paylines, Wild, Scatter/Freispiele) übernimmt die Engine.
3. In `GameRegistry` registrieren (`register(definition:plugin:)`).
4. Fertig - `CollectionView`, `SlotMachineView`, `PaytableSheetView` usw.
   funktionieren unverändert, da sie ausschließlich über `SlotGameDefinition`
   und `GameRegistry` arbeiten. `GameRegistryTests` demonstriert das anhand
   eines Mock-Spiels.

## Bauen & Testen

Dieses Projekt wurde in einer Linux-Umgebung ohne Xcode/Swift-Toolchain
entwickelt - der Code konnte hier **nicht kompiliert** werden. Vor dem
ersten echten Einsatz bitte in Xcode (26.3 oder neuer) ausführen:

```
open DemonicSlots.xcodeproj
```

- Build: `Cmd+B` bzw. `xcodebuild -project DemonicSlots.xcodeproj -scheme DemonicSlots build`
- Tests: `Cmd+U` bzw. `xcodebuild -project DemonicSlots.xcodeproj -scheme DemonicSlots test`
- Alle neuen Dateien liegen unter den bestehenden
  *file system synchronized groups* (`DemonicSlots/`, `DemonicSlotsTests/`,
  `DemonicSlotsUITests/`) und werden von Xcode automatisch dem jeweiligen
  Target zugeordnet - es war keine manuelle `project.pbxproj`-Bearbeitung
  für einzelne Quelldateien nötig. Signing (`DEVELOPMENT_TEAM`,
  `CODE_SIGN_STYLE = Automatic`) und die Bundle-Identifier
  (`me.thedemonlord333.DemonicSlots*`) wurden unverändert übernommen; nur
  `IPHONEOS_DEPLOYMENT_TARGET` wurde projektweit auf `17.0` gesetzt (siehe
  Aufgabenstellung).

Bitte nach dem ersten Öffnen in Xcode einen vollständigen Build + Testlauf
durchführen und verbleibende Warnungen (insbesondere rund um Swift-6-
Concurrency-Checks, falls das Projekt später auf Swift 6 Language Mode
umgestellt wird) beheben.

## RTP-Tuning (Infernal Forge)

Die Walzenstreifen-Gewichtung in `InfernalForgeSymbols` ist ein
**Startwert**, kein gemessenes Ergebnis. Zielkorridor laut Vorgabe: ca.
94-96 % RTP bei mittlerer bis hoher Volatilität. So wird er in Xcode
gemessen und nachjustiert:

1. App im DEBUG-Build starten → Einstellungen → Abschnitt „Entwicklung“ →
   „RTP-Simulation (Infernal Forge)“ → simuliert ≥ 1.000.000 Spins
   (`SlotSimulator`, inkl. Freispielrunden) und zeigt RTP, Trefferquote,
   Bonusquote und maximale Auszahlung.
2. Alternativ headless: `SlotSimulatorTests` (Swift Testing, `#if DEBUG`)
   laufen standardmäßig nur mit kleinen Stichproben (schnell für CI); für
   eine volle Messung `SlotSimulator.run(definition:betPerLine:spinCount:)`
   mit `spinCount: 1_000_000` aufrufen.
3. Gewichte in `InfernalForgeSymbols.weights` anpassen (häufigere/seltenere
   Symbole), erneut messen, bis der RTP im Zielkorridor liegt.
4. Die fertige App zeigt **keinen** festen RTP-Wert an, solange er nicht
   durch diese Simulation bestätigt wurde.

## Wichtige Spielregeln (Kurzreferenz)

- Guthaben/Einsätze/Gewinne ausschließlich `Int64`, niemals negativ, niemals
  Overflow (siehe `WalletService`).
- Ein Spin läuft transaktionssicher über `SpinTransactionService`: Ergebnis
  wird vor jeder Kontobewegung vollständig berechnet, als `PendingSpin` mit
  eindeutiger Transaktions-ID gespeichert, Einsatz genau einmal abgebucht,
  nach der Animation Gewinn genau einmal gutgeschrieben, Transaktion
  abgeschlossen. Wird die App mittendrin beendet, erkennt
  `recoverPendingSpins(...)` beim nächsten Start denselben Spin und
  schließt ihn ab, ohne erneut abzubuchen.
- Zustandsautomat `SlotMachineState` (`idle → preparing → spinning →
  stopping → evaluating → celebrating → enteringBonus/bonusSummary` bzw.
  `error`) verhindert Mehrfach-Spins durch schnelles Antippen.
- Soul Rescue: unter 10 Soul Coins einmal pro Kalendertag 1.000 Soul Coins
  gratis (`WalletService.claimSoulRescue()`), Datum über injizierbaren
  `DateProvider` testbar.
