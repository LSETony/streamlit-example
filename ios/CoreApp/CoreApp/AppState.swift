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
    /// The mini bar-chart sparkline next to "Your Progress" (9 bars, height
    /// 0...1, matching the Figma source's exact geometry); highlighted bars
    /// mark days with a completed workout.
    @Published var progressSparkline: [(value: Double, highlighted: Bool)] = [
        (0.33, true), (0.68, true), (0.47, false), (1.0, false), (0.75, true),
        (0.56, false), (0.22, true), (0.68, false), (0.87, true),
    ]

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
    var todayCalories: Int { workoutHistory.first(where: { $0.date == "Today" })?.calories ?? 0 }

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
    /// Bar heights 0...1 across the day (5 bars, matching the Figma source's
    /// exact geometry); index 2 is "now" and always accented.
    @Published var occupancyBars: [Double] = [0.145, 0.355, 0.79, 1.0, 0.355]
    /// Fuller hour-by-hour breakdown behind the occupancy detail screen.
    @Published var occupancyHourly: [(hour: String, value: Double)] = [
        ("06", 0.10), ("08", 0.22), ("10", 0.355), ("12", 0.5), ("14", 0.79),
        ("16", 0.9), ("18", 1.0), ("20", 0.6), ("22", 0.355),
    ]
    /// The hour matching "now" on the compact Home card's accented bar.
    @Published var occupancyNowHour: String = "14"

    // MARK: Workout library (Beginner's Plan / Top 10 / Important)

    @Published var beginnerPlanCards: [WorkoutCard] = [
        WorkoutCard(
            imageName: "WorkoutBeginnerFemale", title: "Beginner Female Aesthetics", level: "Beginner", duration: "7 day", category: "Strength",
            exercises: [
                Exercise(name: "Bodyweight Squats", icon: "figure.strengthtraining.functional", sets: 3, reps: "15"),
                Exercise(name: "Glute Bridges", icon: "figure.core.training", sets: 3, reps: "15"),
                Exercise(name: "Knee Push-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
                Exercise(name: "Plank", icon: "figure.core.training", sets: 3, reps: "30 sec"),
                Exercise(name: "Lunges", icon: "figure.walk", sets: 3, reps: "12"),
                Exercise(name: "Bicycle Crunches", icon: "figure.core.training", sets: 3, reps: "20"),
            ]
        ),
        WorkoutCard(
            imageName: "WorkoutBodyWeight", title: "Beginner Body Weight Plan", level: "Beginner", duration: "7 day", category: "Strength",
            exercises: [
                Exercise(name: "Jumping Jacks", icon: "figure.jumprope", sets: 3, reps: "30 sec"),
                Exercise(name: "Push-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
                Exercise(name: "Squats", icon: "figure.strengthtraining.functional", sets: 3, reps: "15"),
                Exercise(name: "Mountain Climbers", icon: "figure.highintensity.intervaltraining", sets: 3, reps: "20"),
                Exercise(name: "Plank", icon: "figure.core.training", sets: 3, reps: "30 sec"),
            ]
        ),
    ]
    @Published var topWorkoutCards: [WorkoutCard] = [
        WorkoutCard(
            imageName: "WorkoutPrentalFlow", title: "Sam's Prental Flow", level: "Beginner", duration: "22 mins", category: "Strength",
            exercises: [
                Exercise(name: "Cat-Cow Stretch", icon: "figure.flexibility", sets: 3, reps: "10"),
                Exercise(name: "Pelvic Tilts", icon: "figure.flexibility", sets: 3, reps: "12"),
                Exercise(name: "Wall Push-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
                Exercise(name: "Side-Lying Leg Lifts", icon: "figure.core.training", sets: 3, reps: "12"),
                Exercise(name: "Seated Marching", icon: "figure.walk", sets: 3, reps: "15"),
                Exercise(name: "Deep Breathing", icon: "figure.mind.and.body", sets: 3, reps: "1 min"),
            ]
        ),
        WorkoutCard(
            imageName: "WorkoutChestTriceps", title: "Chest and Triceps", level: "Inter", duration: "22 mins", category: "Strength",
            exercises: [
                Exercise(name: "Push-ups", icon: "figure.strengthtraining.traditional", sets: 4, reps: "12"),
                Exercise(name: "Dumbbell Bench Press", icon: "dumbbell.fill", sets: 4, reps: "10"),
                Exercise(name: "Tricep Dips", icon: "figure.strengthtraining.traditional", sets: 3, reps: "12"),
                Exercise(name: "Overhead Tricep Extension", icon: "dumbbell.fill", sets: 3, reps: "12"),
                Exercise(name: "Chest Fly", icon: "dumbbell.fill", sets: 3, reps: "12"),
                Exercise(name: "Close-Grip Push-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
            ]
        ),
    ]
    @Published var importantCards: [ImportantCard] = [
        ImportantCard(icon: "shield.fill", title: "Gym Safety", subtitle: "Rules & equipment guide"),
        ImportantCard(icon: "party.popper.fill", title: "Events", subtitle: "What's on this month"),
    ]

    // MARK: Food recipes

    @Published var foodRecipes: [FoodRecipe] = [
        FoodRecipe(name: "Chicken Cajun", price: 9, ingredients: ["Chicken breast", "Cajun spice", "Olive oil", "Bell pepper"]),
        FoodRecipe(name: "Protein pancakes", price: 6, ingredients: ["Whey protein", "Egg", "Banana", "Oats"]),
        FoodRecipe(name: "Beef Jerky", price: 12, ingredients: ["Beef", "Soy sauce", "Black pepper", "Garlic powder"]),
        FoodRecipe(name: "Carnivore Soup", price: 10, ingredients: ["Beef bone broth", "Beef chunks", "Salt", "Egg"]),
    ]

    // MARK: Trainers

    @Published var trainers: [Trainer] = [
        Trainer(imageName: "Trainer1", name: "Arina Ivolga", specialty: "Personal trainer", rating: "4.9", reviews: 212, priceLabel: "$45/h", priceCompact: "45", nextAvailable: "Today", availabilityColor: .appSuccess, yearsExperience: "9 years", clients: 48, sessions: 1840, tags: ["Squat mechanics", "Peaking blocks", "Return to lifting"], bio: "Coaches the strength floor and writes the club's barbell progressions. Works with lifters coming back from long breaks and with members chasing a first 2× bodyweight squat."),
        Trainer(imageName: "Trainer2", name: "Mercede Moini", specialty: "Personal trainer", rating: "5.0", reviews: 168, priceLabel: "$52/h", priceCompact: "52", nextAvailable: "Tue", availabilityColor: .appAccent, yearsExperience: "12 years", clients: 62, sessions: 2210, tags: ["Body composition", "Conditioning", "Mobility"], bio: "Runs conditioning and mobility work for members coming back from injury or a long break from training."),
    ]
    @Published var trainerSlots: [String] = ["07:30", "11:00", "17:00", "19:30"]

    // MARK: Calendar bookings

    @Published var bookedSessions: [BookedSession] = {
        let calendar = Calendar.current
        let now = Date()
        func at(dayOffset: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        return [
            BookedSession(date: at(dayOffset: 0, hour: 18), title: "Personal Training", trainerName: "Arina Ivolga"),
            BookedSession(date: at(dayOffset: 2, hour: 9), title: "Group Class · HIIT", trainerName: "Mercede Moini"),
            BookedSession(date: at(dayOffset: 5, hour: 17), title: "Personal Training", trainerName: "Arina Ivolga"),
        ]
    }()

    func rescheduleSession(_ session: BookedSession, to newDate: Date) {
        guard let index = bookedSessions.firstIndex(where: { $0.id == session.id }) else { return }
        bookedSessions[index].date = newDate
    }

    func cancelSession(_ session: BookedSession) {
        bookedSessions.removeAll { $0.id == session.id }
    }

    // MARK: Zone booking (behind Home's "Book" tile)

    @Published var gymZones: [GymZone] = [
        GymZone(icon: "figure.pilates", name: "Pilates Studio", subtitle: "Reformer & mat sessions", capacity: 8),
        GymZone(icon: "figure.run", name: "Running Track", subtitle: "Indoor treadmill lane", capacity: 12),
        GymZone(icon: "dumbbell.fill", name: "Free Weights Floor", subtitle: "Barbells, racks & benches", capacity: 20),
        GymZone(icon: "flame.fill", name: "Sauna & Recovery", subtitle: "Steam room & sauna", capacity: 6),
    ]

    /// Books the next occurrence of `time` ("HH:mm") for `zone`, adding it
    /// to bookedSessions so it shows up in the Calendar tab too.
    func bookZone(_ zone: GymZone, at time: String) {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let calendar = Calendar.current
        let now = Date()
        var date = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) ?? now
        if date < now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        bookedSessions.append(BookedSession(date: date, title: zone.name, trainerName: zone.subtitle))
    }

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

    // MARK: Club subscriptions (behind Home's wallet icon)

    @Published var subscriptionPlans: [SubscriptionPlan] = [
        SubscriptionPlan(name: "Basic", price: 39, period: "mo", perks: ["Gym floor access", "Locker room", "1 club location"], recommended: false),
        SubscriptionPlan(name: "Unlimited 24/7", price: 79, period: "mo", perks: ["24/7 access, every club", "Group classes included", "Guest passes ×2/mo"], recommended: true),
        SubscriptionPlan(name: "Premium + PT", price: 129, period: "mo", perks: ["Everything in Unlimited", "4 PT sessions/mo", "Priority booking"], recommended: false),
    ]

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
