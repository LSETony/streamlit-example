import Foundation
import CoreLocation
import CryptoKit
import Security
import Supabase

/// Connection to the core. gym platform (the CRM the gym's front desk and
/// owner use). The member signs in with Supabase Auth as before
/// (AuthService); this service then links that account to the member's
/// record in their gym — by the verified email or phone on the account —
/// and loads everything the front desk sees: memberships, visits, the
/// class schedule and a rotating QR pass the reception scanner accepts.
///
/// Requires the app to point at the same Supabase project as the platform
/// (SupabaseConfig in SupabaseService.swift) and `CorePlatformURL` in
/// Info.plist for the two server calls (checkout, account deletion).
@MainActor
final class CoreMemberService: ObservableObject {
    enum Phase: Equatable {
        case signedOut, loading, needsGym, ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .signedOut
    @Published private(set) var clients: [CoreLinkedClient] = []
    @Published var currentClientID: String? {
        didSet { UserDefaults.standard.set(currentClientID, forKey: Self.currentClientKey) }
    }
    @Published private(set) var gym: CoreGym?
    @Published private(set) var memberships: [CoreMembership] = []
    @Published private(set) var classes: [CoreClass] = []
    @Published private(set) var visitsCount: Int?
    @Published private(set) var memberSince: Date?
    @Published private(set) var device: CoreDevice?

    private static let currentClientKey = "core.platform.clientID"

    init() {
        currentClientID = UserDefaults.standard.string(forKey: Self.currentClientKey)
        device = CoreKeychain.loadDevice()
    }

    var isLinked: Bool { phase == .ready && currentClient != nil }
    var currentClient: CoreLinkedClient? { clients.first { $0.clientID == currentClientID } ?? clients.first }

    /// The membership valid today (active or frozen), if any.
    var activeMembership: CoreMembership? {
        let today = CoreDates.day(Date())
        return memberships.first { ($0.status == "active" || $0.status == "frozen") && $0.startsOn <= today && $0.endsOn >= today }
    }

    var onlinePlans: [CorePlan] { gym?.plans.filter { $0.soldOnline ?? false } ?? [] }

    // MARK: Loading

    /// Call after sign-in and on launch. Links the account to the gym and
    /// loads the member's data; leaves `phase == .needsGym` when the
    /// account isn't a client of any gym yet (show CoreJoinGymView).
    func refresh() async {
        guard (try? await supabase.auth.session) != nil else {
            reset()
            return
        }
        if phase != .ready { phase = .loading }
        do {
            let link: CoreLinkResult = try await supabase.rpc("link_account").execute().value
            clients = link.clients
            guard let client = currentClient else {
                phase = .needsGym
                return
            }
            currentClientID = client.clientID
            async let gymResult: CoreGym = supabase.rpc("public_gym", params: CoreGymParams(p_gym: client.gymID)).execute().value
            async let membershipRows: [CoreMembership] = supabase.from("memberships")
                .select("id,plan_name,kind,status,starts_on,ends_on,visits_left,freeze_days_max,freeze_days_used")
                .eq("client_id", value: client.clientID)
                .order("ends_on", ascending: false)
                .execute().value
            async let clientRow: [CoreClientRow] = supabase.from("clients")
                .select("created_at")
                .eq("id", value: client.clientID)
                .execute().value
            async let visits = supabase.from("visits")
                .select("id", head: true, count: .exact)
                .eq("client_id", value: client.clientID)
                .execute().count
            gym = try await gymResult
            memberships = try await membershipRows
            memberSince = try await clientRow.first.flatMap { CoreDates.timestamp($0.createdAt) }
            visitsCount = try await visits
            phase = .ready
            await registerDevice()
            await loadSchedule()
        } catch {
            phase = .failed(CoreError.message(for: error))
        }
    }

    func switchGym(to client: CoreLinkedClient) async {
        currentClientID = client.clientID
        await refresh()
    }

    func loadSchedule() async {
        guard let gymID = currentClient?.gymID else { return }
        classes = (try? await supabase.rpc("public_schedule", params: CoreScheduleParams(p_gym: gymID, p_days: 14)).execute().value) ?? []
    }

    func reset() {
        phase = .signedOut
        clients = []
        gym = nil
        memberships = []
        classes = []
        visitsCount = nil
        memberSince = nil
    }

    // MARK: Joining a gym

    func searchGyms(_ query: String) async -> [CorePublicGym] {
        var request = supabase.from("public_gyms").select("id,name,address,region")
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { request = request.ilike("name", pattern: "%\(trimmed)%") }
        return (try? await request.order("name").limit(30).execute().value) ?? []
    }

    func joinGym(_ gymID: String, fullName: String, phone: String, marketingConsent: Bool) async throws {
        let params = CoreJoinParams(p_gym: gymID, p_full_name: fullName, p_marketing_consent: marketingConsent,
                                    p_phone: phone.isEmpty ? nil : phone)
        let clientID: String = try await supabase.rpc("join_gym", params: params).execute().value
        currentClientID = clientID
        await refresh()
    }

    // MARK: QR pass

    /// Registers this iPhone for the QR pass (and push, once a token is
    /// available). Registering a new phone revokes the previous one, so a
    /// copied secret stops working.
    func registerDevice(pushToken: String? = nil) async {
        let params = CoreDeviceParams(p_platform: "ios", p_push_token: pushToken, p_device_id: device?.deviceID)
        guard let result: CoreDevice = try? await supabase.rpc("register_device", params: params).execute().value else { return }
        device = result
        CoreKeychain.saveDevice(result)
    }

    /// `CORE1:<device>:<t>:<sig>` — t = unix time / 30, sig = first 16 bytes
    /// of HMAC-SHA256(qr_secret, "CORE1:<device>:<t>") in hex. Matches the
    /// platform's verify_qr: a screenshot older than a minute is rejected.
    func qrPayload(at date: Date = Date()) -> String? {
        guard let device, let keyData = Data(hexString: device.qrSecret) else { return nil }
        let t = Int(date.timeIntervalSince1970) / 30
        let message = "CORE1:\(device.deviceID.lowercased()):\(t)"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: keyData))
        let signature = Data(mac).prefix(16).map { String(format: "%02x", $0) }.joined()
        return "\(message):\(signature)"
    }

    // MARK: Booking, freezing, buying

    func book(_ item: CoreClass) async throws {
        if let bookingID = item.myBookingID {
            _ = try await supabase.rpc("cancel_booking", params: CoreCancelParams(p_booking: bookingID)).execute()
        } else {
            _ = try await supabase.rpc("book_class", params: CoreBookParams(p_item: item.id, p_client: nil)).execute()
        }
        await loadSchedule()
    }

    func freeze(_ membership: CoreMembership, from start: Date, days: Int) async throws {
        let end = Calendar.current.date(byAdding: .day, value: max(days, 1) - 1, to: start) ?? start
        let params = CoreFreezeParams(p_membership: membership.id, p_from: CoreDates.day(start), p_to: CoreDates.day(end), p_reason: nil)
        _ = try await supabase.rpc("freeze_membership", params: params).execute()
        await refresh()
    }

    /// Opens the gym's payment page (Stripe in the UAE, YooKassa in Russia).
    /// The membership turns active once the payment provider confirms.
    func checkoutURL(for plan: CorePlan) async throws -> URL {
        struct Body: Encodable { let plan_id: String }
        struct Reply: Decodable { let url: String }
        let data = try await callPlatform("api/member/checkout", body: Body(plan_id: plan.id))
        guard let url = URL(string: (try JSONDecoder().decode(Reply.self, from: data)).url) else { throw CoreError.server("No payment URL") }
        return url
    }

    /// Anonymizes the member at every gym and deletes the sign-in account
    /// (App Store requirement). Payments stay with the gym for accounting.
    func deleteAccount() async throws {
        struct Empty: Encodable {}
        _ = try await callPlatform("api/member/delete", body: Empty())
        CoreKeychain.deleteDevice()
        device = nil
        reset()
    }

    private func callPlatform(_ path: String, body: some Encodable) async throws -> Data {
        let token = try await supabase.auth.session.accessToken
        var request = URLRequest(url: CorePlatformConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let reply = try? JSONDecoder().decode(CorePlatformErrorReply.self, from: data)
            throw CoreError.platform(code: reply?.code ?? "ERROR", message: reply?.message ?? "Server error")
        }
        return data
    }
}

// MARK: - Configuration

enum CorePlatformConfig {
    /// The core. dashboard's public address (same as PUBLIC_APP_URL on
    /// Vercel). Set `CorePlatformURL` in Info.plist.
    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CorePlatformURL") as? String, let url = URL(string: value), !value.isEmpty {
            return url
        }
        return URL(string: "https://streamlit-example-6xag.vercel.app")!
    }
}

// MARK: - Models (decoded from the platform's tables and functions)

struct CoreLinkedClient: Decodable, Identifiable, Hashable {
    let clientID: String
    let gymID: String
    let gymName: String
    let fullName: String
    var id: String { clientID }

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id", gymID = "gym_id", gymName = "gym_name", fullName = "full_name"
    }
}

struct CoreLinkResult: Decodable {
    let clients: [CoreLinkedClient]
}

struct CorePublicGym: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let region: String?
}

struct CoreGym: Decodable {
    let id: String
    let name: String
    let address: String?
    let phone: String?
    let region: String
    let currency: String
    let timezone: String
    let schedule: Bool
    let plans: [CorePlan]
}

struct CorePlan: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let kind: String
    let price: Int
    let durationDays: Int
    let visitsLimit: Int?
    let soldOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, kind, price
        case durationDays = "duration_days", visitsLimit = "visits_limit", soldOnline = "sold_online"
    }
}

struct CoreMembership: Decodable, Identifiable, Hashable {
    let id: String
    let planName: String
    let kind: String
    let status: String
    let startsOn: String
    let endsOn: String
    let visitsLeft: Int?
    let freezeDaysMax: Int
    let freezeDaysUsed: Int

    var freezeDaysLeft: Int { max(0, freezeDaysMax - freezeDaysUsed) }

    enum CodingKeys: String, CodingKey {
        case id, kind, status
        case planName = "plan_name", startsOn = "starts_on", endsOn = "ends_on", visitsLeft = "visits_left"
        case freezeDaysMax = "freeze_days_max", freezeDaysUsed = "freeze_days_used"
    }
}

struct CoreClass: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let trainerName: String?
    let zone: String?
    let startsAt: String
    let endsAt: String
    let capacity: Int
    let booked: Int
    let myBookingID: String?

    var start: Date? { CoreDates.timestamp(startsAt) }
    var end: Date? { CoreDates.timestamp(endsAt) }
    var freeSpots: Int { max(0, capacity - booked) }

    enum CodingKeys: String, CodingKey {
        case id, title, zone, capacity, booked
        case trainerName = "trainer_name", startsAt = "starts_at", endsAt = "ends_at", myBookingID = "my_booking_id"
    }
}

struct CoreDevice: Codable, Equatable {
    let deviceID: String
    let qrSecret: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id", qrSecret = "qr_secret"
    }
}

private struct CoreClientRow: Decodable {
    let createdAt: String
    enum CodingKeys: String, CodingKey { case createdAt = "created_at" }
}

private struct CorePlatformErrorReply: Decodable {
    let code: String?
    let message: String?
}

// MARK: - Function parameters

private struct CoreGymParams: Encodable, Sendable { let p_gym: String }
private struct CoreScheduleParams: Encodable, Sendable { let p_gym: String; let p_days: Int }
private struct CoreJoinParams: Encodable, Sendable { let p_gym: String; let p_full_name: String; let p_marketing_consent: Bool; let p_phone: String? }
private struct CoreDeviceParams: Encodable, Sendable { let p_platform: String; let p_push_token: String?; let p_device_id: String? }
private struct CoreBookParams: Encodable, Sendable { let p_item: String; let p_client: String? }
private struct CoreCancelParams: Encodable, Sendable { let p_booking: String }
private struct CoreFreezeParams: Encodable, Sendable { let p_membership: String; let p_from: String; let p_to: String; let p_reason: String? }

// MARK: - Errors

enum CoreError: LocalizedError {
    case platform(code: String, message: String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .platform(let code, let message): return CoreError.localized(code: code) ?? message
        case .server(let message): return message
        }
    }

    /// Database functions raise `{hint: MACHINE_CODE, message}`. Known codes
    /// get a translated text (Localizable.xcstrings); others fall back to
    /// the server's message.
    static func message(for error: Error) -> String {
        if let postgrest = error as? PostgrestError {
            if let hint = postgrest.hint, let text = localized(code: hint) { return text }
            return postgrest.message
        }
        return error.localizedDescription
    }

    static func localized(code: String) -> String? {
        let key: String.LocalizationValue
        switch code {
        case "CLASS_FULL": key = "No spots left"
        case "NO_ACTIVE_MEMBERSHIP": key = "No active membership on the class date"
        case "CANCEL_TOO_LATE": key = "It's too late to cancel this booking"
        case "CLASS_STARTED": key = "The class has already started"
        case "ALREADY_BOOKED": key = "You're already booked for this class"
        case "FREEZE_NOT_ALLOWED": key = "The gym doesn't allow freezing from the app — please contact the front desk"
        case "FREEZE_LIMIT": key = "Freeze limit exceeded"
        case "PHONE_REQUIRED": key = "Enter your phone number"
        case "PHONE_TAKEN": key = "This number is already registered at the gym. Ask the front desk to add your email"
        case "GYM_READ_ONLY": key = "The gym isn't accepting changes right now"
        case "PLAN_NOT_FOR_SALE": key = "This plan isn't sold in the app"
        case "STRIPE_NOT_CONNECTED": key = "This gym doesn't take online payments yet"
        default: return nil
        }
        return String(localized: key, locale: AppLanguage.current.locale)
    }
}

// MARK: - Dates

enum CoreDates {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso = ISO8601DateFormatter()

    /// "2026-10-21" in the device's time zone — the format of Postgres `date`.
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func parseDay(_ value: String) -> Date? { dayFormatter.date(from: value) }
    static func timestamp(_ value: String) -> Date? { isoFractional.date(from: value) ?? iso.date(from: value) }
}

// MARK: - Keychain (QR pass secret)

enum CoreKeychain {
    private static let account = "core.platform.device"

    static func saveDevice(_ device: CoreDevice) {
        guard let data = try? JSONEncoder().encode(device) else { return }
        deleteDevice()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadDevice() -> CoreDevice? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(CoreDevice.self, from: data)
    }

    static func deleteDevice() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

// MARK: - Profile from the platform

extension AppState {
    /// Replaces the sample profile (name, visits, membership, club) with the
    /// member's real data from their gym once linked.
    func applyPlatformProfile(_ core: CoreMemberService) {
        guard core.isLinked, let client = core.currentClient else { return }
        fullName = client.fullName
        if let visits = core.visitsCount { totalVisits = visits }
        if let since = core.memberSince {
            let formatter = DateFormatter()
            formatter.locale = preferredLanguage.locale
            formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
            memberSince = formatter.string(from: since)
        }
        if let membership = core.activeMembership {
            membershipPlanName = membership.planName
            if let end = CoreDates.parseDay(membership.endsOn) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "d MMM yyyy"
                membershipRenewDate = formatter.string(from: end)
            }
        } else {
            membershipPlanName = String(localized: "No active membership", locale: preferredLanguage.locale)
            membershipRenewDate = "—"
        }
        guard let gym = core.gym else { return }
        if gymLocations.contains(where: { $0.name == gym.name }) {
            clubName = gym.name
            return
        }
        // Put the member's real gym on the club map: geocode its address once.
        let address = gym.address ?? ""
        Task { @MainActor in
            let placemark = try? await CLGeocoder().geocodeAddressString(address).first
            guard let coordinate = placemark?.location?.coordinate else { return }
            let location = GymLocation(
                name: gym.name, city: placemark?.locality ?? "", address: address,
                latitude: coordinate.latitude, longitude: coordinate.longitude,
                hoursLabel: "", description: ""
            )
            if !self.gymLocations.contains(where: { $0.name == gym.name }) {
                self.gymLocations.insert(location, at: 0)
            }
            self.clubName = gym.name
        }
    }
}
