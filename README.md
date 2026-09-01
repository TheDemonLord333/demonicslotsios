# Demonic Slots

Eine Sammlung dämonisch-thematischer Casino-Spiele für iOS. Aktuell
vollständig spielbar sind zwei eigenständige Spiele, die sich dasselbe
globale Soul-Coin-Guthaben teilen:

- **Infernal Forge** - ein klassischer Slot (5 Walzen, 3 Reihen, 10 feste
  Gewinnlinien, Wild, Scatter/Freispiele), aufgebaut auf einer
  wiederverwendbaren Slot-Engine (`Core/Engine`).
- **Demonic Risk Ladder** - eine dämonische Risikoleiter: Einsatz wählen,
  Stufe für Stufe klettern (steigender Multiplikator, sinkende
  Erfolgschance) und jederzeit den aktuellen Gewinn nehmen oder weiter
  riskieren, bis Verlust, Cash-out oder der automatisch ausgezahlte
  Jackpot die Runde beendet (`Core/Services/RiskLadderSessionController`,
  `Core/Engine/RiskLadderEngine`).

Drei weitere Spiele (**Blood Cathedral**, **Abyssal Crypt**, **Cursed
Carnival**) sind als "Bald verfügbar" in der Spielesammlung sichtbar, aber
noch nicht implementiert.

> **Nur zur Unterhaltung. Kein Echtgeld, keine Gewinne und keine Auszahlung
> möglich.** Alle Einsätze/Gewinne bestehen ausschließlich aus virtuellen
> Soul Coins ohne realen Geldwert. Keine In-App-Käufe, keine Werbung, keine
> Lootboxen. Das Spiel funktioniert vollständig offline; optional kann ein
> Spieler einen einmaligen Benutzernamen registrieren, damit sein
> Guthaben zusätzlich mit einem eigenen Backend (`backend/`) synchronisiert
> wird - siehe `backend/README.md`. Ohne Registrierung ändert sich am
> rein lokalen Verhalten nichts.

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
                            GameStatistics, PendingSpin, RiskLadderRoundState,
                            UserSettings) + PersistenceController
    Services/               GameRegistry, WalletService, SpinTransactionService,
                            SpinSessionController/RiskLadderSessionController
                            (je ein Zustandsautomat), Haptics/Audio/DateProvider
  Features/
    Collection/             Spielhalle (Startbildschirm, liest aus GameRegistry,
                            routet je nach SlotGameDefinition.kind)
    SlotMachine/             Walzenfeld, Einsatzsteuerung, Paytable-Sheet, Partikelebene
    RiskLadder/              Leiter-Ansicht, Einsatzsteuerung, Ergebnis-Overlays
    Statistics/              Globale + Pro-Spiel-Statistiken
    Settings/                Audio/Haptik/Bewegung, Reset, RTP-Simulation (DEBUG)
  Games/
    InfernalForge/          Konkrete SlotGameDefinition für Infernal Forge
    RiskLadder/              RiskLadderDefinition (Katalogeintrag) + zentrale
                            RiskLadderConfiguration (Stufen/Multiplikatoren/Odds)
    ComingSoonGames.swift    Platzhalter-Definitionen für zukünftige Spiele
  Resources/Games/InfernalForge/  Asset-Key-Dokumentation für spätere Artwork/Audio
  Resources/Games/RiskLadder/      Audio-Assets/Dokumentation für Demonic Risk Ladder
  Shared/                  Farbpalette, Color(hex:)-Helper
DemonicSlotsTests/
  Core/                    Unit-Tests für Engine, Wallet, Persistenz, Registry,
                            RiskLadderEngine/RiskLadderSessionController
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

**Ein Spiel hinzufügen, das kein Slot ist** (wie Demonic Risk Ladder): auch
das läuft über dieselbe `GameRegistry`/`SlotGameDefinition`-Registrierung -
`SlotGameDefinition.kind` (`.slotMachine` per Default, `.riskLadder` für die
Risikoleiter) sagt `CollectionView`s einziger `.navigationDestination`, auf
welche Feature-View sie routet. Reel-/Payline-/Symbol-Felder, die für das
neue Spiel keine Bedeutung haben, werden minimal-aber-valide befüllt, exakt
wie `ComingSoonGames` es für seine Platzhalter schon tut; `betLevels` bleibt
in jedem Fall die echte, wiederverwendete Einsatzstufen-Liste. Es entsteht
dabei **keine** zweite Navigation und **keine** zweite `GameRegistry` -
siehe `RiskLadderDefinition.swift` als Vorlage.

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

## Demonic Risk Ladder konfigurieren

Stufenanzahl, Multiplikatoren und Erfolgswahrscheinlichkeiten sind zentral
in `RiskLadderConfiguration.levels` definiert (`[RiskLevel]`, je Stufe
`level`/`multiplier`/`successProbability`/`isJackpot`) - nirgendwo sonst im
Code steht eine Zahl fest verdrahtet. Wie bei den Infernal-Forge-Gewichten
ist die Startkonfiguration ein Ausgangswert, kein gemessenes Ergebnis;
`RiskLadderEngineTests` prüft Auszahlungs-/Rundungslogik sowie (mit
`SeededRandomSource`, hoher Stichprobenzahl) dass die beobachtete
Erfolgsquote einer Stufe ungefähr der konfigurierten entspricht.

## Player-Level, Win-Chance-Multiplikator & Bet-Tiers

Jeder Spieler hat zusätzlich zu Coins ein serverseitig verwaltetes `level`
(1-100) und einen `winChanceMultiplier` (0.10-2.00) - siehe
`backend/README.md`s "Player progression"-Abschnitt für die Backend-Seite
(Schema, Migration, API, serverseitige Validierung). Diese zwei Werte
beeinflussen zwei unabhängige Dinge, nie über verstreute
`if player.level >= X`-Ketten, sondern ausschließlich über eine zentrale
Stelle:

```
PlayerProfile (level, winChanceMultiplier - vom Server synchronisiert)
  ↓
PlayerProgressionService  (Core/Services/PlayerProgressionService.swift)
  ↓
GameProbabilityContext    (Core/Models/GameProbabilityContext.swift)
  ↓
SlotEngine / RiskLadderEngine
```

- **Gewinnchance:** `finalWinMultiplier = levelWinMultiplier(level) *
  validatedWinChanceMultiplier`, angewendet als `effectiveProbability =
  baseProbability * finalWinMultiplier`, gedeckelt bei
  `PlayerProgressionService.maximumEffectiveWinChance` (Default `0.95`) -
  ein hoher Multiplikator kann also nie einen praktisch garantierten Gewinn
  erzeugen. Beispiel aus der Aufgabenstellung: Level-Bonus `1.08` ×
  Admin-Multiplikator `1.10` = `1.188`; eine Basis-Gewinnchance von `20 %`
  wird damit zu `23.76 %`, nicht zu `20 % + 18.8 % = 38.8 %`.
  - **Demonic Risk Ladder** wendet diese Formel wörtlich auf die
    konfigurierte `successProbability` jeder Stufe an
    (`RiskLadderEngine.attemptClimb`).
  - **Infernal Forge** hat keine einzelne skalare "Gewinnwahrscheinlichkeit"
    - ein Spin-Ergebnis entsteht kombinatorisch daraus, welche Symbole auf
      allen Walzen landen. Die ehrliche, "innerhalb der bestehenden
      RNG-/Walzen-Logik" liegende Umsetzung ist deshalb eine
      **Gewichtsverschiebung bei der Stop-Index-Auswahl** in `ReelSpinner`:
      jedes Symbol bekommt anhand seines eigenen Paytable-Werts (bzw. für
      das Scatter-Symbol seines Freispiel-Payouts) ein Auswahlgewicht,
      normiert auf das wertvollste Symbol des jeweiligen Spiels - ein Bonus
      erhöht das Gewicht wertvoller Symbole (und senkt es für weniger
      wertvolle), ohne Paylines/Payout-Mathematik anzufassen oder je ein
      Ergebnis zu erzeugen, das der Walzenstreifen nicht ohnehin hergeben
      könnte. Bei `finalWinMultiplier == 1.0` (kein Bonus, der
      Normalfall) läuft exakt der ursprüngliche, uniforme
      `nextInt(0..<strip.count)`-Wurf - byte-identisches Verhalten zu vorher,
      siehe `ReelSpinner.swift`s Kopfkommentar und
      `ReelSpinnerTests.neutralProbabilityContextIsByteForByteIdenticalToTheOriginalRoll`.
- **Einsatzlimits:** `PlayerLevelConfiguration.betTiers` (sparsame
  Meilensteine, z. B. Level 10 → 500, unverändert bis Level 15 → 1.000) legt
  das **globale** Max-Bet fest; `effectiveMaxBet = min(globalesMaxBet,
  spielEigenesMaxBet)`. Jedes Spiel filtert seine eigene `betLevels`-Liste
  über `PlayerProgressionService.availableBets(...)` auf das, was das
  aktuelle Level tatsächlich freischaltet (`SpinSessionController.
  availableBetLevels`, `RiskLadderSessionController.availableStakeLevels`) -
  ein gesperrter Einsatz lässt sich weder in der UI auswählen noch (als
  zweite, unabhängige Absicherung) tatsächlich starten
  (`spin()`/`startRound()` prüfen das erneut). Der nächste gesperrte Einsatz
  wird als kleiner "🔒 Level X schaltet Y Coins frei"-Hinweis unterhalb der
  bestehenden Einsatzsteuerung angezeigt, ohne deren UI umzubauen.
- **Level-Konfiguration** (`PlayerLevelConfiguration.swift`): zwei bewusst
  getrennte, leicht erweiterbare Tabellen - `levels` (Win-Bonus pro Level,
  dicht bis Level 10, danach bleibt der letzte Wert stehen) und `betTiers`
  (Meilensteine für das Max-Bet). Neue Stufen/Tiers hinzufügen heißt nur,
  diese Arrays zu erweitern.
- **Validierung, zweifach:** Level (`1...100`) und Multiplikator
  (`0.10...2.00`, `NaN`/`Infinity` → Fallback `1.0`) werden sowohl vom
  Backend (`routes/admin.js`, lehnt ungültige Werte mit `400` ab) als auch
  clientseitig erneut geprüft (`PlayerProgressionService.validatedLevel`/
  `validatedWinChanceMultiplier`, `AccountSyncController` wendet das direkt
  beim Einlesen einer Sync-Antwort an) - ein korrupter oder manipulierter
  Wert kann das Spiel nie zum Absturz bringen oder eine kaputte
  Wahrscheinlichkeit erzeugen.
- **Server bleibt Quelle der Wahrheit:** `level`/`winChanceMultiplier`
  werden ausschließlich von `AccountSyncController` aus einer
  Register-/Sync-Antwort geschrieben, nie von Gameplay-Code - eine
  zukünftige Admin-App ändert sie über `PATCH /api/admin/players/:username`
  (siehe `backend/README.md`), die App übernimmt den neuen Wert beim
  nächsten Sync automatisch, ganz ohne Sonderweg für diese beiden Felder.
- **Level ≠ Coins:** Level wird ausschließlich als gespeicherter
  Profilwert behandelt, niemals aus dem Coin-Guthaben berechnet - ein Spieler
  mit vielen Coins ist nicht automatisch hochstufig.

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
- Demonic Risk Ladder ist genauso transaktionssicher, nur ohne eine
  `PendingSpin`-Warteschlange: `RiskLadderRoundState` hält immer höchstens
  eine aktive Runde pro Spiel fest (`isActive`/`stakeDebited`/`stake`/
  `currentLevel`). Der Einsatz wird beim Start genau einmal abgebucht;
  danach ist nichts mehr zu verlieren, was nicht schon abgebucht wurde -
  ein Neustart mittendrin setzt die Runde exakt an der zuletzt erreichten
  Stufe fort, statt den Einsatz zu erstatten oder erneut abzuziehen. Jede
  Auszahlung (Cash-out, Jackpot) setzt `state` synchron aus `.ready` heraus,
  *bevor* die eigentliche Gutschrift läuft, damit ein schnelles
  Doppel-Tippen nie doppelt auszahlt - `RiskLadderSessionControllerTests`
  deckt genau das ab.
