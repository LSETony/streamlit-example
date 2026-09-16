import Foundation
import Combine
import SwiftUI

/// Single in-memory store for the whole app. Data and copy are ported from
/// the design source ("core App.dc.html") so every screen matches it
/// exactly; interactions (timers, booking, logging, chat) are real, just
/// backed by local state instead of a server.
@MainActor
final class AppState: ObservableObject {

    // MARK: Profile / Home

    @Published var userName: String = "Jarvis"
    @Published var fullName: String = "Jarvis Kitsune Jr"
    var initials: String {
        fullName.split(separator: " ").compactMap(\.first).map(String.init).joined().uppercased()
    }
    @Published var readiness: Int = 72
    @Published var streakDays: Int = 12

    // MARK: Onboarding wizard (4 steps: gender, goal, contradictions, level)

    @Published var hasCompletedOnboarding: Bool = false
    @Published var selectedGender: String?
    @Published var selectedGoal: String?
    @Published var selectedContradictions: Set<String> = []
    @Published var contradictionsNote: String = ""
    @Published var selectedLevel: String?

    // MARK: Home hero + progress card (latest Figma pass)

    @Published var clubName: String = "RC Rezindtsii Arhitektorov"
    @Published var trainingProgressPercent: Int = 67
    @Published var trainingDay: Int = 1
    @Published var trainingMinutesToday: Int = 38

    // MARK: Workout library (Beginner's Plan / Top 10 / Important)

    @Published var beginnerPlanCards: [WorkoutCard] = [
        WorkoutCard(title: "Beginner Female Aesthetics", level: "Beginner", duration: "7 day", category: "Strength", photoStyle: .trainer),
        WorkoutCard(title: "Beginner Body Weight Plan", level: "Beginner", duration: "7 day", category: "Strength", photoStyle: .gym),
    ]
    @Published var topWorkoutCards: [WorkoutCard] = [
        WorkoutCard(title: "Sam's Prenatal Flow", level: "Beginner", duration: "22 mins", category: "Strength", photoStyle: .trainer),
        WorkoutCard(title: "Chest and Triceps", level: "Inter", duration: "62 mins", category: "Strength", photoStyle: .gym),
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

    // MARK: Workout session (elapsed time, counts up like the source)

    @Published var isWorkoutInProgress: Bool = true
    @Published var workoutSeconds: Int = 1458
    @Published var recommendedWorkoutTitle: String = "Push A · heavy upper body"
    @Published var recommendedWorkoutMeta: String = "6 lifts · 52 min · sleep 7h 40m"
    @Published var currentLiftIndex: Int = 2
    @Published var currentLiftName: String = "Incline bench press"
    @Published var currentLiftNote: String = "Last time 82.5 kg × 8 · RPE 8 · target +2.5 kg"
    @Published var totalLifts: Int = 6
    @Published var nextLiftName: String = "Cable fly"
    @Published var avgHeartRate: Int = 142

    @Published var sets: [WorkoutSet] = [
        WorkoutSet(weight: 85, reps: 8, isDone: true),
        WorkoutSet(weight: 85, reps: 7, isDone: true),
        WorkoutSet(weight: 87.5, reps: 6, isDone: false),
    ]
    @Published var restSeconds: Int = 0
    private var workoutTimerCancellable: AnyCancellable?

    var workoutTimeString: String { Self.mmss(workoutSeconds) }
    var doneSetsCount: Int { sets.filter(\.isDone).count }
    var completedVolume: Int {
        Int(sets.filter(\.isDone).reduce(0) { $0 + $1.weight * Double($1.reps) })
    }

    static func mmss(_ n: Int) -> String {
        String(format: "%02d:%02d", n / 60, n % 60)
    }

    func toggleWorkout() {
        isWorkoutInProgress.toggle()
        if isWorkoutInProgress { startTimer() } else { workoutTimerCancellable?.cancel() }
    }

    func startTimer() {
        workoutTimerCancellable?.cancel()
        workoutTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isWorkoutInProgress else { return }
                self.workoutSeconds += 1
                if self.restSeconds > 0 { self.restSeconds -= 1 }
            }
    }

    func toggleSet(_ set: WorkoutSet) {
        guard let idx = sets.firstIndex(where: { $0.id == set.id }) else { return }
        sets[idx].isDone.toggle()
        if sets[idx].isDone { restSeconds = 90 }
    }

    func addSet() {
        let last = sets.last?.weight ?? 20
        sets.append(WorkoutSet(weight: last, reps: 6, isDone: false))
    }

    func startRest(_ seconds: Int) { restSeconds = seconds }

    func advanceToNextLift() {
        currentLiftIndex = min(currentLiftIndex + 1, totalLifts)
        currentLiftName = nextLiftName
        sets = [
            WorkoutSet(weight: 22.5, reps: 12, isDone: false),
            WorkoutSet(weight: 22.5, reps: 12, isDone: false),
            WorkoutSet(weight: 22.5, reps: 10, isDone: false),
        ]
        restSeconds = 0
    }

    // MARK: Club occupancy

    @Published var occupancyPercent: Int = 42
    @Published var occupancyInClub: Int = 38
    @Published var occupancyCapacity: Int = 90
    /// Bar heights 0...1 across the day; index 3 is "now" and always accented.
    @Published var occupancyBars: [Double] = [0.24, 0.18, 0.40, 0.42, 0.56, 0.74, 1.0, 0.82, 0.48, 0.30]

    // MARK: Calendar / schedule

    @Published var upcoming: [ScheduleEvent] = [
        ScheduleEvent(time: "18:30", title: "Strength 45 · Hall 2", subtitle: "Mika Orlov · 11/16 booked", kind: .trainer, status: .booked),
        ScheduleEvent(time: "17.09", title: "Body scan · diagnostics", subtitle: "Lab room · Elena V. · 20 min", kind: .reservation, status: .confirm),
    ]

    @Published var events: [ScheduleEvent] = [
        ScheduleEvent(time: "09:00", title: "Body scan · diagnostics", subtitle: "Lab room · Elena V.", kind: .trainer, status: .hold),
        ScheduleEvent(time: "18:00", title: "Strength floor reserved", subtitle: "90 min · zone booking", kind: .reservation, status: .you),
        ScheduleEvent(time: "18:30", title: "Push A · heavy upper", subtitle: "6 lifts · 52 min", kind: .workout, status: .plan),
    ]

    // MARK: Booking / zones

    @Published var bookingDates: [Int] = [13, 14, 15, 16, 17, 18, 19]
    @Published var selectedBookingDate: Int = 15
    @Published var bookingStartTimes: [String] = ["07:00", "09:00", "12:00", "14:00", "16:00", "18:00", "20:00", "21:30"]
    @Published var selectedBookingTime: String = "18:00"
    @Published var bookingDurations: [Int] = [60, 90, 120]
    @Published var selectedBookingDuration: Int = 90
    @Published var isBooked: Bool = false

    @Published var zones: [Zone] = [
        Zone(name: "Strength floor", capacity: 40, occupied: 17, icon: "figure.strengthtraining.traditional"),
        Zone(name: "Free weights", capacity: 24, occupied: 17, icon: "dumbbell.fill"),
        Zone(name: "Cardio deck", capacity: 30, occupied: 7, icon: "figure.run"),
        Zone(name: "Functional room", capacity: 16, occupied: 14, icon: "figure.cross.training"),
        Zone(name: "Recovery & sauna", capacity: 12, occupied: 4, icon: "flame.fill"),
    ]
    @Published var selectedZoneName: String = "Strength floor"
    var selectedZone: Zone? { zones.first { $0.name == selectedZoneName } }
    var bookingsLeftThisWeek: Int { max(3 - (isBooked ? 1 : 0), 0) }

    func reserve() { isBooked.toggle() }

    // MARK: Trainers

    @Published var trainers: [Trainer] = [
        Trainer(initials: "MO", name: "Mika Orlov", specialty: "Strength · powerlifting", rating: "4.9", reviews: 212, priceLabel: "₽3 500/h", priceCompact: "3.5k", nextAvailable: "Today", availabilityColor: .appSuccess, yearsExperience: "9 years", clients: 48, sessions: 1840, tags: ["Squat mechanics", "Peaking blocks", "Return to lifting"], bio: "Coaches the strength floor and writes the club's barbell progressions. Works with lifters coming back from long breaks and with members chasing a first 2× bodyweight squat."),
        Trainer(initials: "EV", name: "Elena Vasnetsova", specialty: "Diagnostics · nutrition", rating: "5.0", reviews: 168, priceLabel: "₽4 200/h", priceCompact: "4.2k", nextAvailable: "Tue", availabilityColor: .appAccent, yearsExperience: "12 years", clients: 62, sessions: 2210, tags: ["Body composition", "Blood panels", "Supplement audit"], bio: "Runs the diagnostics lab. Reads your scans and blood work, then sets the vitamin and macro protocol that the app tracks against."),
        Trainer(initials: "DK", name: "Dana Kravets", specialty: "Conditioning · cycle", rating: "4.8", reviews: 96, priceLabel: "₽2 900/h", priceCompact: "2.9k", nextAvailable: "Today", availabilityColor: .appSuccess, yearsExperience: "6 years", clients: 71, sessions: 1120, tags: ["Zone 2", "Intervals", "Race prep"], bio: "Builds aerobic base without wrecking your lifting week. Leads the cycle studio and the Sunday long-effort sessions."),
        Trainer(initials: "RS", name: "Ruslan Shirin", specialty: "Rehab · mobility", rating: "4.9", reviews: 140, priceLabel: "₽3 800/h", priceCompact: "3.8k", nextAvailable: "Thu", availabilityColor: .appTextSecondary, yearsExperience: "11 years", clients: 39, sessions: 1660, tags: ["Shoulder", "Lower back", "Post-injury"], bio: "Physio background. Takes the members the other trainers send over, and clears them to load again on a schedule you can see in the app."),
    ]
    @Published var trainerSlots: [String] = ["07:30", "11:00", "17:00", "19:30"]

    // MARK: Plan

    @Published var weekComplianceDone: Int = 3
    @Published var weekComplianceTotal: Int = 4
    @Published var planDays: [PlanDay] = [
        PlanDay(day: "Mon", name: "Push A · heavy upper", detail: "6 lifts · 52 min", isDone: true),
        PlanDay(day: "Tue", name: "Legs A · squat focus", detail: "5 lifts · 61 min", isDone: true),
        PlanDay(day: "Thu", name: "Pull B · back and arms", detail: "7 lifts · 58 min", isDone: true),
        PlanDay(day: "Sun", name: "Push A · heavy upper", detail: "6 lifts · 52 min · today", isDone: false, isToday: true),
    ]
    @Published var library: [LibraryExercise] = [
        LibraryExercise(group: "Chest", name: "Incline bench press", meta: "Barbell · 4 cues"),
        LibraryExercise(group: "Back", name: "Chest-supported row", meta: "Machine · 3 cues"),
        LibraryExercise(group: "Legs", name: "Hack squat", meta: "Machine · 5 cues"),
        LibraryExercise(group: "Shoulders", name: "Cable lateral raise", meta: "Cable · 3 cues"),
    ]
    @Published var history: [HistoryEntry] = [
        HistoryEntry(name: "Pull B · back and arms", date: "11 Sep", duration: "58 min", volume: "5.2t"),
        HistoryEntry(name: "Legs A · squat focus", date: "09 Sep", duration: "61 min", volume: "7.8t"),
        HistoryEntry(name: "Push A · heavy upper", date: "07 Sep", duration: "54 min", volume: "4.6t"),
    ]

    // MARK: Workouts (Personal / Group / Solo)

    @Published var personalSessionsLeft: Int = 3
    @Published var groupClasses: [GroupClass] = [
        GroupClass(time: "12:30", name: "Cycle 40", subtitle: "Hall 3 · Dana K. · 22 of 24", state: .waitlist),
        GroupClass(time: "17:00", name: "Functional 30", subtitle: "Studio · Dana K. · 9 of 16", state: .book),
        GroupClass(time: "18:30", name: "Strength 45", subtitle: "Hall 2 · Mika Orlov · 11 of 16", state: .booked),
        GroupClass(time: "20:00", name: "Mobility & recovery", subtitle: "Studio · full", state: .full),
    ]

    // MARK: Nutrition

    let kcalTarget: Int = 2600
    var kcalInToday: Int { meals.reduce(0) { $0 + $1.calories } }
    var kcalLeft: Int { kcalTarget - kcalInToday }

    @Published var proteinTarget: Int = 190
    @Published var carbsCurrent: Int = 186
    @Published var carbsTarget: Int = 280
    @Published var fatCurrent: Int = 52
    @Published var fatTarget: Int = 78
    var proteinCurrent: Int { meals.reduce(0) { $0 + $1.protein } }

    @Published var waterGlassesFilled: Int = 5
    let waterGlassesTotal: Int = 8
    var waterLiters: Double { Double(waterGlassesFilled) * 0.25 }

    func addWater() { waterGlassesFilled = min(waterGlassesFilled + 1, waterGlassesTotal) }
    func removeWater() { waterGlassesFilled = max(waterGlassesFilled - 1, 0) }

    @Published var meals: [MealEntry] = [
        MealEntry(time: "08:10", name: "Oats, whey, berries", calories: 520, protein: 38),
        MealEntry(time: "13:40", name: "Chicken, rice, greens", calories: 710, protein: 52),
        MealEntry(time: "16:20", name: "Casein shake", calories: 180, protein: 26),
    ]

    func addMeal() {
        meals.append(MealEntry(time: "19:05", name: "Cottage cheese, honey", calories: 320, protein: 34))
    }
    func removeMeal(_ meal: MealEntry) {
        meals.removeAll { $0.id == meal.id }
    }

    // MARK: Diagnostics / Body

    @Published var weightHistory: [BodyMetricPoint] = [
        BodyMetricPoint(label: "Mar", value: 31.4),
        BodyMetricPoint(label: "May", value: 32.0),
        BodyMetricPoint(label: "Jul", value: 33.1),
        BodyMetricPoint(label: "Sep", value: 34.2),
    ]
    @Published var muscleMassGainKg: Double = 1.4

    @Published var bodyMetrics: [BodyMetric] = [
        BodyMetric(name: "Body fat", value: "14.8%", note: "Down from 16.1% in July"),
        BodyMetric(name: "Total body water", value: "58.1%", note: "In range"),
        BodyMetric(name: "Visceral fat index", value: "4", note: "Healthy band is 1–9"),
        BodyMetric(name: "Basal metabolic rate", value: "1 812", note: "kcal at rest"),
    ]

    @Published var labResults: [LabResult] = [
        LabResult(name: "Ferritin", value: "28", range: "30–400 ng/ml", flag: "Low", level: .warn),
        LabResult(name: "Vitamin D (25-OH)", value: "31", range: "30–100 ng/ml", flag: "Low-normal", level: .warn),
        LabResult(name: "Testosterone, total", value: "19.4", range: "8.6–29 nmol/l", flag: "In range", level: .ok),
        LabResult(name: "Creatine kinase", value: "284", range: "30–200 U/l", flag: "High · training", level: .warn),
        LabResult(name: "HbA1c", value: "5.1", range: "4.0–5.6 %", flag: "In range", level: .ok),
        LabResult(name: "Magnesium", value: "0.91", range: "0.75–0.95 mmol/l", flag: "In range", level: .ok),
    ]
    var flaggedLabs: [LabResult] { labResults.filter { $0.level == .warn } }
    var okLabs: [LabResult] { labResults.filter { $0.level == .ok } }

    @Published var vitamins: [VitaminItem] = [
        VitaminItem(symbol: "D3", name: "Vitamin D3 + K2", dosage: "4 000 IU · with breakfast", status: .taken),
        VitaminItem(symbol: "Fe", name: "Iron bisglycinate", dosage: "25 mg · evening, away from tea", status: .due),
        VitaminItem(symbol: "Mg", name: "Magnesium glycinate", dosage: "400 mg · before sleep", status: .due),
        VitaminItem(symbol: "w3", name: "Omega-3 EPA/DHA", dosage: "2 g · with any meal", status: .taken),
    ]
    var vitaminsTakenLabel: String { "\(vitamins.filter { $0.status == .taken }.count) of \(vitamins.count) taken" }

    func toggleVitamin(_ item: VitaminItem) {
        guard let idx = vitamins.firstIndex(where: { $0.id == item.id }) else { return }
        vitamins[idx].status = vitamins[idx].status == .taken ? .due : .taken
    }

    @Published var lastScanDate: String = "02 SEP"
    @Published var nextScanDate: String = "17 SEP"

    // MARK: Store / Vitamins catalog

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
                benefits: "Adds a few reps at a given load and roughly 1–2 kg of water inside the muscle. Elena flagged it for your next block.",
                risks: "Safe in healthy adults at 3–5 g. Drink enough water; kidney disease is the one contraindication.",
                interactions: "No meaningful drug interactions. Caffeine does not cancel it, despite the old claim."),
        Product(abbr: "Zn", name: "Zinc picolinate", form: "Capsule", dose: "15 mg", count: "100 capsules", price: 35, subscriptionPrice: 30, tag: "Watch dose", tagColor: .appWarning,
                desc: "A 15 mg dose, deliberately lower than the 50 mg tubs sold elsewhere.",
                ingredients: [Ingredient(name: "Zinc (picolinate)", amount: "15 mg"), Ingredient(name: "Copper (gluconate)", amount: "1 mg")],
                benefits: "Covers a genuine gap in low-meat diets and supports immune function.",
                risks: "Above 40 mg daily for months depletes copper and can cause anaemia.",
                interactions: "Competes with your iron — four hours apart. Also reduces absorption of some antibiotics."),
        Product(abbr: "Mg", name: "Magnesium", form: "Capsule", dose: "400 mg", count: "120 capsules", price: 85, subscriptionPrice: 72, tag: "In protocol", tagColor: .appAccent,
                desc: "The sleep-and-recovery magnesium. Glycinate is well absorbed and does not act as a laxative at this dose.",
                ingredients: [Ingredient(name: "Magnesium (glycinate)", amount: "400 mg"), Ingredient(name: "Glycine", amount: "1 200 mg")],
                benefits: "Shortens time to sleep and reduces cramping in heavy training weeks.",
                risks: "Loose stools above 600 mg. Anyone with reduced kidney function should ask a doctor first.",
                interactions: "Blunts absorption of tetracycline and quinolone antibiotics, and of bisphosphonates. Separate by two hours."),
        Product(abbr: "D3K2", name: "Vitamin D3 4000 + K2", form: "Softgel", dose: "4 000 IU", count: "120 softgels", price: 42, subscriptionPrice: 36, tag: "In protocol", tagColor: .appAccent,
                desc: "The club's baseline for the dark half of the year. D3 with MK-7 so calcium is directed to bone rather than soft tissue.",
                ingredients: [Ingredient(name: "Vitamin D3 (cholecalciferol)", amount: "4 000 IU"), Ingredient(name: "Vitamin K2 (MK-7)", amount: "100 mcg"), Ingredient(name: "MCT oil", amount: "250 mg")],
                benefits: "Supports bone density, immune response and testosterone in deficient men. Your 02 Sep level was 31 ng/ml, at the bottom of range.",
                risks: "Do not exceed 10 000 IU daily without a blood test. Excess builds up and raises blood calcium.",
                interactions: "K2 interferes with warfarin and other vitamin-K antagonists. Thiazide diuretics increase calcium retention."),
        Product(abbr: "Fe", name: "Iron bisglycinate 25", form: "Capsule", dose: "25 mg", count: "90 capsules", price: 39, subscriptionPrice: 33, tag: "In protocol", tagColor: .appAccent,
                desc: "Chelated iron, chosen because it is gentler on the stomach than sulphate at the same absorbed dose.",
                ingredients: [Ingredient(name: "Iron (bisglycinate chelate)", amount: "25 mg"), Ingredient(name: "Vitamin C", amount: "80 mg"), Ingredient(name: "Folate", amount: "200 mcg")],
                benefits: "Rebuilds ferritin, which sat at 28 ng/ml on your last panel. Low ferritin shows up as flat endurance and poor recovery.",
                risks: "Iron is the most common cause of supplement poisoning in children — keep it locked away. May darken stools.",
                interactions: "Take four hours apart from zinc, calcium, coffee and black tea. Reduces absorption of levothyroxine and some antibiotics."),
        Product(abbr: "w3", name: "Omega-3 EPA/DHA 2g", form: "Softgel", dose: "2 g", count: "180 softgels", price: 58, subscriptionPrice: 49, tag: "Popular", tagColor: .appTextSecondary,
                desc: "Triglyceride-form fish oil, IFOS tested for oxidation. Kept in the club fridge, not on a shelf.",
                ingredients: [Ingredient(name: "EPA", amount: "1 200 mg"), Ingredient(name: "DHA", amount: "800 mg"), Ingredient(name: "Vitamin E", amount: "10 mg")],
                benefits: "Lowers triglycerides and helps joint comfort through heavy blocks.",
                risks: "Mild reflux or a fishy aftertaste. Stop two weeks before surgery.",
                interactions: "Adds to the effect of anticoagulants such as warfarin, apixaban or aspirin — tell your doctor."),
    ]
    @Published var isSubscribed: Bool = false
    @Published var cart: [CartLine] = []

    var cartCount: Int { cart.count }
    var cartTotal: Int { cart.reduce(0) { $0 + $1.price } }

    func addToCart(_ product: Product) {
        cart.append(CartLine(name: product.name, price: product.price))
    }
    func addBundle() {
        cart.append(contentsOf: [
            CartLine(name: "Iron bisglycinate 25", price: 39),
            CartLine(name: "Vitamin D3 4000 + K2", price: 42),
            CartLine(name: "Magnesium", price: 85),
        ])
    }
    func removeFromCart(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
    }
    func clearCart() { cart.removeAll() }

    // MARK: Scanner

    @Published var lastScanFlag: String = "Two flags against your protocol"
    @Published var lastScanDetail: String = "50 mg daily is above the 40 mg upper limit and can suppress copper absorption over months. It also competes with the iron bisglycinate Elena prescribed — separate them by four hours or drop to 15 mg."

    // MARK: AI Assistant

    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(isUser: false, text: "Morning. Readiness is 72 and the club is quiet until 16:00. Want me to move Push A earlier?")
    ]

    func sendChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(ChatMessage(isUser: true, text: trimmed))
        let reply = Self.scriptedReplies[trimmed] ?? "Noted. Against your 02 Sep panel and this week's volume, I would keep the current protocol and revisit after the 17 Sep scan — ask Elena if you want it changed sooner."
        chatMessages.append(ChatMessage(isUser: false, text: reply))
    }

    static let suggestedQuestions: [String] = [
        "Is 50 mg zinc too much?",
        "Move Push A earlier?",
        "Why is my ferritin low?",
    ]
    static let scriptedReplies: [String: String] = [
        "Is 50 mg zinc too much?": "Yes, for daily use. The upper limit is 40 mg and you already get zinc in the club bundle. Drop to 15 mg and keep it four hours away from your iron.",
        "Move Push A earlier?": "The strength floor sits at 23% until 16:00. Moving Push A to 14:00 gets you a free rack and keeps 5 hours before your 20:00 casein shake.",
        "Why is my ferritin low?": "Ferritin at 28 ng/ml with your training volume usually means intake, not loss. Your protein is fine but red meat is twice a month — the 25 mg bisglycinate covers the gap in about 8 weeks.",
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
    @Published var isCheckedIn: Bool = false

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

    func confirmCheckIn() {
        isCheckedIn.toggle()
        if isCheckedIn {
            visits.insert(Visit(date: "Today", zone: "Strength floor", timeRange: "just now"), at: 0)
        }
    }

    // MARK: Profile

    @Published var memberSince: String = "March 2023"
    @Published var totalVisits: Int = 128
    @Published var septemberVisits: Int = 18
    @Published var scansThisMonth: Int = 6
    @Published var ptSessionsLeft: Int = 3
    @Published var appleHealthSyncEnabled: Bool = true
    @Published var membershipPlanName: String = "Unlimited 24/7"
    @Published var membershipRenewDate: String = "12 Mar 2027"
    @Published var membershipMonthlyPrice: Int = 7900

    let settingsRows: [SettingsRowItem] = [
        SettingsRowItem(name: "Notifications", subtitle: "Class reminders, protocol nudges, restock"),
        SettingsRowItem(name: "Payments", subtitle: "Card ·· 4417 · invoices"),
        SettingsRowItem(name: "Diagnostics history", subtitle: "6 reports since Mar 2023", destination: .diagnostics),
        SettingsRowItem(name: "Vitamin subscription", subtitle: "Monthly box · ships 28 Sep", destination: .store),
        SettingsRowItem(name: "Accessibility", subtitle: "Larger text, reduce motion, VoiceOver"),
    ]
}

struct MealEntry: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let calories: Int
    let protein: Int
}

struct CartLine: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
}
