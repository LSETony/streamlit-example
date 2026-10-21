import Foundation

/// A minimal, standalone copy of AuthService.swift's SupabaseConfig — the
/// widget extension target doesn't link the Supabase SPM package (it only
/// needs one read-only REST call, via plain URLSession, so pulling in the
/// whole SDK just for this one request isn't worth the extra binary size
/// in a widget's tight memory budget). Same public anon key as the main
/// app; it's called "anon" because it's meant to be embedded client-side —
/// see AuthService.swift's doc comment.
enum WidgetSupabaseConfig {
    static let projectURL = URL(string: "https://ubykgrowhekmsvxhvjxf.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVieWtncm93aGVrbXN2eGh2anhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMDk2NDEsImV4cCI6MjEwNTU4NTY0MX0.K0QlpHidEUaQAMvo4lC8KNTf2wWZCQsKYIUFuDknm0c"
}
