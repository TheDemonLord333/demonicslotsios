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

## Player-Level, Win-Chance-Multiplikator, Bet-Tiers & garantierter Jackpot

Jeder Spieler hat zusätzlich zu Coins ein serverseitig verwaltetes `level`
(1-100), einen `winChanceMultiplier` (0.10-2.00) und ein
`guaranteedJackpot`-Flag (bool) - siehe `backend/README.md`s "Player
progression"-Abschnitt für die Backend-Seite (Schema, Migration, API,
serverseitige Validierung). Diese drei Werte beeinflussen unabhängige
Dinge, nie über verstreute `if player.level >= X`-Ketten, sondern
ausschließlich über eine zentrale Stelle:

```
PlayerProfile (level, winChanceMultiplier, hasGuaranteedJackpot - vom Server synchronisiert)
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
- **Einsatzlimits (geteilte Einsatzleiter, pro Spiel verschoben):**
  `PlayerProgressionService.stakeSequenceValue(atIndex:)` erzeugt eine
  einzige, für beide Spiele gemeinsame Zahlenfolge nach dem Muster `10, 25,
  50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, ...`
  (dekadisch, ×1/×2.5/×5). Jedes Spiel hat dort nur einen eigenen
  Startindex (`SlotGameDefinition.betTierStartIndex` - Infernal Forge bei
  Index 4 = 250, entspricht seinem bisherigen `perLine: 25`-Höchsteinsatz
  über 10 Paylines; Demonic Risk Ladder bei Index 5 = 500, sein bisheriger
  Höchsteinsatz) und schaltet **alle 10 Level**
  (`PlayerLevelConfiguration.levelsPerBetTierStep`) den nächsten Wert der
  Leiter frei: `maxBet(level, betTierStartIndex) = stakeSequenceValue(
  betTierStartIndex + level / 10)`. Level 1 bleibt also exakt beim
  bisherigen Höchsteinsatz jedes Spiels, Level 10 verdoppelt ihn (Forge
  250→500, Risk Ladder 500→1.000), Level 20 wieder, und so weiter bis
  Level 100. `effectiveMaxBet = min(maxBet(...), spielEigenesMaxBet)`.
  Jedes Spiel filtert seine eigene, aus derselben Leiter generierte
  `betLevels`-Liste (siehe `InfernalForgeDefinition.betLevels`/
  `RiskLadderConfiguration.stakeLevels`) über
  `PlayerProgressionService.availableBets(...)` auf das, was das aktuelle
  Level tatsächlich freischaltet (`SpinSessionController.
  availableBetLevels`, `RiskLadderSessionController.availableStakeLevels`) -
  wichtig: verglichen wird immer der **Gesamteinsatz**
  (`definition.totalBet(betPerLine:)`, also `perLine × aktive Paylines`),
  nie der bloße `perLine`-Wert, da Infernal Forge 10 Paylines hat und
  Demonic Risk Ladder nur eine. Ein gesperrter Einsatz lässt sich weder in
  der UI auswählen noch (als zweite, unabhängige Absicherung) tatsächlich
  starten (`spin()`/`startRound()` prüfen das erneut). Der nächste
  gesperrte Einsatz wird als kleiner "🔒 Level X schaltet Y Coins frei"-
  Hinweis unterhalb der bestehenden Einsatzsteuerung angezeigt, ohne deren
  UI umzubauen.
- **Level-Konfiguration** (`PlayerLevelConfiguration.swift`): zwei bewusst
  getrennte, leicht erweiterbare Werte - `levels` (Win-Bonus pro Level,
  dicht bis Level 10, danach bleibt der letzte Wert stehen) und
  `levelsPerBetTierStep` (wie oft die geteilte Einsatzleiter eine Stufe
  weiterschaltet). Neue Win-Bonus-Stufen hinzufügen heißt nur, `levels` zu
  erweitern; an der Einsatzleiter selbst muss dafür nichts geändert werden.
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
  Register-/Sync-Antwort geschrieben, nie direkt von Gameplay-Code. Die
  Admin-App ändert sie über `PATCH /api/admin/players/:id` (siehe
  `backend/README.md` - Spieler werden dort über ihre stabile, unveränderliche
  `id` adressiert, nicht über den änderbaren `username`); die App übernimmt
  jeden neuen Wert beim nächsten Sync automatisch, ganz ohne Sonderweg für
  diese Felder.
- **Level ≠ Coins:** Level wird ausschließlich als gespeicherter
  Profilwert behandelt, niemals aus dem Coin-Guthaben berechnet - ein Spieler
  mit vielen Coins ist nicht automatisch hochstufig.

### Admin-Modus "garantierter Jackpot"

`guaranteedJackpot` ist ein reiner Admin-Schalter (nur über die Admin-App
setzbar, nie durch Gameplay) - solange er `true` ist, gewinnt dieser
Spieler auf seinem Gerät **immer** den bestmöglichen Ausgang, ohne
jeglichen Zufalls-Wurf:

- **Demonic Risk Ladder:** `RiskLadderEngine.attemptClimb` gibt sofort
  `true` zurück, sobald `probabilityContext.guaranteesJackpot` gesetzt ist
  - noch vor dem eigentlichen Wahrscheinlichkeits-Wurf. Jeder Klettern-
  Versuch gelingt, bis zur obersten (Jackpot-)Stufe.
- **Infernal Forge:** Da ein Spin-Ergebnis aus vielen Walzen/Symbolen
  entsteht (nicht aus einer einzelnen Wahrscheinlichkeit), lässt sich
  "garantiert gewinnen" nicht über eine Stop-Index-Gewichtung erzwingen -
  ein Walzenstreifen hat keine Garantie auf eine lange Folge desselben
  Symbols. Stattdessen überschreibt `SlotEngine.spin(...)` das fertig
  berechnete Grid direkt mit dem wertvollsten Symbol des Spiels
  (`ReelSpinner.highestValueSymbol`, ermittelt aus Paytable + Scatter-
  Auszahlung) in jeder Zelle. Bei Infernal Forge ist das Wild
  (`infernalCrown`) zufällig gleichzeitig auch das höchstzahlende reguläre
  Symbol - das Grid wird also komplett mit dem Wild gefüllt, wodurch die
  **bestehende, unveränderte** `PaylineEvaluator`-Wild-Ersetzungslogik auf
  jeder einzelnen Payline automatisch die maximale Auszahlung erkennt,
  ohne dass an der Auswertung selbst irgendetwas geändert werden musste.
  Die Walzen-Animation (`stopIndices`) bleibt ein echter Wurf - nur das
  ausgewertete/angezeigte Grid wird überschrieben.
- **Bewusst ein harter Bypass, kein extremer Multiplikator:** ein
  `finalWinMultiplier` läuft immer noch durch `adjustedProbability`s
  Deckel (`maximumEffectiveWinChance`, Default 95 %) und echtes RNG - damit
  könnte "immer" nie tatsächlich erreicht werden. `guaranteesJackpot` ist
  deshalb ein eigenes, unabhängiges Feld auf `GameProbabilityContext`, kein
  Sonderwert für `finalWinMultiplier`.
- Serverseitig verhält sich `guaranteed_jackpot` genau wie `level`/
  `win_chance_multiplier`: admin-only, löst keinen `admin_revision`-Bump
  aus, wird bei jedem Sync einfach als aktueller Wert mitgeliefert (siehe
  `backend/README.md`).

### Autospin (Infernal Forge)

Den Spin-Button gedrückt halten (`onLongPressGesture`, 0,45 s) aktiviert
Autospin: `SpinSessionController.toggleAutoSpin()` setzt `isAutoSpinning`
und queued sofort einen Spin. Nach jedem abgeschlossenen Spin (inklusive
jedes einzelnen Freispiels innerhalb einer Bonusrunde - Hooks in
`runSpinSequence()`s finalem `state = .idle` und in
`acknowledgeBonusSummary()`) wird nach einer kurzen Pause
(`SpinTiming.autoSpinPause`, 0,5 s) automatisch der nächste Spin ausgelöst,
solange `isAutoSpinning` noch an ist. Einfaches Antippen des Buttons
während Autospin schaltet es sofort wieder aus (`toggleAutoSpin()` erneut).
Der Button wechselt während Autospin die Farbe (Radial-Gradient auf
`glowingViolet`/`hellfireRed` statt `emberOrange`/`hellfireRed`, violetter
Rahmen/Glow) und zeigt "AUTO" statt "SPIN". Autospin stoppt sich außerdem
selbst, sobald ein Spin scheitert (nicht genug Guthaben, ein inzwischen
gesperrter Einsatz, eine ungültige Definition) oder ein Fehler manuell
weggetippt wird (`dismissError()`) - nie persistiert, jede neue
`SpinSessionController`-Instanz startet mit Autospin aus.

### XP: Level wird durch Spielen automatisch erreicht

Level steigt nicht nur, wenn du es im Admin-Panel setzt, sondern auch von
selbst durch Spielen - beides gleichzeitig, ohne Widerspruch:

- **XP-Quelle:** Jeder eingesetzte Coin zählt 1:1 als XP
  (`WalletService.awardXP`, aufgerufen genau dort, wo auch
  `GameStatistics.record(wager:)` läuft - `SpinTransactionService.
  finalizeSpin`/`RiskLadderSessionController.settleRound`). Freispiele
  kosten keinen Einsatz und bringen konsistent auch keine XP.
  `PlayerProfile.totalXP` ist rein clientseitig, wächst nur, wird nie von
  einer Sync-Antwort überschrieben und nie kleiner.
- **XP → Level:** `PlayerProgressionService.cumulativeXPRequired(forLevel:)`
  ist eine einfache dreieckige Kurve (`xpStep * level * (level-1) / 2`,
  `xpStep = 500` in `PlayerLevelConfiguration`) - Level 2 kostet 500 XP
  insgesamt, Level 10 (Deckel des Win-Bonus, erste Einsatzleiter-Stufe)
  22.500, Level 100 (absolutes Maximum, letzte Einsatzleiter-Stufe)
  2.475.000. Startwert,
  keine gemessene Balance - `xpStep` ist der eine Wert zum Nachjustieren.
- **Anspruch, kein Zwang:** Bei jedem Sync berechnet der Client sein
  eigenes `PlayerProgressionService.level(forTotalXP:)` und schickt es nur
  dann als `earnedLevel` mit, wenn es über dem zuletzt bekannten
  Server-Level liegt (`AccountSyncController.syncSilently`). Der Server
  (`POST /api/players/sync`, siehe `backend/README.md`) wendet
  `newLevel = max(aktuellesLevel, earnedLevel)` an - ein XP-Anspruch kann
  das Level also nur anheben, nie absenken, und ein Admin-Boost über das,
  was die eigene Spielzeit bisher hergibt, bleibt beim nächsten Sync
  unangetastet stehen.
- **Fortschrittsbalken:** `PlayerProgressionService.xpProgress(totalXP:
  currentLevel:)` liefert `xpIntoLevel`/`xpForNextLevel`/`fraction` relativ
  zum *gespeicherten* Level (nicht zum reinen XP-Level) - nach einem
  Admin-Boost zeigt der Balken also ehrlich "noch nichts" statt einer
  verwirrenden "schon über 100 %"-Anzeige, bis die echte Spielzeit
  nachgezogen hat. `nil` ab Level 100 (nichts mehr, wohin fortzuschreiten
  wäre). Angezeigt in `ProfileSheetView`.

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
