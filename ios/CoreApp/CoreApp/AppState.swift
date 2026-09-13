import Foundation
import Combine
import SwiftUI

/// Single in-memory store for the whole app. Everything here is local,
/// mock data meant to demonstrate fully working interactions (timers,
/// booking, logging, chat) without requiring a backend.
@MainActor
final class AppState: ObservableObject {

    // MARK: Profile / Home

    @Published var userName: String = "Artem"
    @Published var readiness: Int = 72
    @Published var sleepHours: Double = 7.67

    // MARK: Workout session

    @Published var isWorkoutInProgress: Bool = true
    @Published var workoutSecondsRemaining: Int = 24 * 60 + 21
    @Published var recommendedWorkoutTitle: String = "Push A · heavy upper body"
    @Published var recommendedWorkoutMeta: String = "6 lifts · 52 min · sleep 7h 40m"
    @Published var lifts: [WorkoutLift] = [
        WorkoutLift(name: "Barbell bench press", sets: 4, reps: "6-8"),
        WorkoutLift(name: "Incline dumbbell press", sets: 3, reps: "8-10"),
        WorkoutLift(name: "Weighted dips", sets: 3, reps: "10-12"),
        WorkoutLift(name: "Overhead press", sets: 4, reps: "6-8"),
        WorkoutLift(name: "Lateral raise", sets: 3, reps: "12-15"),
        WorkoutLift(name: "Triceps pushdown", sets: 3, reps: "12-15"),
    ]

    var workoutTimeString: String {
        let m = workoutSecondsRemaining / 60
        let s = workoutSecondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var timerCancellable: AnyCancellable?

    func toggleWorkout() {
        isWorkoutInProgress.toggle()
        if isWorkoutInProgress {
            startTimer()
        } else {
            timerCancellable?.cancel()
        }
    }

    func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.isWorkoutInProgress else { return }
                if self.workoutSecondsRemaining > 0 {
                    self.workoutSecondsRemaining -= 1
                } else {
                    self.isWorkoutInProgress = false
                    self.timerCancellable?.cancel()
                }
            }
    }

    func toggleLift(_ lift: WorkoutLift) {
        guard let idx = lifts.firstIndex(where: { $0.id == lift.id }) else { return }
        lifts[idx].isDone.toggle()
    }

    // MARK: Club occupancy

    @Published var occupancyPercent: Int = 42
    @Published var occupancyByHour: [(hour: Int, value: Double)] = [
        (6, 0.10), (10, 0.22), (14, 0.55), (18, 0.95), (22, 0.30)
    ]

    // MARK: Quick stats

    @Published var kcalInToday: Int = 1846

    // MARK: Calendar / schedule

    @Published var events: [ScheduleEvent] = [
        ScheduleEvent(time: "09:00", title: "Body scan · diagnostics", subtitle: "Lab room · Elena V.", kind: .trainer, status: .hold),
        ScheduleEvent(time: "18:00", title: "Strength floor reserved", subtitle: "90 min · zone booking", kind: .reservation, status: .you),
        ScheduleEvent(time: "18:30", title: "Push A · heavy upper", subtitle: "6 lifts · 52 min", kind: .workout, status: .plan),
    ]

    // MARK: Booking / zones

    @Published var zones: [Zone] = [
        Zone(name: "Strength floor", capacity: 40, occupied: 17, icon: "figure.strengthtraining.traditional"),
        Zone(name: "Free weights", capacity: 24, occupied: 17, icon: "dumbbell.fill"),
        Zone(name: "Cardio deck", capacity: 30, occupied: 7, icon: "figure.run"),
        Zone(name: "Functional room", capacity: 16, occupied: 14, icon: "figure.cross.training"),
        Zone(name: "Recovery & sauna", capacity: 12, occupied: 4, icon: "flame.fill"),
    ]

    @Published var lastBookedZoneName: String?

    func reserve(_ zone: Zone) {
        lastBookedZoneName = zone.name
        if let idx = zones.firstIndex(where: { $0.id == zone.id }), zones[idx].occupied < zones[idx].capacity {
            zones[idx].occupied += 1
        }
    }

    // MARK: Trainers

    @Published var trainers: [Trainer] = [
        Trainer(name: "Mika Orlov", initials: "MO", specialty: "Strength · powerlifting", rating: 4.9, reviews: 212, pricePerHour: 3500, nextAvailable: "MON", avatarColor: .appAccent),
        Trainer(name: "Elena Vasnetsova", initials: "EV", specialty: "Diagnostics · nutrition", rating: 5.0, reviews: 168, pricePerHour: 4200, nextAvailable: "TUE", avatarColor: .appSuccess),
        Trainer(name: "Dana Kravets", initials: "DK", specialty: "Conditioning · cycle", rating: 4.8, reviews: 96, pricePerHour: 2900, nextAvailable: "TODAY", avatarColor: .appWarning, isTodayAvailable: true),
        Trainer(name: "Ruslan Shirin", initials: "RS", specialty: "Rehab · mobility", rating: 4.9, reviews: 140, pricePerHour: 3800, nextAvailable: "THU", avatarColor: .white),
    ]

    // MARK: Nutrition

    @Published var proteinCurrent: Int = 116
    @Published var proteinTarget: Int = 190
    @Published var carbsCurrent: Int = 186
    @Published var carbsTarget: Int = 280
    @Published var fatCurrent: Int = 52
    @Published var fatTarget: Int = 78

    @Published var waterGlassesFilled: Int = 5
    let waterGlassesTotal: Int = 8
    let waterPerGlassLiters: Double = 0.25
    var waterLiters: Double { Double(waterGlassesFilled) * waterPerGlassLiters }

    func addWater() { waterGlassesFilled = min(waterGlassesFilled + 1, waterGlassesTotal) }
    func removeWater() { waterGlassesFilled = max(waterGlassesFilled - 1, 0) }

    @Published var meals: [Meal] = [
        Meal(time: "08:10", name: "Oats, whey, berries", subtitle: "38 g protein", calories: 520),
        Meal(time: "13:40", name: "Chicken, rice, greens", subtitle: "52 g protein", calories: 710),
        Meal(time: "16:20", name: "Casein shake", subtitle: "26 g protein", calories: 180),
    ]

    func addMeal(name: String, subtitle: String, calories: Int) {
        let time = Self.timeFormatter.string(from: Date())
        meals.append(Meal(time: time, name: name, subtitle: subtitle, calories: calories))
        kcalInToday += calories
    }

    func removeMeal(_ meal: Meal) {
        meals.removeAll { $0.id == meal.id }
        kcalInToday = max(kcalInToday - meal.calories, 0)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: Diagnostics / Body

    @Published var weightHistory: [BodyMetricPoint] = [
        BodyMetricPoint(label: "Mar", value: 31.4),
        BodyMetricPoint(label: "May", value: 32.0),
        BodyMetricPoint(label: "Jul", value: 33.1),
        BodyMetricPoint(label: "Sep", value: 34.2),
    ]
    @Published var bodyFatPercent: Double = 14.8
    @Published var bodyFatNote: String = "Down from 16.1% in July"
    @Published var totalBodyWaterPercent: Double = 58.1
    @Published var visceralFatIndex: Int = 4
    @Published var basalMetabolicRate: Int = 1812

    @Published var vitamins: [VitaminItem] = [
        VitaminItem(symbol: "D3", name: "Vitamin D3 + K2", dosage: "4 000 IU · with breakfast", status: .taken),
        VitaminItem(symbol: "Fe", name: "Iron bisglycinate", dosage: "25 mg · evening, away from tea", status: .due),
        VitaminItem(symbol: "Mg", name: "Magnesium glycinate", dosage: "400 mg · before sleep", status: .due),
        VitaminItem(symbol: "w3", name: "Omega-3 EPA/DHA", dosage: "2 g · with any meal", status: .taken),
    ]

    func toggleVitamin(_ item: VitaminItem) {
        guard let idx = vitamins.firstIndex(where: { $0.id == item.id }) else { return }
        vitamins[idx].status = vitamins[idx].status == .taken ? .due : .taken
    }

    @Published var lastScanDate: String = "02 SEP"
    @Published var nextScanDate: String = "17 SEP"

    // MARK: Store

    @Published var products: [Product] = [
        Product(code: "D3K2", name: "Vitamin D3 4000 + K2", price: 1290),
        Product(code: "Fe", name: "Iron bisglycinate 25", price: 980),
        Product(code: "Mg", name: "Magnesium glycinate", price: 1150),
        Product(code: "w3", name: "Omega-3 EPA/DHA 2g", price: 1760),
        Product(code: "Cr", name: "Creatine monohydrate", price: 1450),
        Product(code: "Zn", name: "Zinc picolinate 15", price: 890),
    ]
    @Published var isSubscribed: Bool = true

    var cartCount: Int { products.reduce(0) { $0 + $1.inCart } }
    var cartTotal: Int { products.reduce(0) { $0 + $1.inCart * $1.price } }

    func addToCart(_ product: Product) {
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[idx].inCart += 1
    }

    // MARK: AI Assistant

    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(isUser: false, text: "Hey Artem — ask me anything about your training, food or supplements.")
    ]

    func sendChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(ChatMessage(isUser: true, text: trimmed))
        let reply = Self.scriptedReply(for: trimmed, state: self)
        chatMessages.append(ChatMessage(isUser: false, text: reply))
    }

    private static func scriptedReply(for question: String, state: AppState) -> String {
        let q = question.lowercased()
        if q.contains("zinc") {
            return "50 mg of zinc is above the 40 mg tolerable upper limit for adults — your current plan uses 15 mg, which is a safer daily dose."
        } else if q.contains("push a") || q.contains("earlier") {
            return "You can move Push A to earlier in the day — your readiness score is highest before 11:00 based on recent sleep."
        } else if q.contains("ferritin") {
            return "Low ferritin is often linked to iron intake and training volume. You're already taking iron bisglycinate — keep it away from tea or coffee to improve absorption."
        } else if q.contains("protein") {
            return "You're at \(state.proteinCurrent)g of your \(state.proteinTarget)g protein target today — about \(state.proteinTarget - state.proteinCurrent)g under. A casein shake before bed would close most of that gap."
        } else {
            return "Got it — I'll factor that into your plan. Anything else about training, nutrition or supplements?"
        }
    }

    static let suggestedQuestions: [String] = [
        "Is 50 mg zinc too much?",
        "Move Push A earlier?",
        "Why is my ferritin low?",
    ]

    // MARK: QR Pass

    @Published var qrPayload: String = ""
    @Published var qrSecondsRemaining: Int = 30
    private var qrTimerCancellable: AnyCancellable?

    @Published var visits: [Visit] = [
        Visit(date: "11 Sep", zone: "Strength floor", timeRange: "18:22–19:40"),
        Visit(date: "09 Sep", zone: "Strength floor", timeRange: "07:05–08:31"),
        Visit(date: "07 Sep", zone: "Recovery", timeRange: "20:10–20:55"),
    ]

    var memberCode: String { "AK · 4417 · 0912" }

    func startQRRotation() {
        regenerateQR()
        qrTimerCancellable?.cancel()
        qrTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.qrSecondsRemaining > 0 {
                    self.qrSecondsRemaining -= 1
                } else {
                    self.regenerateQR()
                }
            }
    }

    private func regenerateQR() {
        qrSecondsRemaining = 30
        let token = UUID().uuidString.prefix(12)
        qrPayload = "CORECLUB:AK4417:\(token):\(Int(Date().timeIntervalSince1970))"
    }

    @Published var lastCheckIn: String?
    func confirmCheckIn() {
        lastCheckIn = "Checked in just now"
        visits.insert(Visit(date: "Today", zone: "Strength floor", timeRange: "just now"), at: 0)
    }

    // MARK: Progress

    @Published var streakDateLabel: String = "Wed 3 Oct"
    @Published var streakDays: [StreakDay] = [
        StreakDay(letter: "S", number: 1, state: .completed),
        StreakDay(letter: "M", number: 2, state: .completed),
        StreakDay(letter: "T", number: 3, state: .today),
        StreakDay(letter: "W", number: 4, state: .upcoming),
        StreakDay(letter: "T", number: 5, state: .upcoming),
        StreakDay(letter: "F", number: 6, state: .upcoming),
        StreakDay(letter: "S", number: 7, state: .upcoming),
    ]
    @Published var volumePercentOfGoal: Int = 54
    @Published var totalSets: Int = 802
    @Published var exerciseMinutesThisMonth: Int = 54
    @Published var weeklyVolumeBars: [(day: String, value: Double, isToday: Bool)] = [
        ("S", 0.55, false), ("M", 0.35, false), ("T", 0.85, false), ("W", 0.6, false),
        ("T", 1.0, true), ("F", 0.5, false), ("S", 0.7, false),
    ]

    // MARK: Profile

    @Published var septemberVisits: Int = 18
    @Published var scansThisMonth: Int = 6
    @Published var ptSessionsLeft: Int = 3
    @Published var appleHealthSyncEnabled: Bool = true
    @Published var membershipRenewDate: String = "12 Mar 2027"
    @Published var membershipMonthlyPrice: Int = 7900
}
