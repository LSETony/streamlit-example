import SwiftUI

private enum HomeSheet: String, Identifiable {
    case booking, trainers, nutrition, store, scanner, ai, workout, pass
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: MainTab
    @State private var activeSheet: HomeSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                occupancyCard
                inProgressCard
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
        case .pass: QRPassView()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Welcome back!")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.appSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button { activeSheet = .pass } label: {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var occupancyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Club Occupancy")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button { activeSheet = .booking } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(appState.occupancyPercent)")
                    .font(.brand(44))
                    .foregroundStyle(.white)
                Text("38 of 90 in the club")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
            }
            BarChartView(bars: appState.occupancyByHour, highlightHour: 14)
        }
        .glowCard()
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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(appState.workoutTimeString)
                    .font(.digitalTimer(28))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(18)
            .background(Color.appPurple)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear { if appState.isWorkoutInProgress { appState.startTimer() } }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            gridTile(icon: "calendar", title: "Book", filled: true) { activeSheet = .booking }
            gridTile(icon: "person.2.fill", title: "Trainers", filled: false) { activeSheet = .trainers }
            gridTile(icon: "fork.knife", title: "Food", filled: false) { activeSheet = .nutrition }
            gridTile(icon: "cart.fill", title: "Store", filled: false) { activeSheet = .store }
            gridTile(icon: "camera.viewfinder", title: "Scan", filled: false) { activeSheet = .scanner }
            gridTile(icon: "sparkles", title: "Core AI", filled: false) { activeSheet = .ai }
        }
    }

    private func gridTile(icon: String, title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(filled ? .white : Color.appTextSecondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(filled ? Color.appAccent : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(filled ? .clear : Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environmentObject(AppState())
}
