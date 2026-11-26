# Changelog – No Big Truck Revisited

Continuation of No Big Truck by MacSergey (MIT). Game version 1.21.2-f5.
Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3846463309

## 2.0.0 (2026-11-26, Steam Workshop 3846463309)

**New base**
- ModsCommon (MacSergey; may not be published without his consent) replaced by AlgernonCommons (MIT, algernon),
  the same base Advanced Vehicle Options uses. The mod DLL shrank from 431 KB to about 100 KB.
- Existing rules are kept: same file `NoBigTruck.xml` with the 1.x format.
- Every Harmony patch is applied and logged on its own; summary line `Harmony patches: 13 applied, 0 failed`
  (11 without Advanced Vehicle Options). A second log line lists which mods patch the shared methods and in which order.

**Options page**
- One group of checkboxes per rule (3 source types, 6 target types), "check target building's size",
  maximum length/width (confirm with Enter), "Delete rule", "Add new rule".
- Every change is saved immediately; next to the rule: "Saved at 22:03:48 (5 s ago)", "Created, ...",
  "Was rule 2, ..." after a deletion, or a red "NOT saved" if the file could not be written.
  The status is cleared when the page is left.
- Language selection; 24 languages incl. English (translations of 1.x, missing texts machine-translated, maintained on Crowdin).

**Behaviour**
- New target type Wall-to-wall (district specialization of the Plazas & Promenades DLC; not tested in game).
- Fix: large trucks that look for a new target on their way (rest of a load after a partial delivery, arrival
  from a cargo train or ship, target gone) are no longer sent to buildings covered by a rule. This gap also
  existed in No Big Truck 1.3.
- Vehicle Selector: where it chooses the vehicles (industry, extractors, warehouses), it takes precedence.
  No Big Truck still filters deliveries from outside connections and blocks the redirection of large trucks.
  Vehicle Selector and Advanced Vehicle Options are also detected as local copies without workshop ID.
- Notice in game if Advanced Vehicle Options is not enabled (without it no vehicle can be marked as large).
- No "mod is out of date" window any more; compatibility with game updates is checked with GameScan.

## 1.3.2 (local only, not released)

- Game version 1.21.2-f5 (based on Will's fork for 1.20/1.21: `ChangeVehicleType` with 5 parameters,
  Vehicle Selector support, "Max building's width" fix, filter for vehicles from outside connections).
- Real .NET 3.5 System.Xml.Linq shipped again (a reference assembly crashed the settings page).
- New target type Wall-to-wall.
- Rerouting fix (see 2.0.0).
