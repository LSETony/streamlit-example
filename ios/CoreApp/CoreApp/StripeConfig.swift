import Foundation

/// Stripe's publishable key is safe to embed client-side by design (same
/// trust model as the Supabase anon key) — the secret key that can actually
/// move money lives only in the create-payment-intent Edge Function's
/// server-side environment, never in the app.
enum StripeConfig {
    static let publishableKey = "pk_test_51UIZuWJyNC0FtLaFA2fuZPpNVjQEzgtyA0fYw9595ErbSrVJjHZHWK5HymTmFwZ1sGvp42FlygwsIw4rjlbOeZEW00sAg8TU5z"

    static var isConfigured: Bool {
        publishableKey.hasPrefix("pk_")
    }
}
