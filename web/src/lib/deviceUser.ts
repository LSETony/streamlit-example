const KEY = "core.deviceUserID";

/// Web equivalent of DeviceUser.id in SupabaseService.swift — a random id
/// kept in localStorage (there, UserDefaults) so booked_sessions,
/// cart_items, member_stats and progress_photos rows can be scoped to
/// "this browser" without a Supabase Auth session backing every sign-in
/// method. A new browser/device gets a fresh id and starts over, same as
/// a fresh install on iOS.
function readOrCreate(): string {
  try {
    const existing = localStorage.getItem(KEY);
    if (existing) return existing;
    const fresh = crypto.randomUUID();
    localStorage.setItem(KEY, fresh);
    return fresh;
  } catch {
    // Storage blocked (private mode, etc.) — fall back to a per-session id.
    return crypto.randomUUID();
  }
}

export const deviceUserId = readOrCreate();
