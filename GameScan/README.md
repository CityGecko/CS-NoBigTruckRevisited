# GameScan – Spiel-Updates gegen No Big Truck prüfen

Aufgebaut wie `GameScan` in Advanced Vehicle Options, zugeschnitten auf die Harmony-Patches von No Big Truck (NBT).
Benötigt [ilspycmd](https://github.com/icsharpcode/ILSpy) (`dotnet tool install -g ilspycmd`) und für Diffs `git`.

## Warum

Ein Transpiler, der seinen Aufruf im Spielcode nicht mehr findet, ersetzt einfach nichts – Harmony meldet trotzdem
„Success patched!“. NBT würde dann still wirkungslos. `05_patch_targets.txt` prüft deshalb direkt im IL, ob jede
Ersetzung noch ihr Ziel hat (Signatur/Argument-Indizes, Anzahl der Aufrufe, lokale Variablen 6/7 in `ChangeVehicleType`).

## Ablauf bei einem Spiel-Update

1. **Vorher** (einmalig je Spielversion): DLL-Set sichern und Baseline scannen.
   Ordner: `GameBaseline\<Version>_<Datum>\dll` (Kopie von `Cities_Data\Managed`) und `...\scan`.
   ```powershell
   .\Scan-Game.ps1 -OutDir '..\GameBaseline\1.21.1-f9_2026-10-14\scan' -AssemblyDir '..\GameBaseline\1.21.1-f9_2026-10-14\dll'
   ```
2. **Nach dem Update**: neuen Stand scannen (Standard-`AssemblyDir` ist der Managed-Ordner der Steam-Installation).
   ```powershell
   .\Scan-Game.ps1 -OutDir '..\GameBaseline\<neue Version>_<Datum>\scan'
   ```
3. **Vergleichen**:
   ```powershell
   .\Compare-Scans.ps1 -Old '..\GameBaseline\1.21.1-f9_2026-10-14\scan' -New '..\GameBaseline\<neue Version>_<Datum>\scan'
   ```
4. Im Spiel `output_log.txt` prüfen: alle `[NoBigTruck] ... Success patched!` und `[NoBigTruck] Patch Success`.

## Dateien eines Scans

| Datei | Inhalt |
|---|---|
| `00_info.txt` | Spielversion, Save-Format, SHA256 der Spiel-DLLs und der geprüften AVO-DLL |
| `02_enums_consts.txt` | `ItemClass` (Service/SubService/Level), `TransferManager` (TransferReason), `DistrictPolicies` (Spezialisierungen) |
| `03_signatures.txt` | Member-Signaturen der NBT-relevanten Typen |
| `04_nbt_dependencies.txt` | Spiel- und AVO-Member, die NBT per Reflection/Harmony nutzt: `OK` / `FEHLT` / `HINWEIS` |
| `05_patch_targets.txt` | Harmony-Ziele im IL: `OK` / `PRUEFEN` / `FEHLT` |
| `il\`, `src\` | IL der gepatchten Methoden, dekompilierter Quelltext (nur lokal, siehe `.gitignore`) |

Neue Reflection-Zugriffe oder Harmony-Ziele in NBT bitte in `Scan-Game.ps1` (`$deps` bzw. `$targets`) nachtragen.

## Rechtliches

`dll\`, `src\`, `il\` und die `*_changes.patch` enthalten Spielcode von Colossal Order/Paradox und sind per
`.gitignore` ausgeschlossen. Ins Repo gehören nur die Skripte und die Inventar-Textdateien.
