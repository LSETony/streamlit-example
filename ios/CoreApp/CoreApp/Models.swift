import SwiftUI

// MARK: - Trainers

struct Trainer: Identifiable {
    let id = UUID()
    let imageName: String
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

// MARK: - Workout library / Food recipes

struct WorkoutCard: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let level: String
    let duration: String
    let category: String
    let exercises: [Exercise]
}

/// One movement inside a WorkoutCard's plan, shown in its detail screen and
/// stepped through during an active session.
struct Exercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let sets: Int
    let reps: String
}

struct ImportantCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct FoodRecipe: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
    let ingredients: [String]
}

// MARK: - Workout progress history (behind Home's "Your Progress" card)

struct WorkoutHistoryEntry: Identifiable {
    let id = UUID()
    let date: String
    let title: String
    let sets: Int
    let minutes: Int
    let calories: Int
}

/// One point on the Progress screen's muscle-mass growth chart.
struct MuscleMassEntry: Identifiable {
    let id = UUID()
    let label: String
    let kg: Double
}

// MARK: - Club subscriptions (behind Home's wallet icon)

struct SubscriptionPlan: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
    let period: String
    let perks: [String]
    let recommended: Bool
}

// MARK: - Calendar tab bookings

struct BookedSession: Identifiable {
    let id = UUID()
    var date: Date
    let title: String
    let trainerName: String
}

// MARK: - Zone booking (behind Home's "Book" tile)

/// A bookable area of the club floor — Pilates studio, running track,
/// free weights, etc. Booking a slot adds a BookedSession, so it shows
/// up alongside trainer sessions in the Calendar tab.
struct GymZone: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let subtitle: String
    let capacity: Int
}
