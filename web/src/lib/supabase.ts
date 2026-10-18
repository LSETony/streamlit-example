import { createClient } from "@supabase/supabase-js";

// Same project the iOS app uses (ios/CoreApp/CoreApp/SupabaseService.swift)
// — the anon key is meant to be embedded in clients; access is controlled
// by the Row Level Security policies in supabase/schema.sql, not secrecy.
const projectURL = "https://ubykgrowhekmsvxhvjxf.supabase.co";
const anonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVieWtncm93aGVrbXN2eGh2anhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMDk2NDEsImV4cCI6MjEwNTU4NTY0MX0.K0QlpHidEUaQAMvo4lC8KNTf2wWZCQsKYIUFuDknm0c";

export const supabase = createClient(projectURL, anonKey);
