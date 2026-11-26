# Übersetzungen (Crowdin)

Die Texte liegen in `NoBigTruck/Translations/<Sprache>.csv` (Format von AlgernonCommons: `"SCHLÜSSEL","Text"`).
Quelle ist `en-EN.csv`. Fehlt ein Schlüssel in einer Sprache, zeigt der Mod den englischen Text.
Die Dateinamen entsprechen den Crowdin-Sprachcodes (`de-DE`, `uk-UA`, `zh-CN`, ...). `crowdin.yml` im Repo-Stamm
beschreibt das für Crowdin.

Herkunft: 22 Sprachen aus den Crowdin-Übersetzungen von MacSergeys No Big Truck (über Will's Branch `workshop` und
MacSergeys Branch `Translation`), einmalig umgewandelt mit `tools/resx2csv.py`. Ab jetzt sind die CSV-Dateien der
maßgebliche Stand; das Skript nicht mehr laufen lassen, es würde Crowdin-Übersetzungen überschreiben.

## Crowdin-Projekt einrichten (einmalig, mit eigenem Login)

1. crowdin.com → **Create Project**: Name z. B. „No Big Truck Revisited“, **Public project**, Quellsprache **English**.
   Zielsprachen: Czech, Danish, German, English (United Kingdom), Spanish, Finnish, French, Hungarian, Italian,
   Japanese, Korean, Dutch, Polish, Portuguese, Romanian, Russian, Thai, Turkish, Ukrainian, Vietnamese,
   Chinese Simplified, Chinese Traditional, Indonesian (und gern weitere).
   Für Open-Source-Projekte ist Crowdin kostenlos (Antrag „Open Source“ im Projekt bzw. auf crowdin.com/page/open-source-project-setup-request).
2. Im Projekt: **Integrations → GitHub** → mit dem GitHub-Konto verbinden → Repository
   `CityGecko/CS-NoBigTruckRevisited` → Branch **dev/2.0** wählen.
3. Beim Einrichten **„Upload existing translations“** (vorhandene Übersetzungen hochladen) aktivieren.
   Die Konfiguration kommt aus `crowdin.yml`; Service-Branch-Name z. B. `l10n_dev/2.0`.
4. Crowdin liest dann `en-EN.csv` als Quelle und die 21 Sprachdateien als vorhandene Übersetzungen.
5. Neue oder geänderte Übersetzungen schickt Crowdin als Pull Request auf `dev/2.0`.

## Neue Texte im Mod

Neuen Schlüssel in `en-EN.csv` (und `de-DE.csv`) eintragen und pushen. Crowdin übernimmt ihn bei der nächsten
Synchronisation als neuen Text zum Übersetzen.

Hinweis: Der Schlüssel `LANGUAGE` enthält den Namen der Sprache in der Sprache selbst (z. B. „Deutsch“) und wird
ebenfalls über Crowdin gepflegt.
