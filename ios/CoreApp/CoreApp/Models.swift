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
        case ..<40: return .appSuccess
        case 40..<75: return .appWarning
        default: return .appAccent
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
        case .reservation: return .white
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
        case .hold: return .appTextTertiary
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
    var dayOffset: Int = 0 // days from "today" in the demo calendar
}

// MARK: - Trainers

struct Trainer: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let specialty: String
    let rating: Double
    let reviews: Int
    let pricePerHour: Int
    let nextAvailable: String
    let avatarColor: Color
    var isTodayAvailable: Bool = false
}

// MARK: - Workout

struct WorkoutLift: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String
    var isDone: Bool = false
}

// MARK: - Nutrition

struct Meal: Identifiable {
    let id = UUID()
    let time: String
    let name: String
    let subtitle: String
    let calories: Int
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

// MARK: - Store

struct Product: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let price: Int
    var inCart: Int = 0
}

// MARK: - QR Pass

struct Visit: Identifiable {
    let id = UUID()
    let date: String
    let zone: String
    let timeRange: String
}

// MARK: - Progress

enum StreakDayState {
    case completed, today, upcoming
}

struct StreakDay: Identifiable {
    let id = UUID()
    let letter: String
    let number: Int
    let state: StreakDayState
}

// MARK: - AI Assistant

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}
