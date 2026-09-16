import SwiftUI

private enum HomeSheet: String, Identifiable {
    case booking, trainers, nutrition, store, scanner, ai, workout
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: MainTab
    @State private var activeSheet: HomeSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                    .padding(.bottom, 34) // room for the occupancy card overlap
                    .overlay(alignment: .bottom) {
                        occupancyGlassCard
                            .screenPadding()
                            .offset(y: 34)
                    }

                progressCard
                    .screenPadding()
                iconGrid
                    .screenPadding()

                Divider().overlay(Color.appDivider).screenPadding().padding(.top, 6)

                VStack(alignment: .leading, spacing: 18) {
                    readinessCard
                    inProgressCard
                    upcomingSection
                }
                .screenPadding()
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
    }

    // MARK: Hero (photo header + search/store icons)

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            PhotoPlaceholder(style: .gym, icon: "figure.strengthtraining.traditional")
                .frame(height: 250)

            HStack {
                Text(appState.clubName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                Spacer()
                heroIconButton("magnifyingglass") {}
                heroIconButton("bag.fill") { activeSheet = .store }
            }
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.top, 56)
        }
        .clipped()
    }

    private func heroIconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var occupancyGlassCard: some View {
        Button { activeSheet = .booking } label: {
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
                        .background(Color.appAccent)
                        .clipShape(Circle())
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
                    ForEach(appState.occupancyBars.prefix(6).indices, id: \.self) { i in
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
        .buttonStyle(.plain)
    }

    // MARK: Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15))
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

    // MARK: Icon grid (circular buttons)

    private var iconGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            circleTile(icon: "calendar", title: "Book", highlighted: true) { activeSheet = .booking }
            circleTile(icon: "person.2.fill", title: "Trainers") { activeSheet = .trainers }
            circleTile(icon: "leaf.fill", title: "Food") { activeSheet = .nutrition }
            circleTile(icon: "cart.fill", title: "Store") { activeSheet = .store }
            circleTile(icon: "qrcode.viewfinder", title: "Scan") { activeSheet = .scanner }
            circleTile(icon: "gearshape.fill", title: "Core AI") { activeSheet = .ai }
        }
    }

    private func circleTile(icon: String, title: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(highlighted ? Color.appAccent : Color.clear)
                    .overlay(Circle().stroke(highlighted ? .clear : Color.appDivider, lineWidth: 1))
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sheetView(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .booking: NavigationStack { BookingView() }
        case .trainers: NavigationStack { TrainersView() }
        case .nutrition: NavigationStack { FoodRecipesView() }
        case .store: NavigationStack { StoreView() }
        case .scanner: NavigationStack { ScannerView() }
        case .ai: NavigationStack { AIAssistantView() }
        case .workout: NavigationStack { WorkoutSessionView() }
        }
    }

    private var readinessCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.appSurfaceElevated, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: Double(appState.readiness) / 100)
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(appState.readiness)")
                        .font(.digitalTimer(30))
                        .foregroundStyle(.white)
                    Text("READY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text("RECOMMENDED TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.appAccent)
                Text(appState.recommendedWorkoutTitle)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                Text(appState.recommendedWorkoutMeta)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .appCard(padding: 20)
    }

    private var inProgressCard: some View {
        Button { activeSheet = .workout } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("IN PROGRESS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Continue Push A")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(appState.workoutTimeString)
                    .font(.digitalTimer(26))
                    .foregroundStyle(.white)
            }
            .padding(20)
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear { if appState.isWorkoutInProgress { appState.startTimer() } }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderRow(title: "Upcoming", trailing: "Calendar") {
                selectedTab = .calendar
            }
            ForEach(appState.upcoming) { event in
                UpcomingRow(event: event)
            }
        }
    }

}

private struct UpcomingRow: View {
    let event: ScheduleEvent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.time)
                .font(.digitalTimer(17))
                .foregroundStyle(event.status == .booked ? Color.appAccent : Color.appTextSecondary)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(event.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            StatusBadge(text: event.status.rawValue, color: event.status.color)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(AppState())
}
