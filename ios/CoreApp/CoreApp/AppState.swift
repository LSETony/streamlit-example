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
    // Catalog data below is loaded from Supabase — see loadFromSupabase()
    // in AppState+Supabase.swift. Starts empty; supabase/schema.sql seeds
    // the actual rows.

    @Published var beginnerPlanCards: [WorkoutCard] = []
    @Published var topWorkoutCards: [WorkoutCard] = []
    @Published var importantCards: [ImportantCard] = []

    // MARK: Food recipes

    @Published var foodRecipes: [FoodRecipe] = []

    // MARK: Trainers

    @Published var trainers: [Trainer] = []
    @Published var trainerSlots: [String] = ["07:30", "11:00", "17:00", "19:30"]

    // MARK: Calendar bookings (Supabase-backed, scoped to DeviceUser.id)

    @Published var bookedSessions: [BookedSession] = []

    func rescheduleSession(_ session: BookedSession, to newDate: Date) {
        guard let index = bookedSessions.firstIndex(where: { $0.id == session.id }) else { return }
        bookedSessions[index].date = newDate
        Task { await self.updateSessionDate(session.id, to: newDate) }
    }

    func cancelSession(_ session: BookedSession) {
        bookedSessions.removeAll { $0.id == session.id }
        Task { await self.deleteSession(session.id) }
    }

    // MARK: Zone booking (behind Home's "Book" tile)

    @Published var gymZones: [GymZone] = []

    /// Books the next occurrence of `time` ("HH:mm") for `zone`, adding it
    /// to bookedSessions (and Supabase) so it shows up in the Calendar tab
    /// too.
    func bookZone(_ zone: GymZone, at time: String) {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let calendar = Calendar.current
        let now = Date()
        var date = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) ?? now
        if date < now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        let session = BookedSession(date: date, title: zone.name, trainerName: zone.subtitle)
        bookedSessions.append(session)
        Task { await self.insertSession(session) }
    }

    // MARK: Store / Supplements

    @Published var products: [Product] = []
    @Published var cart: [CartLine] = []

    var cartCount: Int { cart.count }
    var cartTotal: Int { cart.reduce(0) { $0 + $1.price } }

    func addToCart(_ product: Product) {
        let line = CartLine(name: product.name, price: product.price)
        cart.append(line)
        Task { await self.insertCartLine(line) }
    }
    func removeFromCart(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
        Task { await self.deleteCartLine(line.id) }
    }
    func clearCart() {
        cart.removeAll()
        Task { await self.deleteAllCartLines() }
    }

    // MARK: Club subscriptions (behind Home's wallet icon)

    @Published var subscriptionPlans: [SubscriptionPlan] = []

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
    let id: UUID
    let name: String
    let price: Int

    /// `id` defaults to a fresh UUID for locally-added lines, but can be
    /// passed explicitly when reconstructing a row already stored in
    /// Supabase (see CartLineRow.toModel() in SupabaseModels.swift).
    init(id: UUID = UUID(), name: String, price: Int) {
        self.id = id
        self.name = name
        self.price = price
    }
}
