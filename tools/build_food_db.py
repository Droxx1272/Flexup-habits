#!/usr/bin/env python3
"""Build FlexUp/Resources/USDAFoods.json from USDA FoodData Central.

Both sources are US government works in the public domain:
  FNDDS survey foods (dishes as eaten, with household portions)
  SR Legacy (ingredients and generic foods)

Download the JSON zips from https://fdc.nal.usda.gov/download-datasets/ ,
unzip them next to this script, then run:
  python3 tools/build_food_db.py surveyDownload.json FoodData_Central_sr_legacy_food_json_2018-04.json

Row layout (per 100 g):
  [name, category, kcal, protein_g, carbs_g, fat_g, fiber_g, sugar_g,
   sodium_mg, [[portion label, grams], ...], source (0 FNDDS, 1 SR)]
"""
import json
import sys
from pathlib import Path

NUTRIENTS = {"208": "kcal", "203": "p", "204": "f", "205": "c", "291": "fib", "269": "sug", "307": "na"}
SKIP_CATEGORIES = {"Baby Foods"}


def nutrients(food):
    found = {}
    for entry in food["foodNutrients"]:
        number = entry.get("nutrient", {}).get("number")
        if number in NUTRIENTS and "amount" in entry:
            found[NUTRIENTS[number]] = entry["amount"]
    return found


def rounded(value, digits=1):
    value = round(value, digits)
    return int(value) if value == int(value) else value


def main(survey_path, legacy_path):
    rows, seen = [], set()

    def add(name, category, values, portions, source):
        key = name.lower()
        if key in seen or "kcal" not in values:
            return
        seen.add(key)
        rows.append([
            name, category, rounded(values["kcal"], 0),
            rounded(values.get("p", 0)), rounded(values.get("c", 0)), rounded(values.get("f", 0)),
            rounded(values.get("fib", 0)), rounded(values.get("sug", 0)), rounded(values.get("na", 0), 0),
            portions, source,
        ])

    for food in json.load(open(survey_path))["SurveyFoods"]:
        portions = []
        for portion in sorted(food.get("foodPortions", []), key=lambda p: p.get("sequenceNumber", 0)):
            label = portion.get("portionDescription", "").strip()
            grams = portion.get("gramWeight")
            if not label or not grams or label.lower().startswith("guideline"):
                continue
            if label.lower() == "quantity not specified":
                label = "typical serving"
            portions.append([label[:48], rounded(grams)])
        category = (food.get("wweiaFoodCategory") or {}).get("wweiaFoodCategoryDescription", "")
        add(food["description"].strip(), category, nutrients(food), portions[:6], 0)

    for food in json.load(open(legacy_path))["SRLegacyFoods"]:
        category = (food.get("foodCategory") or {}).get("description", "")
        if category in SKIP_CATEGORIES:
            continue
        portions = []
        for portion in sorted(food.get("foodPortions", []), key=lambda p: p.get("sequenceNumber", 0)):
            grams = portion.get("gramWeight")
            amount = portion.get("amount") or portion.get("value") or 1
            unit = (portion.get("measureUnit") or {}).get("name", "")
            modifier = (portion.get("modifier") or "").strip()
            if unit == "undetermined":
                unit = ""
            label = " ".join(part for part in [f"{amount:g}", unit, modifier] if part).strip()
            if grams and label:
                portions.append([label[:48], rounded(grams)])
        add(food["description"].strip(), category, nutrients(food), portions[:6], 1)

    out = Path(__file__).resolve().parent.parent / "FlexUp" / "Resources" / "USDAFoods.json"
    out.write_text(json.dumps(rows, separators=(",", ":"), ensure_ascii=False))
    print(f"{len(rows)} foods -> {out}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
