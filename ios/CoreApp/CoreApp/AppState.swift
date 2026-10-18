import Foundation
import SwiftUI
import WidgetKit

/// A language core. actually ships translations for (see
/// Localizable.xcstrings) — not every language iOS itself supports.
/// `.arabic` additionally flips the whole app to right-to-left (see
/// CoreAppApp.swift's RootView, which applies both the locale and the
/// layout direction from AppState.preferredLanguage).
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    case arabic = "ar"

    var id: String { rawValue }

    /// Shown in its own language (not translated through the current
    /// locale), like every real iOS language picker — "Русский" reads the
    /// same regardless of which language is currently selected.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        case .arabic: "العربية"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
    var isRightToLeft: Bool { self == .arabic }
}

/// Single in-memory store for the whole app. Every field here backs one of
/// the 13 screens in the Figma source (splash, sign-in/OTP, the 4-step
/// onboarding wizard, Home, Workouts Library, Profile, Trainers,
/// Supplements, Food recipes) — nothing else.
@MainActor
final class AppState: ObservableObject {

    init() {
        avatarImageURLString = UserDefaults.standard.string(forKey: Self.avatarImageURLKey)
        avatarPresetID = UserDefaults.standard.string(forKey: Self.avatarPresetIDKey)
        if let saved = UserDefaults.standard.string(forKey: Self.preferredLanguageKey), let language = AppLanguage(rawValue: saved) {
            preferredLanguage = language
        } else {
            // First launch: default to the device's own language if core.
            // actually supports it, English otherwise — not forced on
            // every member regardless of their phone's language.
            let deviceLanguage = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier }
            preferredLanguage = deviceLanguage.flatMap(AppLanguage.init) ?? .english
        }
        refreshOccupancyNow()
    }

    // MARK: Language

    @Published var preferredLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(preferredLanguage.rawValue, forKey: Self.preferredLanguageKey)
            Font.brandFontOverride = preferredLanguage == .russian ? "Geologica-SemiBold" : nil
        }
    }
    private static let preferredLanguageKey = "core.preferredLanguage"

    // MARK: Profile

    @Published var fullName: String = "Jarvis Kitsune Jr"
    var initials: String {
        fullName.split(separator: " ").compactMap(\.first).map(String.init).joined().uppercased()
    }

    // MARK: Onboarding wizard (4 steps: gender, goal, contradictions, level)

    // TEMPORARY: true so disabling requiresSignIn (CoreAppApp.swift) goes
    // straight to Home instead of stopping at onboarding. Revert to false
    // together with requiresSignIn.
    @Published var hasCompletedOnboarding: Bool = true
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
    /// Every real club location the member can switch to — each pinned on
    /// LocationPickerView's map with its own real address/coordinates/
    /// hours/description, not just a renamed header.
    @Published var gymLocations: [GymLocation] = [
        GymLocation(
            name: "RC Rezindtsii Arhitektorov", city: "Moscow", address: "1-ya Tverskaya-Yamskaya, 2/1, Moscow",
            latitude: 55.7766, longitude: 37.5926, hoursLabel: "until 22:00",
            description: "A full strength floor, free weights, cardio and a group class studio — steps from the metro, open daily."
        ),
        GymLocation(
            name: "RC Dubai Marina", city: "Dubai", address: "Marina Walk, Dubai Marina, Dubai",
            latitude: 25.0805, longitude: 55.1403, hoursLabel: "until 23:00",
            description: "Floor-to-ceiling marina views, a full free-weight floor and a rooftop studio — steps from Dubai Marina Mall."
        ),
        GymLocation(
            name: "RC Downtown Dubai", city: "Dubai", address: "Sheikh Mohammed bin Rashid Blvd, Downtown Dubai, Dubai",
            latitude: 25.1972, longitude: 55.2744, hoursLabel: "until 23:00",
            description: "In the shadow of Burj Khalifa — a premium strength floor, sauna and recovery suite for the downtown crowd."
        ),
        GymLocation(
            name: "RC New York", city: "New York", address: "5th Avenue, Flatiron District, New York",
            latitude: 40.7410, longitude: -73.9896, hoursLabel: "until 23:00",
            description: "A Flatiron fixture — free weights, a run club meeting point and the city's best post-workout matcha bar next door."
        ),
        GymLocation(
            name: "RC Los Angeles", city: "Los Angeles", address: "Melrose Avenue, West Hollywood, Los Angeles",
            latitude: 34.0836, longitude: -118.3617, hoursLabel: "until 22:00",
            description: "West Hollywood's go-to strength floor — outdoor turf area, cold plunge and a juice bar on Melrose."
        ),
        GymLocation(
            name: "RC Miami", city: "Miami", address: "Ocean Drive, South Beach, Miami",
            latitude: 25.7826, longitude: -80.1300, hoursLabel: "until 23:00",
            description: "Steps from the sand on Ocean Drive — open-air cardio deck, beach bootcamp classes and an on-site smoothie bar."
        ),
    ]
    /// The currently selected location's full record — falls back to the
    /// first one if clubName somehow doesn't match (shouldn't happen).
    var currentLocation: GymLocation { gymLocations.first(where: { $0.name == clubName }) ?? gymLocations[0] }
    /// Backs the gym photo sheet opened from Home.
    var clubAddress: String { currentLocation.address }
    var clubHoursLabel: String { currentLocation.hoursLabel }
    var clubDescription: String { currentLocation.description }
    /// Plays Home's bundled hero video (HeroVideo.mp4) on a loop — created
    /// here, not inside HomeView, so it starts immediately at launch
    /// instead of only once HomeView's hero view first appears.
    let heroVideoPlayer = HeroVideoPlayerService()
    /// Extra real gym photos for the photo strip in GymPhotoViewer.
    @Published var gymPhotoURLs: [URL] = []

    /// Behind the Home "Your Progress" card — total sets/time/calories and
    /// a session-by-session history. Starts with past-day sample history
    /// only; "Today" entries only appear once a real workout is completed
    /// (WorkoutDetailView.recordCompletion), so these stay real counts.
    @Published var workoutHistory: [WorkoutHistoryEntry] = [
        WorkoutHistoryEntry(date: "Yesterday", title: "Beginner Body Weight Plan", sets: 10, minutes: 27, calories: 205, completedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()),
        WorkoutHistoryEntry(date: "Mon", title: "Sam's Prental Flow", sets: 12, minutes: 22, calories: 168, completedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()),
        WorkoutHistoryEntry(date: "Sat", title: "Beginner Female Aesthetics", sets: 16, minutes: 41, calories: 289, completedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()),
    ]
    /// Today's entries, summed — a member can complete more than one
    /// session in a day, so Home's Sets/Time/Calories tiles reflect all of
    /// them, not just the most recent.
    private var todaysEntries: [WorkoutHistoryEntry] { workoutHistory.filter { Calendar.current.isDateInToday($0.completedAt) } }
    var trainingSetsToday: Int { todaysEntries.reduce(0) { $0 + $1.sets } }
    var trainingMinutesToday: Int { todaysEntries.reduce(0) { $0 + $1.minutes } }
    var trainingCaloriesToday: Int { todaysEntries.reduce(0) { $0 + $1.calories } }
    var totalSetsThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.sets } }
    var totalMinutesThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.minutes } }
    var totalCaloriesThisWeek: Int { workoutHistory.reduce(0) { $0 + $1.calories } }
    var todayCalories: Int { trainingCaloriesToday }

    /// Muscle mass growth chart (Progress screen).
    @Published var muscleMassHistory: [MuscleMassEntry] = [
        MuscleMassEntry(label: "W1", kg: 32.4),
        MuscleMassEntry(label: "W2", kg: 32.9),
        MuscleMassEntry(label: "W3", kg: 33.1),
        MuscleMassEntry(label: "W4", kg: 33.6),
        MuscleMassEntry(label: "W5", kg: 34.0),
        MuscleMassEntry(label: "W6", kg: 34.5),
    ]

    /// Body composition (InBody-style scan history, Progress screen) —
    /// each entry is one scan at the gym's InBody machine; oldest first.
    /// The stat tiles elsewhere show the latest scan via the computed
    /// properties below.
    @Published var inBodyHistory: [InBodyEntry] = [
        InBodyEntry(scannedAt: Calendar.current.date(byAdding: .day, value: -42, to: Date()) ?? Date(), bodyFatPercent: 19.1, totalBodyWaterPercent: 55.8, visceralFatIndex: 9, basalMetabolicRate: 1650),
        InBodyEntry(scannedAt: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(), bodyFatPercent: 17.6, totalBodyWaterPercent: 57.0, visceralFatIndex: 8, basalMetabolicRate: 1685),
        InBodyEntry(scannedAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), bodyFatPercent: 16.2, totalBodyWaterPercent: 58.4, visceralFatIndex: 7, basalMetabolicRate: 1720),
    ]
    var latestInBodyScan: InBodyEntry? { inBodyHistory.max(by: { $0.scannedAt < $1.scannedAt }) }
    var bodyFatPercent: Double { latestInBodyScan?.bodyFatPercent ?? 0 }
    var totalBodyWaterPercent: Double { latestInBodyScan?.totalBodyWaterPercent ?? 0 }
    var visceralFatIndex: Int { latestInBodyScan?.visceralFatIndex ?? 0 }
    var basalMetabolicRate: Int { latestInBodyScan?.basalMetabolicRate ?? 0 }

    func logInBodyScan(bodyFatPercent: Double, totalBodyWaterPercent: Double, visceralFatIndex: Int, basalMetabolicRate: Int) {
        inBodyHistory.append(
            InBodyEntry(
                scannedAt: Date(), bodyFatPercent: bodyFatPercent, totalBodyWaterPercent: totalBodyWaterPercent,
                visceralFatIndex: visceralFatIndex, basalMetabolicRate: basalMetabolicRate
            )
        )
    }

    // MARK: Club occupancy

    /// A "typical day" shape (same idea as Google Maps' Popular Times —
    /// averaged, not a live sensor feed, since there's no turnstile/camera
    /// hardware here to source a real headcount from) that
    /// refreshOccupancyNow() samples against the real clock, so the
    /// reading actually moves instead of being permanently frozen at
    /// whatever hardcoded number it launched with.
    struct OccupancyPoint: Identifiable, Equatable {
        let id = UUID()
        let hour: Int // 0...23
        let shape: Double // 0...1, this hour's share of a full house
        var isNow: Bool = false
    }

    @Published var occupancyPercent: Int = 0
    @Published var occupancyInClub: Int = 0
    @Published var occupancyCapacity: Int = 90
    @Published var occupancyHourly: [OccupancyPoint] = [
        OccupancyPoint(hour: 6, shape: 0.10), OccupancyPoint(hour: 8, shape: 0.22),
        OccupancyPoint(hour: 10, shape: 0.355), OccupancyPoint(hour: 12, shape: 0.5),
        OccupancyPoint(hour: 14, shape: 0.79), OccupancyPoint(hour: 16, shape: 0.9),
        OccupancyPoint(hour: 18, shape: 1.0), OccupancyPoint(hour: 20, shape: 0.6),
        OccupancyPoint(hour: 22, shape: 0.355),
    ]

    /// Samples the typical-day curve at the current wall-clock time —
    /// interpolated between the two nearest hour points, so the number
    /// genuinely moves minute to minute rather than jumping once an hour.
    /// Call on launch and periodically while the occupancy screens are on
    /// screen (see HomeView/OccupancyDetailView's .task loops).
    func refreshOccupancyNow() {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let fractionalHour = Double(now.hour ?? 12) + Double(now.minute ?? 0) / 60
        let sorted = occupancyHourly.sorted { $0.hour < $1.hour }
        guard let first = sorted.first, let last = sorted.last else { return }

        let shape: Double
        if fractionalHour <= Double(first.hour) {
            shape = first.shape
        } else if fractionalHour >= Double(last.hour) {
            shape = last.shape
        } else {
            let upperIndex = sorted.firstIndex { Double($0.hour) >= fractionalHour } ?? sorted.count - 1
            let lower = sorted[max(0, upperIndex - 1)]
            let upper = sorted[upperIndex]
            let span = Double(upper.hour - lower.hour)
            let t = span > 0 ? (fractionalHour - Double(lower.hour)) / span : 0
            shape = lower.shape + (upper.shape - lower.shape) * t
        }

        let nearestHour = sorted.min { abs(Double($0.hour) - fractionalHour) < abs(Double($1.hour) - fractionalHour) }?.hour
        occupancyHourly = sorted.map { OccupancyPoint(hour: $0.hour, shape: $0.shape, isNow: $0.hour == nearestHour) }
        occupancyPercent = Int((shape * 100).rounded())
        occupancyInClub = Int((shape * Double(occupancyCapacity)).rounded())
    }

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
        NotificationService.scheduleSessionReminder(id: session.id, title: session.title, trainerName: session.trainerName, date: newDate)
        Task { await self.updateSessionDate(session.id, to: newDate) }
    }

    func cancelSession(_ session: BookedSession) {
        bookedSessions.removeAll { $0.id == session.id }
        NotificationService.cancelSessionReminder(id: session.id)
        Task { await self.deleteSession(session.id) }
    }

    // MARK: Zone booking (behind Home's "Book" tile)

    @Published var gymZones: [GymZone] = []

    /// Books the next occurrence of `time` ("HH:mm") for `zone`, adding it
    /// to bookedSessions (and Supabase) so it shows up in the Calendar tab
    /// too.
    func bookZone(_ zone: GymZone, at time: String) {
        guard let date = Self.nextOccurrence(of: time) else { return }
        let session = BookedSession(date: date, title: zone.name, trainerName: zone.subtitle)
        bookedSessions.append(session)
        NotificationService.scheduleSessionReminder(id: session.id, title: session.title, trainerName: session.trainerName, date: session.date)
        Task { await self.insertSession(session) }
    }

    /// The next real calendar `Date` matching a "HH:mm" time string — today
    /// if that time hasn't passed yet, otherwise tomorrow.
    static func nextOccurrence(of time: String) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let calendar = Calendar.current
        let now = Date()
        var date = calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: now) ?? now
        if date < now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    // MARK: Today's Specials (unbooked trainer slots, discounted)

    /// A trainer time slot nobody has booked yet today — offered at a
    /// discount so the club doesn't just lose that capacity. Behind Home's
    /// "Specials for today" card.
    struct TrainerSpecial: Identifiable {
        var id: String { "\(trainer.id)-\(time)" }
        let trainer: Trainer
        let time: String
        let originalPrice: Int
        let discountPercent: Int
        var discountedPrice: Int { max(0, originalPrice - originalPrice * discountPercent / 100) }
    }

    /// Every (trainer, slot) pair for today that isn't already in
    /// bookedSessions — recomputed live, so booking one removes it from
    /// the list immediately.
    var todaysSpecials: [TrainerSpecial] {
        let calendar = Calendar.current
        let today = Date()
        let bookedTodayByTrainer: Set<String> = Set(
            bookedSessions
                .filter { calendar.isDate($0.date, inSameDayAs: today) }
                .map { session -> String in
                    let components = calendar.dateComponents([.hour, .minute], from: session.date)
                    // bookTrainerSpecial stores the trainer's name as `title`
                    // (zone bookings store the zone's name there instead,
                    // which just won't collide with any trainer's name).
                    return "\(session.title)|\(String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0))"
                }
        )
        return trainers.flatMap { trainer -> [TrainerSpecial] in
            trainerSlots.compactMap { slot -> TrainerSpecial? in
                guard let slotDate = Self.nextOccurrence(of: slot), calendar.isDate(slotDate, inSameDayAs: today) else { return nil }
                let key = "\(trainer.name)|\(slot)"
                guard !bookedTodayByTrainer.contains(key) else { return nil }
                return TrainerSpecial(trainer: trainer, time: slot, originalPrice: Int(trainer.priceCompact) ?? 0, discountPercent: 30)
            }
        }
    }

    /// Books a discounted last-minute slot from `todaysSpecials` — same
    /// bookedSessions/Supabase/reminder path as bookZone, just titled for
    /// a trainer session instead of a zone.
    func bookTrainerSpecial(_ special: TrainerSpecial) {
        guard let date = Self.nextOccurrence(of: special.time) else { return }
        let session = BookedSession(date: date, title: special.trainer.name, trainerName: special.trainer.specialty)
        bookedSessions.append(session)
        NotificationService.scheduleSessionReminder(id: session.id, title: session.title, trainerName: session.trainerName, date: session.date)
        notificationCenter.trigger(
            icon: "tag.fill", title: "Special booked!",
            subtitle: "\(special.trainer.name) · \(special.time) · $\(special.discountedPrice)", accent: .appAccentPurple
        )
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

    // MARK: Health metrics (HealthMetricsView — see AppState+Health.swift)
    // Every field is nil until refreshHealthMetrics() runs (Apple Health
    // sync must be on, and the device must actually have that kind of
    // data) — HealthMetricsView and HealthMetricsWidget both show a plain
    // empty state per card rather than a fake number when nil.
    @Published var heartRateBPM: Int?
    @Published var todaySteps: Int?
    @Published var hydrationML: Int?
    @Published var bmi: Double?
    @Published var sleepMinutesLastNight: Int?
    @Published var bloodPressureSystolic: Int?
    @Published var bloodPressureDiastolic: Int?
    @Published var bloodGlucose: Int?
    @Published var healthMetricsUpdatedAt: Date?

    /// A photo the member uploaded (see uploadAvatarPhoto in
    /// AppState+Avatar.swift) — mutually exclusive with avatarPresetID,
    /// uploading clears the preset and vice versa. Persisted locally
    /// (UserDefaults) like DeviceUser.id, not synced server-side, so it
    /// survives relaunches on this device but not a reinstall or a
    /// different device.
    @Published var avatarImageURLString: String? {
        didSet {
            if let avatarImageURLString {
                UserDefaults.standard.set(avatarImageURLString, forKey: Self.avatarImageURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.avatarImageURLKey)
            }
        }
    }
    /// One of AvatarPresets.all's ids (see AvatarPickerView).
    @Published var avatarPresetID: String? {
        didSet {
            if let avatarPresetID {
                UserDefaults.standard.set(avatarPresetID, forKey: Self.avatarPresetIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.avatarPresetIDKey)
            }
        }
    }
    var avatarImageURL: URL? { avatarImageURLString.flatMap(URL.init) }

    private static let avatarImageURLKey = "core.avatarImageURLString"
    private static let avatarPresetIDKey = "core.avatarPresetID"

    // MARK: Dynamic Island-style notifications
    // Self-contained (owns its own overlay UIWindow) — see
    // DynamicIslandNotifier.swift. Call notificationCenter.trigger(...)
    // from anywhere; no view modifier needs to be attached.
    let notificationCenter = DynamicNotificationCenter()

    // MARK: Streaks, achievements, check-ins, referrals, leaderboard
    // (AppState+Growth.swift). Backed by the `member_stats` Supabase table
    // so the streak/visit count is shared across every device this member
    // uses, not just kept in local UserDefaults.
    @Published var streakDays: Int = 0
    @Published var referralCode: String = ""
    @Published var progressPhotos: [ProgressPhoto] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    /// Not `@Published` — internal bookkeeping for streak math only (see
    /// AppState+Growth.swift's recordActivity()), not something any view
    /// binds to directly.
    var lastActivityDate: Date?

    var achievements: [Achievement] {
        [
            Achievement(icon: "figure.run", title: "First Workout", detail: "Log your first session", isUnlocked: !workoutHistory.isEmpty),
            Achievement(icon: "flame.fill", title: "7 Day Streak", detail: "Stay active 7 days running", isUnlocked: streakDays >= 7),
            Achievement(icon: "flame.fill", title: "30 Day Streak", detail: "Stay active 30 days running", isUnlocked: streakDays >= 30),
            Achievement(icon: "checkmark.seal.fill", title: "10 Workouts", detail: "Complete 10 sessions", isUnlocked: workoutHistory.count >= 10),
            Achievement(icon: "checkmark.seal.fill", title: "50 Workouts", detail: "Complete 50 sessions", isUnlocked: workoutHistory.count >= 50),
            Achievement(icon: "star.fill", title: "100 Visits", detail: "Check in 100 times", isUnlocked: totalVisits >= 100),
        ]
    }

    /// Pushes this member's current streak/workout/achievement state to the
    /// shared App Group container and nudges WidgetKit to redraw — called
    /// after anything that could change what the Progress & Achievements
    /// Home Screen widget shows (recordActivity, initial Supabase load).
    /// The widget itself never hits the network; it just reads whatever
    /// was last written here.
    func syncProgressWidget() {
        let today = Calendar.current.startOfDay(for: Date())
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let thisWeek = workoutHistory.filter { $0.completedAt >= weekAgo }
        let snapshot = ProgressSnapshot(
            streakDays: streakDays,
            totalWorkouts: workoutHistory.count,
            unlockedAchievements: achievements.filter(\.isUnlocked).count,
            totalAchievements: achievements.count,
            weeklySets: thisWeek.reduce(0) { $0 + $1.sets },
            weeklyMinutes: thisWeek.reduce(0) { $0 + $1.minutes },
            weeklyCalories: thisWeek.reduce(0) { $0 + $1.calories },
            lastWorkoutTitle: workoutHistory.first?.title,
            updatedAt: Date()
        )
        SharedProgressStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ProgressAchievementsWidget")
    }
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
