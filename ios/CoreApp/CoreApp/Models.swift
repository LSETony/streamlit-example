import SwiftUI

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
