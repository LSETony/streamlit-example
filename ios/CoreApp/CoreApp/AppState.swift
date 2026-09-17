import Foundation
import SwiftUI

/// Single in-memory store for the whole app. Every field here backs one of
/// the 13 screens in the Figma source (splash, sign-in/OTP, the 4-step
/// onboarding wizard, Home, Workouts Library, Profile, Trainers,
/// Supplements, Food recipes) — nothing else.
@MainActor
final class AppState: ObservableObject {

    // MARK: Profile

    @Published var fullName: String = "Jarvis Kitsune Jr"
    var initials: String {
        fullName.split(separator: " ").compactMap(\.first).map(String.init).joined().uppercased()
    }

    // MARK: Onboarding wizard (4 steps: gender, goal, contradictions, level)

    @Published var hasCompletedOnboarding: Bool = false
    @Published var selectedGender: String?
    @Published var selectedGoal: String?
    @Published var selectedContradictions: Set<String> = []
    /// Contraindication chip options. Starts with the default set from the
    /// design; anything the member types and sends in the "type here" field
    /// is appended here too, so it shows up as a normal chip from then on.
    @Published var contradictionOptions: [String] = ["Allergic", "Diabetes", "Astma"]
    @Published var contradictionsNote: String = ""
    @Published var selectedLevel: String?

    // MARK: Home hero + progress card

    @Published var clubName: String = "RC Rezindtsii Arhitektorov"
    /// Other club locations the member can switch to. Only the current one
    /// has real data in this build — picking another just renames the
    /// header, since no per-location content exists in the source yet.
    @Published var clubLocations: [String] = [
        "RC Rezindtsii Arhitektorov",
        "RC Nagatino i-Land",
        "RC Символ",
    ]
    /// Backs the gym photo sheet opened from Home.
    @Published var clubAddress: String = "1-ya Tverskaya-Yamskaya, 2/1"
    @Published var clubHoursLabel: String = "until 22:00"
    @Published var clubDescription: String = "A full strength floor, free weights, cardio and a group class studio — steps from the metro, open daily."
    @Published var trainingProgressPercent: Int = 67
    @Published var trainingDay: Int = 1
    @Published var trainingMinutesToday: Int = 38
    @Published var trainingSetsToday: Int = 14
    @Published var trainingCaloriesToday: Int = 312

    /// Behind the Home "Your Progress" card — total sets/time/calories and
    /// a session-by-session history.
    @Published var workoutHistory: [WorkoutHistoryEntry] = [
        WorkoutHistoryEntry(date: "Today", title: "Chest and Triceps", sets: 14, minutes: 38, calories: 312),
        WorkoutHistoryEntry(date: "Yesterday", title: "Beginner Body Weight Plan", sets: 10, minutes: 27, calories: 205),
        WorkoutHistoryEntry(date: "Mon", title: "Sam's Prental Flow", sets: 12, minutes: 22, calories: 168),
        WorkoutHistoryEntry(date: "Sat", title: "Beginner Female Aesthetics", sets: 16, minutes: 41, calories: 289),
    ]
    var totalSetsThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.sets } }
    var totalMinutesThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.minutes } }
    var totalCaloriesThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.calories } }

    /// Muscle mass growth chart (Progress screen).
    @Published var muscleMassHistory: [MuscleMassEntry] = [
        MuscleMassEntry(label: "W1", kg: 32.4),
        MuscleMassEntry(label: "W2", kg: 32.9),
        MuscleMassEntry(label: "W3", kg: 33.1),
        MuscleMassEntry(label: "W4", kg: 33.6),
        MuscleMassEntry(label: "W5", kg: 34.0),
        MuscleMassEntry(label: "W6", kg: 34.5),
    ]

    /// Body composition (InBody-style scan readout, Progress screen).
    @Published var bodyFatPercent: Double = 16.2
    @Published var totalBodyWaterPercent: Double = 58.4
    @Published var visceralFatIndex: Int = 7
    @Published var basalMetabolicRate: Int = 1720

    // MARK: Club occupancy

    @Published var occupancyPercent: Int = 84
    @Published var occupancyInClub: Int = 38
    @Published var occupancyCapacity: Int = 90
    /// Bar heights 0...1 across the day (6 bars, matching the Figma source's
    /// exact geometry); index 3 is "now" and always accented.
    @Published var occupancyBars: [Double] = [0.27, 0.15, 0.35, 0.79, 1.0, 0.35]

    // MARK: Workout library (Beginner's Plan / Top 10 / Important)

    @Published var beginnerPlanCards: [WorkoutCard] = [
        WorkoutCard(imageName: "WorkoutBeginnerFemale", title: "Beginner Female Aesthetics", level: "Beginner", duration: "7 day", category: "Strength"),
        WorkoutCard(imageName: "WorkoutBodyWeight", title: "Beginner Body Weight Plan", level: "Beginner", duration: "7 day", category: "Strength"),
    ]
    @Published var topWorkoutCards: [WorkoutCard] = [
        WorkoutCard(imageName: "WorkoutPrentalFlow", title: "Sam's Prental Flow", level: "Beginner", duration: "22 mins", category: "Strength"),
        WorkoutCard(imageName: "WorkoutChestTriceps", title: "Chest and Triceps", level: "Inter", duration: "22 mins", category: "Strength"),
    ]
    @Published var importantCards: [ImportantCard] = [
        ImportantCard(title: "Gym Safety"),
        ImportantCard(title: "Events"),
    ]

    // MARK: Food recipes

    @Published var foodRecipes: [FoodRecipe] = [
        FoodRecipe(name: "Chicken Cajun"),
        FoodRecipe(name: "Protein pancakes"),
        FoodRecipe(name: "Beef Jerky"),
        FoodRecipe(name: "Carnivore Soup"),
    ]

    // MARK: Trainers

    @Published var trainers: [Trainer] = [
        Trainer(imageName: "Trainer1", name: "Arina Ivolga", specialty: "Personal trainer", rating: "4.9", reviews: 212, priceLabel: "$45/h", priceCompact: "45", nextAvailable: "Today", availabilityColor: .appSuccess, yearsExperience: "9 years", clients: 48, sessions: 1840, tags: ["Squat mechanics", "Peaking blocks", "Return to lifting"], bio: "Coaches the strength floor and writes the club's barbell progressions. Works with lifters coming back from long breaks and with members chasing a first 2× bodyweight squat."),
        Trainer(imageName: "Trainer2", name: "Mercede Moini", specialty: "Personal trainer", rating: "5.0", reviews: 168, priceLabel: "$52/h", priceCompact: "52", nextAvailable: "Tue", availabilityColor: .appAccent, yearsExperience: "12 years", clients: 62, sessions: 2210, tags: ["Body composition", "Conditioning", "Mobility"], bio: "Runs conditioning and mobility work for members coming back from injury or a long break from training."),
    ]
    @Published var trainerSlots: [String] = ["07:30", "11:00", "17:00", "19:30"]

    // MARK: Store / Supplements

    @Published var products: [Product] = [
        Product(abbr: "B", name: "B-Complex", form: "Capsule", dose: "50 mg", count: "90 capsules", price: 54, subscriptionPrice: 46, tag: "In protocol", tagColor: .appAccent,
                desc: "A full spread of B vitamins for energy metabolism and nervous-system support through heavy training blocks.",
                ingredients: [Ingredient(name: "Vitamin B6", amount: "10 mg"), Ingredient(name: "Vitamin B12", amount: "500 mcg"), Ingredient(name: "Folate", amount: "400 mcg")],
                benefits: "Supports energy release from food and reduces fatigue during high training volume.",
                risks: "Generally well tolerated. High-dose B6 over long periods can cause nerve tingling — stay within label dose.",
                interactions: "Can interfere with some Parkinson's and epilepsy medications — check with a doctor if you take either."),
        Product(abbr: "Cr", name: "Creatine monohydrate", form: "Powder", dose: "5 g", count: "500 g", price: 150, subscriptionPrice: 128, tag: "Recommended", tagColor: .appSuccess,
                desc: "Creapure monohydrate. The most studied performance supplement there is; no loading phase needed.",
                ingredients: [Ingredient(name: "Creatine monohydrate", amount: "5 000 mg")],
                benefits: "Adds a few reps at a given load and roughly 1–2 kg of water inside the muscle.",
                risks: "Safe in healthy adults at 3–5 g. Drink enough water; kidney disease is the one contraindication.",
                interactions: "No meaningful drug interactions. Caffeine does not cancel it, despite the old claim."),
        Product(abbr: "Zn", name: "Zinc picolinate", form: "Capsule", dose: "15 mg", count: "100 capsules", price: 35, subscriptionPrice: 30, tag: "Watch dose", tagColor: .appWarning,
                desc: "A 15 mg dose, deliberately lower than the 50 mg tubs sold elsewhere.",
                ingredients: [Ingredient(name: "Zinc (picolinate)", amount: "15 mg"), Ingredient(name: "Copper (gluconate)", amount: "1 mg")],
                benefits: "Covers a genuine gap in low-meat diets and supports immune function.",
                risks: "Above 40 mg daily for months depletes copper and can cause anaemia.",
                interactions: "Competes with iron — four hours apart. Also reduces absorption of some antibiotics."),
        Product(abbr: "Mg", name: "Magnesium", form: "Capsule", dose: "400 mg", count: "120 capsules", price: 85, subscriptionPrice: 72, tag: "In protocol", tagColor: .appAccent,
                desc: "The sleep-and-recovery magnesium. Glycinate is well absorbed and does not act as a laxative at this dose.",
                ingredients: [Ingredient(name: "Magnesium (glycinate)", amount: "400 mg"), Ingredient(name: "Glycine", amount: "1 200 mg")],
                benefits: "Shortens time to sleep and reduces cramping in heavy training weeks.",
                risks: "Loose stools above 600 mg. Anyone with reduced kidney function should ask a doctor first.",
                interactions: "Blunts absorption of tetracycline and quinolone antibiotics, and of bisphosphonates. Separate by two hours."),
    ]
    @Published var cart: [CartLine] = []

    var cartCount: Int { cart.count }
    var cartTotal: Int { cart.reduce(0) { $0 + $1.price } }

    func addToCart(_ product: Product) {
        cart.append(CartLine(name: product.name, price: product.price))
    }
    func removeFromCart(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
    }
    func clearCart() { cart.removeAll() }

    // MARK: Profile

    @Published var memberSince: String = "March 2023"
    @Published var totalVisits: Int = 128
    @Published var septemberVisits: Int = 18
    @Published var scansThisMonth: Int = 6
    @Published var ptSessionsLeft: Int = 3
    @Published var appleHealthSyncEnabled: Bool = true
    @Published var membershipPlanName: String = "Unlimited 24/7"
    @Published var membershipRenewDate: String = "12 Mar 2027"
}

struct CartLine: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
}
