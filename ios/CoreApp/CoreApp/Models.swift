import SwiftUI

// MARK: - Booking

struct Zone: Identifiable {
    let id = UUID()
    let name: String
    let capacity: Int
    var occupied: Int
    let icon: String

    var freeSpots: Int { max(capacity - occupied, 0) }
    var occupancyPercent: Int {
        guard capacity > 0 else { return 0 }
        return Int((Double(occupied) / Double(capacity) * 100).rounded())
    }
    var statusColor: Color {
        switch occupancyPercent {
        case ...55: return .appSuccess
        case 56...80: return .appAccent
        default: return .appWarning
        }
    }
}

// MARK: - Calendar / Plan

enum EventKind: String {
    case workout = "Workout"
    case trainer = "Trainer"
    case reservation = "Reservation"

    var color: Color {
        switch self {
        case .workout: return .appAccent
        case .trainer: return .appSuccess
        case .reservation: return .appTextSecondary
        }
    }
}

enum EventStatus: String {
    case booked = "BOOKED"
    case confirm = "CONFIRM"
    case hold = "HOLD"
    case you = "YOU"
    case plan = "PLAN"

    var color: Color {
        switch self {
        case .booked: return .appTextSecondary
        case .confirm: return .appAccent
        case .hold: return .appTextSecondary
        case .you: return .appTextSecondary
        case .plan: return .appAccent
        }
    }
}

struct ScheduleEvent: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let subtitle: String
    let kind: EventKind
    var status: EventStatus
}

struct PlanDay: Identifiable {
    let id = UUID()
    let day: String
    let name: String
    let detail: String
    var isDone: Bool
    var isToday: Bool = false
}

struct LibraryExercise: Identifiable {
    let id = UUID()
    let group: String
    let name: String
    let meta: String
}

struct HistoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let date: String
    let duration: String
    let volume: String
}

// MARK: - Trainers

struct Trainer: Identifiable {
    let id = UUID()
    let initials: String
    let name: String
    let specialty: String
    let rating: String
    let reviews: Int
    let priceLabel: String
    let priceCompact: String
    let nextAvailable: String
    let availabilityColor: Color
    let yearsExperience: String
    let clients: Int
    let sessions: Int
    let tags: [String]
    let bio: String
}

// MARK: - Workout

struct WorkoutSet: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var isDone: Bool
}

enum ClassBookingState {
    case book, booked, waitlist, full
}

struct GroupClass: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let subtitle: String
    let state: ClassBookingState
}

// MARK: - Diagnostics / Vitamins

enum VitaminStatus: String {
    case taken = "TAKEN"
    case due = "DUE"

    var color: Color {
        switch self {
        case .taken: return .appSuccess
        case .due: return .appAccent
        }
    }
}

struct VitaminItem: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let dosage: String
    var status: VitaminStatus
}

struct BodyMetricPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct BodyMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let note: String
}

enum LabFlagLevel {
    case ok, warn
}

struct LabResult: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let range: String
    let flag: String
    let level: LabFlagLevel

    var color: Color { level == .warn ? .appWarning : .appSuccess }
}

// MARK: - Store

struct Ingredient: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
}

struct Product: Identifiable {
    let id = UUID()
    let abbr: String
    let name: String
    let form: String
    let dose: String
    let count: String
    let price: Int
    let subscriptionPrice: Int
    let tag: String
    let tagColor: Color
    let desc: String
    let ingredients: [Ingredient]
    let benefits: String
    let risks: String
    let interactions: String
}

// MARK: - QR Pass

struct Visit: Identifiable {
    let id = UUID()
    let date: String
    let zone: String
    let timeRange: String
}

// MARK: - AI Assistant

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

// MARK: - Profile settings

enum SettingsDestination {
    case none, diagnostics, store
}

struct SettingsRowItem: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    var destination: SettingsDestination = .none
}

// MARK: - Workout library / Food recipes

struct WorkoutCard: Identifiable {
    let id = UUID()
    let title: String
    let level: String
    let duration: String
    let category: String
    let photoStyle: PhotoPlaceholder.Style
}

struct ImportantCard: Identifiable {
    let id = UUID()
    let title: String
}

struct FoodRecipe: Identifiable {
    let id = UUID()
    let name: String
}
