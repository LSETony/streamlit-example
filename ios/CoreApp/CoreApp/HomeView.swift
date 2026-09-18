import SwiftUI

private enum HomeSheet: String, Identifiable {
    case trainers, nutrition, store, location, progress, occupancy, subscriptions, book, coreAI
    var id: String { rawValue }
}

/// Matches the Home frame in the Figma source exactly: photo hero with the
/// club name and store icon, an occupancy glass card overlapping
/// the photo, a progress card, and the 6-icon grid. Nothing else — there is
/// no readiness ring, in-progress banner, or upcoming list in the source.
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeSheet: HomeSheet?
    @State private var showGymPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                hero

                occupancyGlassCard
                    .screenPadding()
                    .padding(.top, -224) // nests the card inside the photo, matching the source proportions

                progressCard
                    .screenPadding()
                iconGrid
                    .screenPadding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
        .sheet(isPresented: $showGymPhoto) {
            GymPhotoViewer()
        }
    }

    // MARK: Hero (photo header + store icon)

    private var hero: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Button {
                    showGymPhoto = true
                } label: {
                    Image("HomeHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .buttonStyle(.plain)

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

    private var occupancyGlassCard: some View {
        Button {
            activeSheet = .occupancy
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Club Occupancy")
                        .font(.brand(24))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular.tint(.appAccent), in: Circle())
                }
                HStack(alignment: .bottom, spacing: 10) {
                    Text("\(appState.occupancyPercent)")
                        .font(.digitalTimer(48))
                        .foregroundStyle(.white)
                    Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                        .font(.brand(16))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 6)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(appState.occupancyBars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(i == 2 ? Color.appAccent : .white.opacity(0.7))
                            .frame(height: max(4, appState.occupancyBars[i] * 40))
                    }
                }
                .frame(height: 40, alignment: .bottom)
                .padding(.top, 4)
                HStack {
                    ForEach(["06", "10", "14", "22"], id: \.self) { hour in
                        Text(hour).font(.brand(10)).foregroundStyle(.white.opacity(0.6))
                        if hour != "22" { Spacer() }
                    }
                }
            }
            .glassCard(padding: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: Progress card

    private var progressCard: some View {
        Button {
            activeSheet = .progress
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Progress")
                    .font(.brand(24))
                    .foregroundStyle(.white)
                HStack(alignment: .bottom) {
                    Text("\(appState.trainingProgressPercent)%")
                        .font(.digitalTimer(48))
                        .foregroundStyle(.white)
                    Spacer()
                    progressSparkline
                }
                ProgressBarView(value: Double(appState.trainingProgressPercent) / 100, color: .appAccentPurple, height: 20)
                HStack {
                    Text("day \(appState.trainingDay)").font(.brand(16)).foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Text("\(appState.trainingMinutesToday) mins training").font(.brand(16)).foregroundStyle(Color.appTextSecondary)
                }
            }
            .appCard(padding: 20)
        }
        .buttonStyle(.plain)
    }

    /// The mini bar-chart sparkline next to the progress percentage —
    /// matches the source's exact 9-bar geometry (accent bars mark days
    /// with a completed workout).
    private var progressSparkline: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(appState.progressSparkline.indices, id: \.self) { i in
                let bar = appState.progressSparkline[i]
                Capsule()
                    .fill(bar.highlighted ? Color.appAccent : .white.opacity(0.7))
                    .frame(width: 6, height: max(4, bar.value * 40))
            }
        }
        .frame(height: 40, alignment: .bottom)
    }

    // MARK: Icon grid (rounded-rect glass tiles)

    private var iconGrid: some View {
        GlassEffectContainer(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                rectTile(icon: "IconCalendar", title: "Book", highlighted: true) { activeSheet = .book }
                rectTile(icon: "IconPerson", title: "Trainers") { activeSheet = .trainers }
                rectTile(icon: "IconFood", title: "Food") { activeSheet = .nutrition }
                rectTile(icon: "IconCart", title: "Store") { activeSheet = .store }
                rectTile(icon: "IconFaceScan", title: "Scan") {}
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
        case .location: LocationPickerView()
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
