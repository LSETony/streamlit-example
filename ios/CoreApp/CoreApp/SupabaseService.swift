import Foundation
import Supabase

/// Project credentials for LSETony's Supabase project. The anon/public key
/// is designed to be embedded in client apps (it's what "anon" means) —
/// access is controlled entirely by the Row Level Security policies
/// defined in supabase/schema.sql, not by keeping this key secret. Never
/// put a service_role key here.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://ubykgrowhekmsvxhvjxf.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVieWtncm93aGVrbXN2eGh2anhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMDk2NDEsImV4cCI6MjEwNTU4NTY0MX0.K0QlpHidEUaQAMvo4lC8KNTf2wWZCQsKYIUFuDknm0c"
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
