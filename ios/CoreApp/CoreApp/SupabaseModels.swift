import Foundation
import SwiftUI

/// Row types decoded straight from Supabase (snake_case columns) plus
/// `toModel()` conversions into the app's existing UI models (Models.swift)
/// — kept separate so none of the ~15 views that already consume Trainer,
/// Product, WorkoutCard etc. needed to change.

// MARK: - Color tokens

/// Trainer.availabilityColor / Product.tagColor are stored as a short
/// token ("success" | "warning" | "accent") since Color itself isn't
/// something Postgres can hold.
extension Color {
    static func fromToken(_ token: String) -> Color {
        switch token {
        case "success": return .appSuccess
        case "warning": return .appWarning
        default: return .appAccent
        }
    }

    var token: String {
        switch self {
        case .appSuccess: return "success"
        case .appWarning: return "warning"
        default: return "accent"
        }
    }
}

// MARK: - Trainers

struct TrainerRow: Decodable {
    let imageName: String
    let name: String
    let specialty: String
    let rating: String
    let reviews: Int
    let priceLabel: String
    let priceCompact: String
    let nextAvailable: String
    let availabilityColor: String
    let yearsExperience: String
    let clients: Int
    let sessions: Int
    let tags: [String]
    let bio: String

    enum CodingKeys: String, CodingKey {
        case imageName = "image_name"
        case name, specialty, rating, reviews
        case priceLabel = "price_label"
        case priceCompact = "price_compact"
        case nextAvailable = "next_available"
        case availabilityColor = "availability_color"
        case yearsExperience = "years_experience"
        case clients, sessions, tags, bio
    }

    func toModel() -> Trainer {
        Trainer(
            imageName: imageName, name: name, specialty: specialty, rating: rating, reviews: reviews,
            priceLabel: priceLabel, priceCompact: priceCompact, nextAvailable: nextAvailable,
            availabilityColor: .fromToken(availabilityColor), yearsExperience: yearsExperience,
            clients: clients, sessions: sessions, tags: tags, bio: bio
        )
    }
}

// MARK: - Store / Supplements

struct ProductIngredientRow: Decodable {
    let name: String
    let amount: String
}

struct ProductRow: Decodable {
    let abbr: String
    let name: String
    let form: String
    let dose: String
    let count: String
    let price: Int
    let subscriptionPrice: Int
    let tag: String
    let tagColor: String
    let description: String
    let benefits: String
    let risks: String
    let interactions: String
    let productIngredients: [ProductIngredientRow]

    enum CodingKeys: String, CodingKey {
        case abbr, name, form, dose, count, price
        case subscriptionPrice = "subscription_price"
        case tag
        case tagColor = "tag_color"
        case description, benefits, risks, interactions
        case productIngredients = "product_ingredients"
    }

    func toModel() -> Product {
        Product(
            abbr: abbr, name: name, form: form, dose: dose, count: count, price: price,
            subscriptionPrice: subscriptionPrice, tag: tag, tagColor: .fromToken(tagColor),
            desc: description,
            ingredients: productIngredients.map { Ingredient(name: $0.name, amount: $0.amount) },
            benefits: benefits, risks: risks, interactions: interactions
        )
    }
}

// MARK: - Workout library

struct ExerciseRow: Decodable {
    let name: String
    let icon: String
    let sets: Int
    let reps: String
}

struct WorkoutCardRow: Decodable {
    let section: String
    let imageName: String
    let title: String
    let level: String
    let duration: String
    let category: String
    let exercises: [ExerciseRow]
    /// Real media uploaded to Supabase Storage — nil for cards still using
    /// a bundled asset (imageName).
    let imageURLString: String?
    let videoURLString: String?

    enum CodingKeys: String, CodingKey {
        case section
        case imageName = "image_name"
        case title, level, duration, category, exercises
        case imageURLString = "image_url"
        case videoURLString = "video_url"
    }

    func toModel() -> WorkoutCard {
        WorkoutCard(
            imageName: imageName, title: title, level: level, duration: duration, category: category,
            exercises: exercises.map { Exercise(name: $0.name, icon: $0.icon, sets: $0.sets, reps: $0.reps) },
            imageURL: imageURLString.flatMap(URL.init(string:)),
            videoURL: videoURLString.flatMap(URL.init(string:))
        )
    }
}

struct ImportantCardRow: Decodable {
    let icon: String
    let title: String
    let subtitle: String

    func toModel() -> ImportantCard { ImportantCard(icon: icon, title: title, subtitle: subtitle) }
}

// MARK: - Food recipes

struct FoodRecipeRow: Decodable {
    let name: String
    let price: Int
    let ingredients: [String]

    func toModel() -> FoodRecipe { FoodRecipe(name: name, price: price, ingredients: ingredients) }
}

// MARK: - Gym zones

struct GymZoneRow: Decodable {
    let icon: String
    let name: String
    let subtitle: String
    let capacity: Int

    func toModel() -> GymZone { GymZone(icon: icon, name: name, subtitle: subtitle, capacity: capacity) }
}

// MARK: - Subscriptions

struct SubscriptionPlanRow: Decodable {
    let name: String
    let price: Int
    let period: String
    let perks: [String]
    let recommended: Bool

    func toModel() -> SubscriptionPlan {
        SubscriptionPlan(name: name, price: price, period: period, perks: perks, recommended: recommended)
    }
}

// MARK: - Calendar bookings (per device_user_id)

struct BookedSessionRow: Decodable {
    let id: UUID
    let date: String
    let title: String
    let trainerName: String

    enum CodingKeys: String, CodingKey {
        case id, date, title
        case trainerName = "trainer_name"
    }

    func toModel() -> BookedSession {
        BookedSession(id: id, date: SupabaseDate.parse(date), title: title, trainerName: trainerName)
    }
}

struct BookedSessionInsert: Encodable {
    let id: UUID
    let deviceUserID: String
    let date: String
    let title: String
    let trainerName: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceUserID = "device_user_id"
        case date, title
        case trainerName = "trainer_name"
    }
}

// MARK: - Cart (per device_user_id)

struct CartLineRow: Decodable {
    let id: UUID
    let name: String
    let price: Int

    func toModel() -> CartLine { CartLine(id: id, name: name, price: price) }
}

struct CartLineInsert: Encodable {
    let id: UUID
    let deviceUserID: String
    let name: String
    let price: Int

    enum CodingKeys: String, CodingKey {
        case id
        case deviceUserID = "device_user_id"
        case name, price
    }
}

// MARK: - Date helpers

/// Supabase timestamptz columns come back as ISO 8601 strings; parsed by
/// hand (rather than trusting the SDK's default JSONDecoder date
/// strategy) so this works the same regardless of SDK version.
enum SupabaseDate {
    static func parse(_ string: String) -> Date {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string) ?? Date()
    }

    static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
