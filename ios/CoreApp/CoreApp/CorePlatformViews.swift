import SwiftUI

// Screens backed by the core. gym platform (see CoreMemberService):
// choosing your gym, the gym's class schedule with booking, and the
// member's real memberships with freezing and online purchase.

// MARK: - Join a gym

/// Shown after sign-in when the account isn't a client of any gym yet —
/// the member picks their gym and becomes a client there (the front desk
/// sees them in the client list straight away).
struct CoreJoinGymView: View {
    @EnvironmentObject var core: CoreMemberService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var gyms: [CorePublicGym] = []
    @State private var selectedGymID: String?
    @State private var fullName = ""
    @State private var phone = ""
    @State private var consent = false
    @State private var marketing = false
    @State private var isJoining = false
    @State private var errorMessage: String?

    private var canJoin: Bool {
        selectedGymID != nil && consent && fullName.trimmingCharacters(in: .whitespaces).count >= 2 && phone.filter(\.isNumber).count >= 9
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose your gym")
                        .font(.brand(32))
                        .foregroundStyle(.white)
                    Text("We couldn't find your account at any gym yet. Pick your gym — the front desk will see you in their client list.")
                        .font(.uiText(size: 14))
                        .foregroundStyle(Color.appTextSecondary)

                    field(icon: "magnifyingglass", placeholder: "Search by name", text: $query)

                    VStack(spacing: 10) {
                        ForEach(gyms) { gym in
                            Button { selectedGymID = gym.id } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(gym.name).font(.uiText(size: 16, weight: .semibold)).foregroundStyle(.white)
                                        if let address = gym.address, !address.isEmpty {
                                            Text(address).font(.uiText(size: 13)).foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: selectedGymID == gym.id ? "checkmark.circle.fill" : "circle")
                                        .font(.uiText(size: 20))
                                        .foregroundStyle(selectedGymID == gym.id ? Color.appAccent : Color.appTextSecondary)
                                }
                                .padding(16)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        if gyms.isEmpty {
                            Text("Nothing found").font(.uiText(size: 14)).foregroundStyle(Color.appTextSecondary)
                        }
                    }

                    field(icon: "person.fill", placeholder: "Full name", text: $fullName)
                    field(icon: "phone.fill", placeholder: "Phone", text: $phone, keyboard: .phonePad)

                    Toggle(isOn: $consent) {
                        Text("I agree to the processing of my personal data").font(.uiText(size: 14)).foregroundStyle(.white)
                    }
                    .tint(.appAccent)
                    Toggle(isOn: $marketing) {
                        Text("Get news and offers from the gym").font(.uiText(size: 14)).foregroundStyle(.white)
                    }
                    .tint(.appAccent)

                    if let errorMessage {
                        Text(errorMessage).font(.uiText(size: 13)).foregroundStyle(Color.appAccent)
                    }

                    PrimaryButton(title: "Join", isEnabled: canJoin, isLoading: isJoining) {
                        guard let gymID = selectedGymID else { return }
                        isJoining = true
                        errorMessage = nil
                        Task {
                            do {
                                try await core.joinGym(gymID, fullName: fullName, phone: phone, marketingConsent: marketing)
                                dismiss()
                            } catch {
                                errorMessage = CoreError.message(for: error)
                            }
                            isJoining = false
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Later") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 250_000_000)
                gyms = await core.searchGyms(query)
            }
            .onAppear {
                if fullName.isEmpty { fullName = appState.fullName }
            }
        }
    }

    private func field(icon: String, placeholder: LocalizedStringKey, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.appTextSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Color.appTextSecondary))
                .keyboardType(keyboard)
                .foregroundStyle(.white)
                .font(.uiText(size: 16))
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

// MARK: - Class schedule

/// The gym's group classes for the next two weeks, with free spots, booking
/// and cancellation. Booking checks capacity and the member's membership on
/// the platform, so nobody gets in over capacity.
struct CoreScheduleView: View {
    @EnvironmentObject var core: CoreMemberService
    @Environment(\.dismiss) private var dismiss
    @State private var busyID: String?
    @State private var errorMessage: String?

    private var days: [(day: String, items: [CoreClass])] {
        var result: [(String, [CoreClass])] = []
        for item in core.classes {
            let label = item.start.map { Self.dayFormatter.string(from: $0) } ?? ""
            if result.last?.0 == label { result[result.count - 1].1.append(item) } else { result.append((label, [item])) }
        }
        return result.map { (day: $0.0, items: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule").font(.brand(32)).foregroundStyle(.white)
                        if let gym = core.gym {
                            Text(gym.name).font(.uiText(size: 14)).foregroundStyle(Color.appTextSecondary)
                        }
                    }

                    if core.classes.isEmpty {
                        Text("No classes in the next two weeks")
                            .font(.uiText(size: 15))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.top, 20)
                    }

                    ForEach(days, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: group.day)
                            ForEach(group.items) { item in classRow(item) }
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .refreshable { await core.loadSchedule() }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .task { await core.loadSchedule() }
            .alert("Couldn't book", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func classRow(_ item: CoreClass) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(item.start.map { Self.timeFormatter.string(from: $0) } ?? "")
                    .font(.digitalTimer(20)).foregroundStyle(.white)
                Text(item.end.map { Self.timeFormatter.string(from: $0) } ?? "")
                    .font(.uiText(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            .frame(width: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.uiText(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                let meta = [item.trainerName, item.zone].compactMap { $0 }.joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta).font(.uiText(size: 13)).foregroundStyle(Color.appTextSecondary).lineLimit(1)
                }
                Group {
                    if item.freeSpots > 0 { Text("\(item.freeSpots) of \(item.capacity) spots free") } else { Text("Full") }
                }
                .font(.uiText(size: 12))
                .foregroundStyle(item.freeSpots > 0 ? Color.appTextSecondary : Color.appAccent)
            }
            Spacer(minLength: 8)

            Button {
                busyID = item.id
                Task {
                    do { try await core.book(item) } catch { errorMessage = CoreError.message(for: error) }
                    busyID = nil
                }
            } label: {
                Group {
                    if busyID == item.id { ProgressView().tint(.white) } else if item.myBookingID == nil { Text("Book") } else { Text("Cancel") }
                }
                .font(.uiText(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .tint(item.myBookingID == nil ? Color.appAccent : Color.appSurfaceElevated)
            .disabled(busyID != nil || (item.freeSpots == 0 && item.myBookingID == nil))
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - Memberships

/// The member's memberships from the gym (what the front desk sold or the
/// member bought online), with freezing, and the plans the gym sells in
/// the app. Used at the top of SubscriptionsView once linked to a gym.
struct CoreMembershipsSection: View {
    @EnvironmentObject var core: CoreMemberService
    @Environment(\.openURL) private var openURL
    @State private var freezing: CoreMembership?
    @State private var buyingPlanID: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                EyebrowLabel(text: "My memberships")
                if core.memberships.isEmpty {
                    Text("No memberships yet. Buy one below or at the front desk.")
                        .font(.uiText(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                }
                ForEach(core.memberships) { membership in
                    membershipCard(membership)
                }
            }

            if !core.onlinePlans.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    EyebrowLabel(text: "Buy a membership")
                    ForEach(core.onlinePlans) { plan in planCard(plan) }
                    Text("You'll pay on the gym's secure payment page. The membership activates automatically — pull down to refresh.")
                        .font(.uiText(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .sheet(item: $freezing) { membership in
            CoreFreezeSheet(membership: membership)
                .presentationDetents([.medium])
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func membershipCard(_ membership: CoreMembership) -> some View {
        let isLive = membership.status == "active" || membership.status == "frozen"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(membership.planName).font(.brand(22)).foregroundStyle(.white)
                Spacer()
                Text(Self.statusLabel(membership.status))
                    .font(.uiText(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(isLive ? (membership.status == "frozen" ? Color.appAccentPurple : Color.appSuccess.opacity(0.6)) : Color.appSurfaceElevated), in: Capsule())
            }
            Text(verbatim: "\(Self.display(membership.startsOn)) — \(Self.display(membership.endsOn))")
                .font(.uiText(size: 14)).foregroundStyle(Color.appTextSecondary)
            if let left = membership.visitsLeft {
                Text("Visits left: \(left)").font(.uiText(size: 14)).foregroundStyle(.white)
            }
            if membership.freezeDaysMax > 0 {
                Text("Freeze: \(membership.freezeDaysUsed) of \(membership.freezeDaysMax) days used")
                    .font(.uiText(size: 13)).foregroundStyle(Color.appTextSecondary)
            }
            if isLive && membership.freezeDaysLeft > 0 && membership.endsOn >= CoreDates.day(Date()) {
                Button { freezing = membership } label: {
                    Label("Freeze", systemImage: "snowflake")
                        .font(.uiText(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private func planCard(_ plan: CorePlan) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.brand(20)).foregroundStyle(.white)
                Group {
                    if let limit = plan.visitsLimit { Text("\(limit) visits · \(plan.durationDays) days") } else { Text("\(plan.durationDays) days") }
                }
                .font(.uiText(size: 13)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Button {
                buyingPlanID = plan.id
                Task {
                    do {
                        let url = try await core.checkoutURL(for: plan)
                        openURL(url)
                    } catch {
                        errorMessage = CoreError.message(for: error)
                    }
                    buyingPlanID = nil
                }
            } label: {
                Group {
                    if buyingPlanID == plan.id { ProgressView().tint(.white) } else { Text(Self.price(plan.price, currency: core.gym?.currency ?? "RUB")) }
                }
                .font(.uiText(size: 15, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .tint(.appAccentPurple)
            .disabled(buyingPlanID != nil)
        }
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    static func statusLabel(_ status: String) -> String {
        let key: String.LocalizationValue
        switch status {
        case "active": key = "Active"
        case "frozen": key = "Frozen"
        case "pending": key = "Awaiting payment"
        case "expired": key = "Expired"
        default: key = "Cancelled"
        }
        return String(localized: key, locale: AppLanguage.current.locale)
    }

    /// "2026-10-21" → "21.10.2026"
    static func display(_ day: String) -> String {
        let parts = day.split(separator: "-")
        return parts.count == 3 ? "\(parts[2]).\(parts[1]).\(parts[0])" : day
    }

    /// Amounts are stored in minor units (kopecks, fils).
    static func price(_ minor: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = minor % 100 == 0 ? 0 : 2
        formatter.locale = currency == "AED" ? Locale(identifier: "en_AE") : Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: Double(minor) / 100)) ?? "\(minor / 100) \(currency)"
    }
}

/// Freeze a membership from the app — only if the gym allows it; the end
/// date moves forward by the same number of days.
struct CoreFreezeSheet: View {
    let membership: CoreMembership
    @EnvironmentObject var core: CoreMemberService
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var days = 7
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Freeze membership").font(.brand(26)).foregroundStyle(.white)
            DatePicker("Starting from", selection: $start, in: Date()..., displayedComponents: .date)
                .font(.uiText(size: 15))
                .tint(.appAccent)
            Stepper(value: $days, in: 1...max(1, membership.freezeDaysLeft)) {
                Text("Days: \(days)").font(.uiText(size: 15)).foregroundStyle(.white)
            }
            Text("\(membership.freezeDaysLeft) days available. The membership is extended by the same number of days.")
                .font(.uiText(size: 13)).foregroundStyle(Color.appTextSecondary)
            if let errorMessage {
                Text(errorMessage).font(.uiText(size: 13)).foregroundStyle(Color.appAccent)
            }
            PrimaryButton(title: "Freeze", isLoading: isSaving, color: .appAccentPurple) {
                isSaving = true
                Task {
                    do {
                        try await core.freeze(membership, from: start, days: days)
                        dismiss()
                    } catch {
                        errorMessage = CoreError.message(for: error)
                    }
                    isSaving = false
                }
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { days = min(7, max(1, membership.freezeDaysLeft)) }
    }
}
