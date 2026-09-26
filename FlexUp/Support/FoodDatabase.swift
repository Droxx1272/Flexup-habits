import Foundation

/// One food from USDA FoodData Central (public domain). Nutrients are per
/// 100 g; `portions` are USDA's own household measures with their weights.
struct USDAFood: Identifiable, Hashable, Sendable {
    struct Portion: Hashable, Sendable {
        let label: String
        let grams: Double
    }

    let id: Int
    let name: String
    let category: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodiumMg: Double
    let portions: [Portion]
    /// FNDDS "as eaten" dishes rank above SR Legacy ingredients.
    let isDish: Bool
    fileprivate let tokens: [String]

    func calories(grams: Double) -> Int {
        Int((kcal * grams / 100).rounded())
    }

    func macros(grams: Double) -> Macros {
        let factor = grams / 100
        return Macros(
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            sodiumMg: sodiumMg * factor
        )
    }

    /// A log-ready item for `grams` of this food.
    func item(grams: Double, portionLabel: String) -> FoodItem {
        FoodItem(
            name: name,
            baseCalories: calories(grams: grams),
            portion: portionLabel,
            baseMacros: macros(grams: grams),
            grams: grams,
            source: .usda
        )
    }
}

/// The bundled food list (`Resources/USDAFoods.json`, built by
/// `tools/build_food_db.py`). Loaded once, off the main thread, on first
/// search.
actor FoodDatabase {
    static let shared = FoodDatabase()

    private var foods: [USDAFood]?

    /// Everyday words USDA doesn't use, mostly Indian kitchen terms.
    private static let synonyms: [String: String] = [
        "roti": "chapati", "phulka": "chapati", "curd": "yogurt", "dahi": "yogurt",
        "chawal": "rice", "anda": "egg", "aloo": "potato", "gobi": "cauliflower",
        "palak": "spinach", "bhindi": "okra", "chana": "chickpeas", "chole": "chickpeas",
        "rajma": "kidney beans", "moong": "mung", "masoor": "lentils", "toor": "pigeon peas",
        "arhar": "pigeon peas", "besan": "chickpea flour", "atta": "whole wheat flour",
        "baingan": "eggplant", "brinjal": "eggplant", "capsicum": "sweet pepper",
        "maida": "wheat flour white", "sabzi": "vegetables", "doodh": "milk",
        "paneer": "paneer", "ghee": "ghee", "prawn": "shrimp", "prawns": "shrimp",
        "courgette": "zucchini", "aubergine": "eggplant", "mince": "ground",
        "porridge": "oatmeal", "chips": "fries", "crisps": "potato chips",
    ]

    var isLoaded: Bool { foods != nil }

    func search(_ query: String, limit: Int = 40) -> [USDAFood] {
        let all = loadedFoods()
        let words = Self.tokenize(query).flatMap { word in
            Self.synonyms[word].map(Self.tokenize) ?? [word]
        }
        guard !words.isEmpty else { return [] }
        let phrase = words.joined(separator: " ")

        var scored: [(score: Double, food: USDAFood)] = []
        for food in all {
            guard words.allSatisfy({ word in food.tokens.contains { $0.hasPrefix(word) } }) else { continue }
            var score = Double(food.tokens.count) * 0.25
            if food.tokens.first?.hasPrefix(words[0]) == true { score -= 3 }
            if food.tokens.joined(separator: " ").hasPrefix(phrase) { score -= 2 }
            if words.allSatisfy(food.tokens.contains) { score -= 1.5 }
            if !food.isDish { score += 1 }
            scored.append((score, food))
        }
        return scored
            .sorted { $0.score == $1.score ? $0.food.name < $1.food.name : $0.score < $1.score }
            .prefix(limit)
            .map(\.food)
    }

    private func loadedFoods() -> [USDAFood] {
        if let foods { return foods }
        let loaded = Self.load()
        foods = loaded
        return loaded
    }

    private static func load() -> [USDAFood] {
        guard
            let url = Bundle.main.url(forResource: "USDAFoods", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[Any]]
        else { return [] }

        func number(_ value: Any) -> Double { (value as? NSNumber)?.doubleValue ?? 0 }

        return rows.enumerated().compactMap { index, row in
            guard row.count >= 11, let rawName = row[0] as? String else { return nil }
            let portions = (row[9] as? [[Any]] ?? []).compactMap { pair -> USDAFood.Portion? in
                guard pair.count == 2, let label = pair[0] as? String else { return nil }
                let grams = number(pair[1])
                return grams > 0 ? USDAFood.Portion(label: label, grams: grams) : nil
            }
            let name = cleanName(rawName)
            return USDAFood(
                id: index,
                name: name,
                category: row[1] as? String ?? "",
                kcal: number(row[2]),
                protein: number(row[3]),
                carbs: number(row[4]),
                fat: number(row[5]),
                fiber: number(row[6]),
                sugar: number(row[7]),
                sodiumMg: number(row[8]),
                portions: portions,
                isDish: number(row[10]) == 0,
                tokens: tokenize(name)
            )
        }
    }

    /// USDA's "NS as to fat" / "NFS" qualifiers mean "not specified" and
    /// only add noise to a phone screen.
    private static func cleanName(_ name: String) -> String {
        name
            .replacingOccurrences(of: #",\s*NS as to [^,]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #",\s*NFS\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
