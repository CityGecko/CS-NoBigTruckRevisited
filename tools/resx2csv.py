# Converts the No Big Truck 1.x translations (Properties/Localize*.resx, community translations via Crowdin,
# MIT like the mod) into AlgernonCommons translation files (NoBigTruck/Translations/<language>.csv).
# New texts of 2.0 exist in English and German only; other languages fall back to English.
# Usage (from the repository root): python tools/resx2csv.py

import glob
import os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "legacy-resx")
DST = os.path.join(ROOT, "NoBigTruck", "Translations")

# old resx key -> new key
KEYS = {
    "Mod_Description": "MOD_DESCRIPTION",
    "RulesTab": "RULES_TITLE",
    "AddNewRule": "ADD_RULE",
    "Source": "SOURCE",
    "SourceIndustry": "SOURCE_INDUSTRY",
    "SourceOutside": "SOURCE_OUTSIDE",
    "SourceWarehouse": "SOURCE_WAREHOUSE",
    "Target": "TARGET",
    "TargetLow": "TARGET_LOW",
    "TargetHigh": "TARGET_HIGH",
    "TargetEco": "TARGET_ECO",
    "TargetLeisure": "TARGET_LEISURE",
    "TargetTourist": "TARGET_TOURIST",
    "TargetWallToWall": "TARGET_WALLTOWALL",
    "TargetWallToWall_Tooltip": "TARGET_WALLTOWALL_TOOLTIP",
    "CheckTargetSize": "CHECK_SIZE",
    "MaxLength": "MAX_LENGTH",
    "MaxWidth": "MAX_WIDTH",
}

# texts that are new in 2.0
NEW = {
    "en-EN": {
        "RULE_TITLE": "Rule {0}",
        "DELETE_RULE": "Delete rule",
        "RULES_HINT": "Goods deliveries from the selected source buildings to the selected target buildings use only vehicles that are NOT marked as \"Large Vehicle\" in Advanced Vehicle Options.",
        "CHECK_SIZE_TOOLTIP": "Apply the rule only to target buildings up to the given lot size (in cells).",
        "AVO_MISSING": "No Big Truck Revisited: Advanced Vehicle Options is not enabled. Vehicles are marked as \"Large Vehicle\" in Advanced Vehicle Options; without it, this mod has nothing to filter.",
        "WHATSNEW_2_0_0_1": "No Big Truck Revisited continues No Big Truck by MacSergey for game version 1.21.",
        "WHATSNEW_2_0_0_2": "Your existing rules are kept.",
        "WHATSNEW_2_0_0_3": "New target type Wall-to-wall.",
        "WHATSNEW_2_0_0_4": "Large vehicles are no longer sent to small shops when they look for a new target on their way (rest of a load, arrival from a cargo train or ship).",
    },
    "de-DE": {
        "RULE_TITLE": "Regel {0}",
        "DELETE_RULE": "Regel löschen",
        "RULES_HINT": "Warenlieferungen von den gewählten Quellgebäuden zu den gewählten Zielgebäuden nutzen nur Fahrzeuge, die in Advanced Vehicle Options NICHT als \"Large Vehicle\" markiert sind.",
        "CHECK_SIZE_TOOLTIP": "Regel nur für Zielgebäude bis zur angegebenen Grundstücksgröße (in Zellen) anwenden.",
        "AVO_MISSING": "No Big Truck Revisited: Advanced Vehicle Options ist nicht aktiv. Fahrzeuge werden in Advanced Vehicle Options als \"Large Vehicle\" markiert; ohne diesen Mod hat No Big Truck nichts zu filtern.",
        "WHATSNEW_2_0_0_1": "No Big Truck Revisited führt No Big Truck von MacSergey für Spielversion 1.21 weiter.",
        "WHATSNEW_2_0_0_2": "Deine bestehenden Regeln bleiben erhalten.",
        "WHATSNEW_2_0_0_3": "Neuer Zieltyp Wall-to-Wall.",
        "WHATSNEW_2_0_0_4": "Große Fahrzeuge werden nicht mehr zu kleinen Läden geschickt, wenn sie unterwegs ein neues Ziel suchen (Restladung, Ankunft per Güterzug oder Schiff).",
    },
}


# Language names in their own language (AlgernonCommons reads them from the "LANGUAGE" key of the top-level files).
LANGUAGE_NAMES = {
    "cs-CZ": "Čeština", "da-DK": "Dansk", "de-DE": "Deutsch", "en-EN": "English", "en-GB": "English (UK)",
    "es-ES": "Español", "fi-FI": "Suomi", "fr-FR": "Français", "hu-HU": "Magyar", "id-ID": "Bahasa Indonesia",
    "it-IT": "Italiano", "ja-JP": "日本語", "ko-KR": "한국어", "nl-NL": "Nederlands", "pl-PL": "Polski",
    "pt-PT": "Português", "ro-RO": "Română", "ru-RU": "Русский", "tr-TR": "Türkçe", "zh-CN": "简体中文",
    "zh-TW": "繁體中文",
}


def read_resx(path):
    values = {}
    for data in ET.parse(path).getroot().iter("data"):
        name = data.get("name")
        value = data.find("value")
        if name in KEYS and value is not None and value.text:
            values[KEYS[name]] = value.text
    return values


def quote(text):
    return '"' + text.replace('"', '""') + '"'


def main():
    os.makedirs(DST, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SRC, "Localize*.resx"))):
        name = os.path.basename(path)
        code = "en-EN" if name == "Localize.resx" else name[len("Localize."):-len(".resx")]
        values = read_resx(path)
        values.update(NEW.get(code, {}))
        if not values:
            continue
        out = os.path.join(DST, code + ".csv")
        with open(out, "w", encoding="utf-8-sig", newline="\r\n") as f:
            f.write(quote("LANGUAGE") + "," + quote(LANGUAGE_NAMES.get(code, code)) + "\n")
            for key in list(KEYS.values()) + list(NEW["en-EN"].keys()):
                if key in values:
                    f.write(quote(key) + "," + quote(values[key]) + "\n")
        print(code, len(values), "->", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
