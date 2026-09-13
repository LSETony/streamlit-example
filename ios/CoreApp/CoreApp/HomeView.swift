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
                statsRow
                clubServicesSection
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.appTextSecondary)
                Text("Hey, \(appState.userName)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(appState.membershipDay) DAY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appAccentDim)
                    .clipShape(Capsule())
                InitialsAvatar(initials: appState.userName.prefix(2).uppercased(), size: 34)
            }
        }
    }

    private var readinessCard: some View {
        HStack(spacing: 16) {
            RingProgressView(
                progress: Double(appState.readiness) / 100,
                size: 88,
                centerValue: "\(appState.readiness)",
                centerLabel: "Ready"
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("RECOMMENDED TODAY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.appAccent)
                Text(appState.recommendedWorkoutTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.recommendedWorkoutMeta)
                    .font(.system(size: 13))
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .appCard()
    }

    private var inProgressCard: some View {
        Button { activeSheet = .workout } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IN PROGRESS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Continue Push A")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(appState.workoutTimeString)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(18)
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear { if appState.isWorkoutInProgress { appState.startTimer() } }
    }

    private var occupancyCard: some View {
        Button { activeSheet = .booking } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    EyebrowLabel(text: "Club occupancy")
                    Spacer()
                    Text(appState.occupancyLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(appState.occupancyColor)
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(appState.occupancyPercent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("38 of 90 in the club")
                        .font(.system(size: 13))
                        .foregroundStyle(.appTextSecondary)
                }
                BarChartView(bars: appState.occupancyByHour, highlightHour: 10)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderRow(title: "Upcoming", trailing: "Calendar") {
                selectedTab = .plan
            }
            ForEach(appState.upcoming) { event in
                UpcomingRow(event: event) {
                    appState.confirmEvent(event)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: String(format: "%.1ft", appState.volumeThisWeekTons), label: "Volume wk")
            StatTile(value: "\(appState.kcalInToday)", label: "Kcal in")
            StatTile(value: String(format: "%.1f", appState.muscleKg), label: "Muscle kg")
        }
    }

    private var clubServicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Club services")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ServiceTile(icon: "square.grid.2x2.fill", title: "Book a zone", subtitle: "Free slots today") {
                    activeSheet = .booking
                }
                ServiceTile(icon: "person.2.fill", title: "Trainers", subtitle: "14 specialists") {
                    activeSheet = .trainers
                }
                ServiceTile(icon: "fork.knife", title: "Nutrition", subtitle: "\(appState.kcalRemaining) kcal left") {
                    activeSheet = .nutrition
                }
                ServiceTile(icon: "pills.fill", title: "Supplements", subtitle: "Pickup at club") {
                    activeSheet = .store
                }
                ServiceTile(icon: "camera.viewfinder", title: "Scan a label", subtitle: "Check interactions") {
                    activeSheet = .scanner
                }
                ServiceTile(icon: "sparkles", title: "Ask core AI", subtitle: "Training & nutrition") {
                    activeSheet = .ai
                }
            }
        }
    }
}

private struct UpcomingRow: View {
    let event: ScheduleEvent
    var onConfirm: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.time)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.appAccent)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(event.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.appTextSecondary)
            }
            Spacer()
            Button {
                onConfirm()
            } label: {
                StatusBadge(text: event.status.rawValue, color: event.status.color)
            }
            .buttonStyle(.plain)
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
