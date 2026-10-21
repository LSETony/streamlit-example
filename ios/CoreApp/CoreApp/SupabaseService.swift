import Foundation
import Supabase

/// Project credentials. The app must use the SAME Supabase project as the
/// core. platform (the gym dashboard), otherwise it can't see the member's
/// gym, memberships or schedule. Set `CoreSupabaseURL` and
/// `CoreSupabaseAnonKey` in Info.plist (the dashboard's
/// NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY); the values
/// below are only a fallback. The anon/public key is designed to be
/// embedded in client apps — access is controlled by Row Level Security.
/// Never put a service_role key here.
enum SupabaseConfig {
    private static let fallbackURL = "https://ubykgrowhekmsvxhvjxf.supabase.co"
    private static let fallbackAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVieWtncm93aGVrbXN2eGh2anhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMDk2NDEsImV4cCI6MjEwNTU4NTY0MX0.K0QlpHidEUaQAMvo4lC8KNTf2wWZCQsKYIUFuDknm0c"

    static let projectURL: URL = URL(string: plistValue("CoreSupabaseURL") ?? fallbackURL)!
    static let anonKey: String = plistValue("CoreSupabaseAnonKey") ?? fallbackAnonKey

    private static func plistValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}

/// Shared Supabase client used for every table read/write in the app.
let supabase = SupabaseClient(supabaseURL: SupabaseConfig.projectURL, supabaseKey: SupabaseConfig.anonKey)

/// A stable per-install identifier used to scope `booked_sessions` and
/// `cart_items` rows to "this member" without requiring the signed-in
/// provider (Apple/Google/phone) to also hold a Supabase Auth session.
/// Generated once and kept in UserDefaults.
enum DeviceUser {
    private static let key = "core.deviceUserID"

    static var id: String = {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()
}
