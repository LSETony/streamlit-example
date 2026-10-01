import SwiftUI

private enum HomeSheet: String, Identifiable {
    case trainers, nutrition, store, location, progress, occupancy, subscriptions, book, coreAI
    var id: String { rawValue }
}

/// Matches the redesigned Home frame (Figma node 391:476): photo hero with
/// the club name and wallet icon, two overlapping cards (Occupancy +
/// Specials for today), a Sets/Time/Calories stats row, and the 6-icon
/// grid — replaces the earlier single occupancy card + "Your Progress"
/// sparkline card layout.
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeSheet: HomeSheet?
    @State private var showGymPhoto = false
    @State private var pendingGymPhoto = false
    @State private var isShowingScan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                hero

                HStack(spacing: 10) {
                    occupancyCard
                    specialsCard
                }
                .screenPadding()
                .padding(.top, -224) // nests the cards inside the photo, matching the source proportions

                statsRow
                    .screenPadding()
                iconGrid
                    .screenPadding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $activeSheet, onDismiss: {
            // Chains straight into the location's photo/info sheet right
            // after picking one — matches the reference flow (pick a
            // location -> its detail card opens automatically).
            if pendingGymPhoto {
                pendingGymPhoto = false
                showGymPhoto = true
            }
        }) { sheet in
            sheetView(for: sheet)
        }
        .sheet(isPresented: $showGymPhoto) {
            GymPhotoViewer()
        }
        .fullScreenCover(isPresented: $isShowingScan) {
            ScanView()
        }
    }

    // MARK: Hero (photo header + store icon)

    private var hero: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ZStack {
                    Color.appBackground
                    if !appState.heroVideoURLs.isEmpty {
                        HeroVideoQueue(player: appState.heroVideoPlayer.player)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: AppMetrics.cardCorner,
                        bottomTrailingRadius: AppMetrics.cardCorner, topTrailingRadius: 0,
                        style: .continuous
                    )
                )

                HStack {
                    Button {
                        activeSheet = .location
                    } label: {
                        HStack(spacing: 6) {
                            Text(appState.clubName)
                                .font(.brand(20))
                                .foregroundStyle(.white)
                                .shadow(radius: 6)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    heroIconButton("IconWallet") { activeSheet = .subscriptions }
                }
                .padding(.horizontal, AppMetrics.screenPadding)
                .padding(.top, 56)
            }
        }
        .frame(height: 500)
    }

    private func heroIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon).customIcon(size: 20)
                .foregroundStyle(.white)
                .frame(width: 72, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var occupancyCard: some View {
        Button {
            activeSheet = .occupancy
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Occupancy")
                    .font(.brand(16))
                    .foregroundStyle(.white)
                Text("\(appState.occupancyPercent)%")
                    .font(.digitalTimer(56))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(trafficLabel)
                    .font(.digitalTimer(13))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                pillLabel("View more", background: .appAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .frame(height: 196)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var specialsCard: some View {
        Button {
            activeSheet = .store
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Specials for today")
                    .font(.brand(16))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                pillLabel("Check out", background: .appAccentPurple.opacity(0.2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .frame(height: 196)
            .background(Color.appAccentPurple)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pillLabel(_ text: String, background: Color) -> some View {
        Text(text)
            .font(.brand(10))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(Capsule())
    }

    /// A quick, dynamic read on how busy the club is right now — same
    /// thresholds OccupancyDetailView's full breakdown implies, just
    /// condensed to one word for this small card.
    private var trafficLabel: String {
        switch appState.occupancyPercent {
        case 80...: return "huge traffic"
        case 50..<80: return "moderate traffic"
        default: return "light traffic"
        }
    }

    // MARK: Stats row (Sets / Time / Calories)

    private var statsRow: some View {
        Button {
            activeSheet = .progress
        } label: {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    statTile(label: "Sets", value: "\(appState.trainingSetsToday)")
                    statTile(label: "Time", value: Self.formatMinutes(appState.trainingMinutesToday))
                    statTile(label: "Calories", value: "\(appState.trainingCaloriesToday)")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.brand(16))
                .foregroundStyle(.white)
            Text(value)
                .font(.digitalTimer(36))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private static func formatMinutes(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        return "\(minutes / 60)h\(minutes % 60)"
    }

    // MARK: Icon grid (rounded-rect glass tiles)

    private var iconGrid: some View {
        GlassEffectContainer(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                rectTile(icon: "IconCalendar", title: "Book", highlighted: true) { activeSheet = .book }
                rectTile(icon: "IconPerson", title: "Trainers") { activeSheet = .trainers }
                rectTile(icon: "IconFood", title: "Food") { activeSheet = .nutrition }
                rectTile(icon: "IconCart", title: "Store") { activeSheet = .store }
                rectTile(icon: "IconFaceScan", title: "Scan") { isShowingScan = true }
                rectTile(icon: "IconAISparkle", title: "Core AI") { activeSheet = .coreAI }
            }
        }
    }

    private func rectTile(icon: String, isSystemIcon: Bool = false, title: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if isSystemIcon {
                        Image(systemName: icon).font(.system(size: 26, weight: .semibold))
                    } else {
                        Image(icon).customIcon(size: 28)
                    }
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(title)
                    .font(.brand(14))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 130)
            .glassEffect(
                highlighted ? .regular.tint(.appAccent).interactive() : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(highlighted ? .clear : .white.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sheetView(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .trainers: NavigationStack { TrainersView() }
        case .nutrition: NavigationStack { FoodRecipesView() }
        case .store: NavigationStack { StoreView() }
        case .location: LocationPickerView(onSelect: { pendingGymPhoto = true })
        case .progress: ProgressDetailView()
        case .occupancy: OccupancyDetailView()
        case .subscriptions: SubscriptionsView()
        case .book: BookZoneView()
        case .coreAI: CoreAIChatView()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
