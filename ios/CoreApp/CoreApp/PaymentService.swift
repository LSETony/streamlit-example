import Foundation
import StripePaymentSheet

/// Drives real card payments: asks the create-payment-intent Supabase Edge
/// Function for a PaymentIntent client secret, then hands it to Stripe's
/// PaymentSheet for the actual card entry / Apple Pay UI. Shared by
/// SubscriptionsView (paying for a plan) and CartView (checking out).
@MainActor
final class PaymentService: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPresenting = false
    @Published var errorMessage: String?

    /// Starts a payment for `amountDollars`. Presents PaymentSheet once the
    /// server has created the PaymentIntent; call `handleCompletion` from
    /// the `.paymentSheet` view modifier's `onCompletion` closure.
    func startPayment(amountDollars: Int, description: String) async {
        errorMessage = nil
        guard StripeConfig.isConfigured else {
            errorMessage = "Payments aren't configured yet — add a real Stripe publishable key in StripeConfig.swift."
            return
        }
        do {
            let clientSecret = try await Self.fetchClientSecret(amountCents: amountDollars * 100, description: description)
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "core."
            paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
            isPresenting = true
        } catch {
            errorMessage = "Couldn't start payment: \(error.localizedDescription)"
        }
    }

    /// Returns true on a completed payment; false for cancel or failure
    /// (failure details land in `errorMessage`).
    @discardableResult
    func handleCompletion(_ result: PaymentSheetResult) -> Bool {
        switch result {
        case .completed:
            return true
        case .canceled:
            return false
        case .failed(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func fetchClientSecret(amountCents: Int, description: String) async throws -> String {
        let url = SupabaseConfig.projectURL.appendingPathComponent("functions/v1/create-payment-intent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "amount": amountCents,
            "currency": "usd",
            "description": description
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(
                domain: "Payment",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: serverMessage ?? "Payment server error"]
            )
        }

        struct Result: Decodable { let clientSecret: String }
        return try JSONDecoder().decode(Result.self, from: data).clientSecret
    }
}
