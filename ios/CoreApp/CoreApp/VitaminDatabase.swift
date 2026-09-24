import Foundation

/// A built-in reference for common vitamins/supplements — lets Scan give a
/// useful result for labels that aren't in the club's own Store catalog
/// (appState.products), not just the handful of products sold there.
struct VitaminInfo: Identifiable {
    let id = UUID()
    let name: String
    /// Lowercase keywords matched against scanned label text.
    let aliases: [String]
    let description: String
    let usage: String
    let restrictions: String
}

enum VitaminDatabase {
    static let all: [VitaminInfo] = [
        VitaminInfo(
            name: "Vitamin D3", aliases: ["vitamin d3", "vitamin d", "cholecalciferol", "vit d"],
            description: "A fat-soluble vitamin the body mostly makes from sunlight — supports calcium absorption, bone density and immune function.",
            usage: "Typically 1,000–4,000 IU daily with a meal containing fat, for better absorption.",
            restrictions: "Very high doses can raise blood calcium. Avoid stacking with other high-dose calcium/D supplements without medical advice."
        ),
        VitaminInfo(
            name: "Vitamin C", aliases: ["vitamin c", "ascorbic acid"],
            description: "A water-soluble antioxidant vitamin supporting immune function, skin and connective tissue health.",
            usage: "500–1,000 mg daily is a common range; the body excretes what it doesn't use.",
            restrictions: "High doses (2g+/day) can cause digestive upset. Caution with a history of kidney stones."
        ),
        VitaminInfo(
            name: "Vitamin B12", aliases: ["vitamin b12", "b12", "cobalamin", "cyanocobalamin", "methylcobalamin"],
            description: "Supports red blood cell formation, nerve function and energy metabolism; mainly found in animal products.",
            usage: "Typical maintenance dose is 500–1,000 mcg daily, especially useful for plant-based diets.",
            restrictions: "Very well tolerated even at high doses — excess is excreted. No major interactions at normal doses."
        ),
        VitaminInfo(
            name: "B-Complex", aliases: ["b-complex", "b complex", "vitamin b complex", "b vitamins"],
            description: "A blend of all 8 B vitamins supporting energy metabolism and nervous-system function during training.",
            usage: "One serving daily with food, per label dosing.",
            restrictions: "High-dose B6 over long periods can cause nerve tingling — don't exceed label dose long-term."
        ),
        VitaminInfo(
            name: "Omega-3 Fish Oil", aliases: ["omega-3", "omega 3", "fish oil", "epa dha", "epa/dha"],
            description: "EPA and DHA fatty acids supporting heart, joint and brain health, and reducing exercise-induced inflammation.",
            usage: "1–3 g combined EPA/DHA daily with a meal.",
            restrictions: "Can mildly thin the blood — check with a doctor if already on blood thinners. May cause fishy aftertaste/reflux."
        ),
        VitaminInfo(
            name: "Zinc", aliases: ["zinc", "zinc picolinate", "zinc gluconate", "zinc citrate"],
            description: "A trace mineral supporting immune function, testosterone production and wound healing.",
            usage: "15–30 mg daily, ideally with food to avoid nausea.",
            restrictions: "Long-term high doses can cause copper deficiency — many products pair zinc with a small amount of copper."
        ),
        VitaminInfo(
            name: "Magnesium", aliases: ["magnesium", "magnesium glycinate", "magnesium citrate", "mg glycinate"],
            description: "Supports muscle relaxation, sleep quality and nervous-system function — commonly depleted by heavy training and sweating.",
            usage: "300–400 mg daily, often taken in the evening.",
            restrictions: "Citrate forms can cause loose stools at high doses. Caution with kidney disease — check with a doctor."
        ),
        VitaminInfo(
            name: "Iron", aliases: ["iron", "ferrous sulfate", "ferrous fumarate", "iron bisglycinate"],
            description: "Essential for oxygen transport in red blood cells — low iron shows up as fatigue and poor training recovery.",
            usage: "Dose varies widely by individual need — best guided by a blood test rather than taken blindly.",
            restrictions: "Excess iron builds up in the body and is harder to clear than most nutrients — don't supplement without a confirmed deficiency."
        ),
        VitaminInfo(
            name: "Calcium", aliases: ["calcium", "calcium carbonate", "calcium citrate"],
            description: "Supports bone density and muscle contraction, including the heart.",
            usage: "500–1,000 mg daily, split across meals for better absorption.",
            restrictions: "High total intake (diet + supplement combined) has been linked to kidney stones and cardiovascular concerns in some studies."
        ),
        VitaminInfo(
            name: "Multivitamin", aliases: ["multivitamin", "multi-vitamin", "daily multi"],
            description: "A broad blend covering baseline vitamin/mineral needs — a safety net, not a substitute for food variety.",
            usage: "One serving daily with a meal, per label dosing.",
            restrictions: "Check for overlap if also taking single-nutrient supplements (e.g. separate vitamin D or iron) to avoid doubling up."
        ),
        VitaminInfo(
            name: "Creatine Monohydrate", aliases: ["creatine", "creatine monohydrate", "creapure"],
            description: "The most studied performance supplement — increases available energy for short, high-intensity efforts.",
            usage: "3–5 g daily, any time of day; no loading phase needed.",
            restrictions: "Can cause mild water retention initially. Drink enough water; generally safe at standard doses long-term."
        ),
        VitaminInfo(
            name: "Ashwagandha", aliases: ["ashwagandha", "withania somnifera"],
            description: "An adaptogenic herb studied for stress reduction, sleep quality and modest strength/recovery benefits.",
            usage: "300–600 mg of a standardized root extract daily.",
            restrictions: "Avoid during pregnancy and with autoimmune conditions or thyroid medication without medical advice."
        ),
        VitaminInfo(
            name: "Melatonin", aliases: ["melatonin"],
            description: "A hormone that signals the body it's time to sleep — used short-term to help fall asleep faster.",
            usage: "0.5–3 mg, 30–60 minutes before bed. Lower doses are often just as effective as higher ones.",
            restrictions: "Can cause grogginess the next morning at higher doses. Not intended for long-term nightly use without a reason to."
        ),
    ]

    /// Matches scanned label text against this database's aliases.
    static func match(text: String) -> VitaminInfo? {
        let lowered = text.lowercased()
        return all.first { info in
            info.aliases.contains { lowered.contains($0) }
        }
    }
}
