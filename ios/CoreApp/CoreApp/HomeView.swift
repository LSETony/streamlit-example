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
                header
                readinessCard
                inProgressCard
                occupancyCard
                upcomingSection
                grid
            }
            .screenPadding()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .booking: NavigationStack { BookingView() }
        case .trainers: NavigationStack { TrainersView() }
        case .nutrition: NavigationStack { NutritionView() }
        case .store: NavigationStack { StoreView() }
        case .scanner: NavigationStack { ScannerView() }
        case .ai: NavigationStack { AIAssistantView() }
        case .workout: NavigationStack { WorkoutSessionView() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: "Sunday 13 Sep")
                Text("Hey, \(appState.userName)")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("\(appState.streakDays)")
                        .font(.digitalTimer(15))
                        .foregroundStyle(Color.appAccent)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.appAccentDim)
                .clipShape(Capsule())

                Button { selectedTab = .me } label: {
                    Text(appState.initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.appSurfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
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

    private var occupancyCard: some View {
        Button { activeSheet = .booking } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    EyebrowLabel(text: "Club occupancy")
                    Spacer()
                    Text("QUIET")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.appSuccess)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    Text("\(appState.occupancyPercent)%")
                        .font(.digitalTimer(42))
                        .foregroundStyle(.white)
                    Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.bottom, 6)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(appState.occupancyBars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(i == 3 ? Color.appAccent : Color.appSurfaceElevated)
                            .frame(height: max(4, appState.occupancyBars[i] * 44))
                    }
                }
                .frame(height: 44, alignment: .bottom)
                .padding(.top, 8)
            }
            .appCard(padding: 20)
        }
        .buttonStyle(.plain)
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

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            gridTile(icon: "calendar.badge.plus", title: "Book", highlighted: false) { activeSheet = .booking }
            gridTile(icon: "person.2.fill", title: "Trainers", highlighted: false) { activeSheet = .trainers }
            gridTile(icon: "leaf.fill", title: "Food", highlighted: false) { activeSheet = .nutrition }
            gridTile(icon: "pills.fill", title: "Store", highlighted: false) { activeSheet = .store }
            gridTile(icon: "viewfinder", title: "Scan", highlighted: false) { activeSheet = .scanner }
            gridTile(icon: "sparkles", title: "core AI", highlighted: true) { activeSheet = .ai }
        }
    }

    private func gridTile(icon: String, title: String, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(highlighted ? Color.appAccentDim : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(highlighted ? Color.appAccent : Color.appDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
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
