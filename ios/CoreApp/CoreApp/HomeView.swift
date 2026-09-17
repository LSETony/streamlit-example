import SwiftUI

private enum HomeSheet: String, Identifiable {
    case trainers, nutrition, store, location
    var id: String { rawValue }
}

/// Matches the Home frame in the Figma source exactly: photo hero with the
/// club name and search/store icons, an occupancy glass card overlapping
/// the photo, a progress card, and the 6-icon grid. Nothing else — there is
/// no readiness ring, in-progress banner, or upcoming list in the source.
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var activeSheet: HomeSheet?
    @State private var showGymPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                occupancyGlassCard
                    .screenPadding()
                    .padding(.top, -50) // overlaps the bottom of the photo

                progressCard
                    .screenPadding()
                iconGrid
                    .screenPadding()
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
        .fullScreenCover(isPresented: $showGymPhoto) {
            GymPhotoViewer()
        }
    }

    // MARK: Hero (photo header + search/store icons)

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            Button {
                showGymPhoto = true
            } label: {
                Image("HomeHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 250)
                    .clipped()
            }
            .buttonStyle(.plain)

            HStack {
                Button {
                    activeSheet = .location
                } label: {
                    HStack(spacing: 6) {
                        Text(appState.clubName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 6)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 14) {
                        heroIconButton("IconSearch") {}
                        heroIconButton("IconWallet") { activeSheet = .store }
                    }
                }
            }
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.top, 56)
        }
        .clipped()
    }

    private func heroIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon).customIcon(size: 20)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var occupancyGlassCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Club Occupancy")
                    .font(.system(size: 16, weight: .semibold))
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
                    .font(.digitalTimer(38))
                    .foregroundStyle(.white)
                Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 6)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(appState.occupancyBars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(i == 3 ? Color.appAccent : .white.opacity(0.7))
                        .frame(height: max(4, appState.occupancyBars[i] * 40))
                }
            }
            .frame(height: 40, alignment: .bottom)
            .padding(.top, 4)
            HStack {
                ForEach(["06", "10", "14", "22"], id: \.self) { hour in
                    Text(hour).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    if hour != "22" { Spacer() }
                }
            }
        }
        .glassCard(padding: 18)
    }

    // MARK: Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image("IconTrending").customIcon(size: 16)
                    .foregroundStyle(Color.appAccent)
            }
            Text("\(appState.trainingProgressPercent)%")
                .font(.digitalTimer(34))
                .foregroundStyle(.white)
            ProgressBarView(value: Double(appState.trainingProgressPercent) / 100, color: .appAccentPurple, height: 8)
            HStack {
                Text("day \(appState.trainingDay)").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("\(appState.trainingMinutesToday) mins training").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
        }
        .appCard(padding: 20)
    }

    // MARK: Icon grid (rounded-rect glass tiles)

    private var iconGrid: some View {
        GlassEffectContainer(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                rectTile(icon: "IconCalendar", title: "Book", highlighted: true) {}
                rectTile(icon: "person.2.fill", isSystemIcon: true, title: "Trainers") { activeSheet = .trainers }
                rectTile(icon: "leaf.fill", isSystemIcon: true, title: "Food") { activeSheet = .nutrition }
                rectTile(icon: "IconWallet", title: "Store") { activeSheet = .store }
                rectTile(icon: "IconFaceScan", title: "Scan") {}
                rectTile(icon: "IconAISparkle", title: "Core AI") {}
            }
        }
    }

    private func rectTile(icon: String, isSystemIcon: Bool = false, title: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Group {
                    if isSystemIcon {
                        Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                    } else {
                        Image(icon).customIcon(size: 20)
                    }
                }
                .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .glassEffect(
                highlighted ? .regular.tint(.appAccent).interactive() : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
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
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
