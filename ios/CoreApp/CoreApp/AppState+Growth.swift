import Foundation

/// Streaks, check-ins, referrals, the leaderboard and the before/after
/// photo gallery — all backed by supabase/add_growth_features.sql's
/// `member_stats` and `progress_photos` tables, kept out of
/// AppState+Supabase.swift so that file stays focused on the read-only
/// catalog load. Same device-scoping trust model as booked_sessions/cart
/// items throughout the rest of the app (see AppState+Supabase.swift's
/// doc comment): the anon key can write any row, scoping is enforced by
/// only ever querying/writing this device's own `device_user_id`.
extension AppState {
    /// Call once on launch (see loadFromSupabase) to hydrate the streak,
    /// visit count and referral code from this device's server-side row —
    /// creating one (seeded with the existing cosmetic defaults, so a
    /// returning tester doesn't see their visit count jump to 0) the first
    /// time this device is ever seen.
    func loadMemberStats() async {
        let rows: [MemberStatsRow] = await fetchOwn("member_stats")
        if let row = rows.first {
            totalVisits = row.totalVisits
            streakDays = row.currentStreak
            lastActivityDate = row.lastActivityDate.flatMap(SupabaseDate.parseDay)
            referralCode = row.referralCode ?? (await ensureReferralCode())
        } else {
            referralCode = Self.generateReferralCode()
            await upsertMemberStats(
                MemberStatsInsert(
                    deviceUserID: DeviceUser.id, displayName: fullName, totalVisits: totalVisits,
                    currentStreak: streakDays, lastActivityDate: nil, referralCode: referralCode, referredBy: nil
                )
            )
        }
    }

    // MARK: Check-in (QR scan at reception)

    /// Called after a successful QR scan (CheckInView) or a completed
    /// in-app workout (ActiveWorkoutView) — either one counts as "showed
    /// up today" for streak purposes, so both funnel through here.
    @discardableResult
    func recordActivity() async -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if let lastActivityDate, Calendar.current.isDate(lastActivityDate, inSameDayAs: today) {
            return false // already counted today — avoid double-counting a second scan/workout same day
        }
        if let lastActivityDate, let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today),
           Calendar.current.isDate(lastActivityDate, inSameDayAs: yesterday) {
            streakDays += 1
        } else {
            streakDays = 1
        }
        lastActivityDate = today
        totalVisits += 1
        await upsertMemberStats(
            MemberStatsInsert(
                deviceUserID: DeviceUser.id, displayName: fullName, totalVisits: totalVisits,
                currentStreak: streakDays, lastActivityDate: SupabaseDate.formatDay(today),
                referralCode: referralCode.isEmpty ? nil : referralCode, referredBy: nil
            )
        )
        return true
    }

    // MARK: Referrals

    /// Generates and persists a code if this device doesn't have one yet.
    @discardableResult
    func ensureReferralCode() async -> String {
        if !referralCode.isEmpty { return referralCode }
        let code = Self.generateReferralCode()
        referralCode = code
        await upsertMemberStats(
            MemberStatsInsert(
                deviceUserID: DeviceUser.id, displayName: fullName, totalVisits: totalVisits,
                currentStreak: streakDays, lastActivityDate: lastActivityDate.map(SupabaseDate.formatDay),
                referralCode: code, referredBy: nil
            )
        )
        return code
    }

    /// Redeems someone else's referral code on this (fresh) device — call
    /// once, e.g. from an "I was invited" field during onboarding.
    func redeemReferralCode(_ code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty, trimmed != referralCode else { return }
        await ensureReferralCode()
        await upsertMemberStats(
            MemberStatsInsert(
                deviceUserID: DeviceUser.id, displayName: fullName, totalVisits: totalVisits,
                currentStreak: streakDays, lastActivityDate: lastActivityDate.map(SupabaseDate.formatDay),
                referralCode: referralCode, referredBy: trimmed
            )
        )
    }

    private static func generateReferralCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no 0/O/1/I — avoids look-alike typos
        return "CORE-" + String((0..<6).map { _ in alphabet.randomElement()! })
    }

    // MARK: Leaderboard

    func refreshLeaderboard() async {
        let rows: [MemberStatsRow] = await fetch("member_stats", select: "*")
        leaderboard = rows
            .sorted { $0.totalVisits > $1.totalVisits }
            .prefix(20)
            .map { row in
                LeaderboardEntry(
                    id: row.deviceUserID, displayName: row.displayName, totalVisits: row.totalVisits,
                    streakDays: row.currentStreak, isMe: row.deviceUserID == DeviceUser.id
                )
            }
    }

    private func upsertMemberStats(_ row: MemberStatsInsert) async {
        do {
            try await supabase.from("member_stats").upsert(row, onConflict: "device_user_id").execute()
        } catch {
            print("Supabase upsertMemberStats failed: \(error)")
        }
    }

    // MARK: Progress photos (before/after gallery)

    func loadProgressPhotos() async {
        let rows: [ProgressPhotoRow] = await fetchOwn("progress_photos")
        progressPhotos = rows
            .map { ProgressPhoto(id: $0.id, imageURL: URL(string: $0.imageURL) ?? SupabaseConfig.projectURL, takenAt: SupabaseDate.parse($0.takenAt)) }
            .sorted { $0.takenAt > $1.takenAt }
    }

    /// Uploads a photo the member just picked (PhotosPicker) to the shared
    /// `media` Storage bucket and records it in `progress_photos`. Like
    /// every other asset in this bucket it ends up at a public URL (see
    /// StoreView/HomeView's existing Storage-backed media) — there's no
    /// per-user privacy on Storage objects in this project yet, only on
    /// who the app *shows* the photo to.
    func uploadProgressPhoto(_ imageData: Data) async {
        let photoID = UUID()
        let path = "progress/\(DeviceUser.id)/\(photoID.uuidString).jpg"
        do {
            try await supabase.storage.from("media").upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            let publicURL = try supabase.storage.from("media").getPublicURL(path: path)
            let row = ProgressPhotoInsert(id: photoID, deviceUserID: DeviceUser.id, imageURL: publicURL.absoluteString)
            try await supabase.from("progress_photos").insert(row).execute()
            progressPhotos.insert(ProgressPhoto(id: photoID, imageURL: publicURL, takenAt: Date()), at: 0)
        } catch {
            let message = "uploadProgressPhoto: \(error)"
            print("Supabase \(message)")
            supabaseDebugMessage = supabaseDebugMessage ?? message
        }
    }

    func deleteProgressPhoto(_ photo: ProgressPhoto) async {
        progressPhotos.removeAll { $0.id == photo.id }
        do {
            try await supabase.from("progress_photos").delete().eq("id", value: photo.id.uuidString).execute()
        } catch {
            print("Supabase deleteProgressPhoto failed: \(error)")
        }
    }
}

// MARK: - Row types

private struct MemberStatsRow: Decodable {
    let deviceUserID: String
    let displayName: String
    let totalVisits: Int
    let currentStreak: Int
    let lastActivityDate: String?
    let referralCode: String?

    enum CodingKeys: String, CodingKey {
        case deviceUserID = "device_user_id"
        case displayName = "display_name"
        case totalVisits = "total_visits"
        case currentStreak = "current_streak"
        case lastActivityDate = "last_activity_date"
        case referralCode = "referral_code"
    }
}

private struct MemberStatsInsert: Encodable {
    let deviceUserID: String
    let displayName: String
    let totalVisits: Int
    let currentStreak: Int
    let lastActivityDate: String?
    let referralCode: String?
    let referredBy: String?

    enum CodingKeys: String, CodingKey {
        case deviceUserID = "device_user_id"
        case displayName = "display_name"
        case totalVisits = "total_visits"
        case currentStreak = "current_streak"
        case lastActivityDate = "last_activity_date"
        case referralCode = "referral_code"
        case referredBy = "referred_by"
    }
}

private struct ProgressPhotoRow: Decodable {
    let id: UUID
    let deviceUserID: String
    let imageURL: String
    let takenAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceUserID = "device_user_id"
        case imageURL = "image_url"
        case takenAt = "taken_at"
    }
}

private struct ProgressPhotoInsert: Encodable {
    let id: UUID
    let deviceUserID: String
    let imageURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceUserID = "device_user_id"
        case imageURL = "image_url"
    }
}

extension SupabaseDate {
    /// `date` (not `timestamptz`) columns — just "2025-06-01", no time
    /// component — used by member_stats.last_activity_date.
    static func parseDay(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)
    }

    static func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
