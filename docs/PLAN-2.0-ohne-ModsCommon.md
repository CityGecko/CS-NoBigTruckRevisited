# No Big Truck 2.0 – Umbau ohne ModsCommon

Stand: 25.11.2026. Grundlage: `dev/1.21` (NBT 1.3.2, im Spiel bestätigt unter 1.21.2-f5).

## Entscheidungen (25.11.2026)

- Basis: **AlgernonCommons** (MIT), wie AVO 1.10.
- Name: **No Big Truck Revisited**, eigener Workshop-Eintrag. Versionsnummer noch offen (Vorschlag 2.0.0).
- Optionsseite: **Checkboxen** je Regel (Quellen, Zieltypen, Größe prüfen) plus zwei Zahlenfelder.
- Vor dem Umbau wird der Stand 1.3.2 lokal committet; Name/E-Mail dafür gibt der User noch an.

## Warum

`ModsCommon` (MacSergey) darf laut `ModsCommon/License.txt` ohne seine Zustimmung nicht kopiert, geändert oder
veröffentlicht werden. Es wird in `NoBigTruck.dll` hineinkompiliert. MacSergey hat auf die Anfrage nicht geantwortet.
No Big Truck selbst steht unter MIT und darf weitergeführt werden.

## Ersatz: AlgernonCommons (MIT)

- `github.com/algernon-A/AlgernonCommons`, MIT, © algernon. Liegt lokal unter `Programmierung\AlgernonCommons-master`.
- AVO 1.10 nutzt es bereits (Git-Submodul + `AlgernonCommonsShared.projitems`). Gleicher Aufbau in beiden Mods.
- Enthält alles, was NBT braucht: Mod-Basis mit Harmony (`PatcherMod`, `PatcherBase`, über CitiesHarmony.API),
  Logging, Übersetzungen (CSV, Sprachwahl), Optionsseite (`OptionsPanelBase`, Checkboxen, Textfelder, Buttons),
  „What's new“-Meldungen, XML-Hilfen.

## Was von ModsCommon genutzt wird und wodurch es ersetzt wird

| Bereich | heute (ModsCommon) | künftig |
|---|---|---|
| Mod-Basis, Laden | `BasePatcherMod<Mod>`, `BaseLoadingExtension<Mod>` | `PatcherMod<OptionsPanel, Patcher>`, `PatcherLoadingBase` |
| Harmony-Patches | `AddTranspiler/AddPrefix/AddPostfix` | `PatcherBase.OnPatchAll(harmony)` mit `harmony.Patch(...)`, je Patch eine Logzeile OK/FEHLER |
| Logging | `SingletonMod<Mod>.Logger.Debug` | `Logging.Message/Error` |
| Optionsseite | Reiter, Regel-Panels, Segment-Knöpfe, Zahlenfelder (`PropertyGroupPanel`, `UIMultySegmented`, `IntPropertyPanel` …) | eine Seite „Regeln“: je Regel eine Gruppe mit Checkboxen (3 Quellen, 6 Zieltypen), Checkbox „Größe prüfen“, zwei Zahlenfelder, Button „Regel löschen“; darunter „Neue Regel“ |
| Regelwerte | `PropertyEnumValue/BoolValue/StructValue` | einfache Felder in `Rule` |
| Konfiguration | `NoBigTruck.xml` über `System.Xml.Linq` | **gleiches Dateiformat** (`<Config><Rule Source Target UseSize MaxLength MaxWidth/>`), gelesen mit `System.Xml` → bestehende Regeln bleiben erhalten; `System.Xml.Linq.dll` muss nicht mehr mitgeliefert werden |
| Übersetzungen | `.resx` + `LocalizeManager` (Crowdin) | NBT-Texte (MIT) per Skript aus den `.resx` in AlgernonCommons-CSV umwandeln, Schlüssel bleiben gleich |
| AVO-Abhängigkeit | `NeedDependencyInfo` + Hinweisfenster | Prüfung beim Laden; fehlt AVO: Hinweis (Notification) und Log, AVO-Patches überspringen |
| Vehicle Selector erkennen | `PluginUtilities` | eigene kleine Plugin-Suche (Name/Workshop-ID) |
| Versionswarnung | „out of date“-Fenster | entfällt (Kompatibilität sichert der GameScan) |
| „What's new“ | `WhatsNewMessageBox` | AlgernonCommons `WhatsNewMessage` |
| `IsFlagSet`, `[Description]`, `[NotVisible]` | ModsCommon-Erweiterungen | eigene Hilfsmethode bzw. feste Liste in der Optionsseite |

## Unverändert übernommen

- `Manager.cs`: Regelprüfung, Cache der kleinen Fahrzeuge, `GetRandomVehicleInfo`, `GetTransferVehicleService`, `IsRestrictedTarget`.
- Alle Transpiler und Prefixe/Postfixe in `Patcher` (inkl. `CargoTruckAI_StartTransfer_Prefix` und Vehicle-Selector-Rückzug).
- Die zwei AVO-Patches (`UIOptionPanel.OnCheckChanged` mit `___m_isLargeVehicle`, `NoBigTruckCompatibilityPatch.IsNBTActive`).
- Namespace `NoBigTruck`, Konfigurationsdatei `NoBigTruck.xml`.
- GameScan/GameBaseline (nur die erwarteten Logzeilen in der README anpassen).

## Entfällt

- Submodul `ModsCommon`, `System.Xml.Linq.dll` und deren HintPath/Satelliten-Workaround in der csproj.
- Beta-Konfiguration, Crowdin-Link, Einstellungsdatei `NoBigTruckSettingsFile.cgs`.

## Veröffentlichung

- Eigener Workshop-Eintrag (neue ID), Titel „No Big Truck Revisited“, Version noch offen (Vorschlag 2.0.0).
- `LICENSE` (MIT, MacSergey) bleibt; ergänzt um eigenes Copyright für neue Teile und den MIT-Text von AlgernonCommons
  (`AlgernonCommons/LICENSE.txt`, wird mitgeliefert). Credits: MacSergey (Original), Will (1.21-Anpassung), algernon (AlgernonCommons).
- AVO erkennt NBT weiter über den Prefix auf `IsNBTActive`, unabhängig von der Workshop-ID.

## Arbeitsschritte

1. Stand 1.3.2 auf `dev/1.21` lokal committen (Basis und Vergleich).
2. Branch `dev/2.0` von dort; AlgernonCommons als Submodul einbinden (wie AVO 1.10).
3. Mod-Basis, Patcher, Logging umstellen; ModsCommon-Imports entfernen.
4. `Rule` + XML-Lesen/Schreiben im alten Format.
5. Optionsseite neu.
6. Übersetzungen umwandeln (Skript), deutsche und englische Texte prüfen.
7. Bauen (0 Fehler), GameScan, Spieltest mit NBT-TrailerTruckProbe (gleiche Testliste wie 1.3.2), Commit.
8. Workshop-Texte, Lizenz/Credits, Release-Entscheidung.

Geschätzter Umfang: Optionsseite ~250 Zeilen, Mod/Patcher/Loading ~200 Zeilen, Rule/XML ~100 Zeilen, Konvertierungsskript ~50 Zeilen.
