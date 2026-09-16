import Foundation

enum Gender: String, CaseIterable { case men = "Men", women = "Women" }

enum Goal: String, CaseIterable {
    case muscleBuilt = "Muscle Built"
    case loseWeight = "Lose Weight"
    case stayFit = "Stay Fit & Healthy"
    case getStronger = "Get Stronger"

    var icon: String {
        switch self {
        case .muscleBuilt: return "flag"
        case .loseWeight: return "lock"
        case .stayFit: return "bolt"
        case .getStronger: return "sparkles"
        }
    }
}

enum Condition: String, CaseIterable {
    case astma = "Astma", allergic = "Allergic", diabetes = "Diabetes"
}

enum FitnessLevel: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case amateur = "Amateur"
    case advanced = "Advanced"

    var subtitle: String {
        switch self {
        case .beginner: return "This means you've just started"
        case .intermediate: return "Have an experience"
        case .amateur: return "I workout all the time"
        case .advanced: return "I know everything"
        }
    }
}

@MainActor
final class OnboardingAnswers: ObservableObject {
    @Published var gender: Gender?
    @Published var goal: Goal? = .muscleBuilt
    @Published var conditions: Set<Condition> = []
    @Published var hasNoContradictions = false
    @Published var level: FitnessLevel?
}
