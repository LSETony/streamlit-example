import SwiftUI

private enum WorkoutsTab: String, CaseIterable {
    case personal = "Personal", group = "Group", solo = "Solo"
}

/// Matches "isWorkouts" — the screen the center tab-bar dumbbell button
/// opens: Personal (your trainer sessions), Group (club classes) and Solo
/// (from-your-plan / open-floor shortcuts).
struct WorkoutsView: View {
    @EnvironmentObject var appState: AppState
    @State private var tab: WorkoutsTab = .personal
    @State private var showPlan = false
    @State private var showBooking = false
    @State private var showTrainer: Trainer?
    @State private var startWorkout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    segmentedControl
                    switch tab {
                    case .personal: personalContent
                    case .group: groupContent
                    case .solo: soloContent
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPlan) { PlanView() }
            .navigationDestination(isPresented: $startWorkout) { WorkoutSessionView() }
            .sheet(isPresented: $showBooking) { NavigationStack { BookingView() } }
            .sheet(item: $showTrainer) { trainer in
                NavigationStack { TrainerDetailView(trainer: trainer) }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Workouts")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { showPlan = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(WorkoutsTab.allCases, id: \.self) { t in
                Text(t.rawValue)
                    .font(.system(size: 13, weight: tab == t ? .semibold : .medium))
                    .foregroundStyle(tab == t ? .white : Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(tab == t ? Color.appSurface : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture { tab = t }
            }
        }
        .padding(2)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Personal

    private var personalContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Next session")
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        InitialsAvatar(initials: "MO", color: .appTextPrimary, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mika Orlov").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            Text("Tue 16 Sep · 07:30 · Hall 2").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text("60m").font(.digitalTimer(15)).foregroundStyle(Color.appAccent)
                    }
                    .padding(16)
                    AppDivider()
                    navRow(title: "Reschedule or cancel", color: .appAccent) {}
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Three personal sessions left on your membership. Cancel more than 12 hours ahead to keep the credit.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Book a trainer")
                VStack(spacing: 0) {
                    ForEach(Array(appState.trainers.enumerated()), id: \.element.id) { index, trainer in
                        Button { showTrainer = trainer } label: {
                            HStack(spacing: 12) {
                                InitialsAvatar(initials: trainer.initials, color: .appTextPrimary, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trainer.name).font(.system(size: 16)).foregroundStyle(.white)
                                    Text(trainer.specialty).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                                }
                                Spacer()
                                Text(trainer.nextAvailable).font(.system(size: 14)).foregroundStyle(trainer.availabilityColor)
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        if index < appState.trainers.count - 1 { AppDivider() }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: Group

    private var groupContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Today · 13 September")
                VStack(spacing: 0) {
                    ForEach(Array(appState.groupClasses.enumerated()), id: \.element.id) { index, groupClass in
                        HStack(spacing: 12) {
                            Text(groupClass.time)
                                .font(.digitalTimer(15))
                                .foregroundStyle(.white)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(groupClass.name).font(.system(size: 16)).foregroundStyle(.white)
                                Text(groupClass.subtitle).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            classButton(groupClass.state)
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, 16)
                        .opacity(groupClass.state == .full ? 0.55 : 1)
                        if index < appState.groupClasses.count - 1 { AppDivider() }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Waitlists clear automatically two hours before the class starts.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("This week")
                VStack(spacing: 0) {
                    navRowValue(title: "Full class timetable", value: "41 classes") {}
                    AppDivider()
                    navRowValue(title: "Your bookings", value: "2") {}
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func classButton(_ state: ClassBookingState) -> some View {
        let spec: (label: String, bg: Color, fg: Color, border: Color) = {
            switch state {
            case .book: return ("Book", .appAccent, .white, .appAccent)
            case .booked: return ("Booked", .clear, .appSuccess, .appSuccess)
            case .waitlist: return ("Waitlist", .clear, .appTextPrimary, .appDivider)
            case .full: return ("Full", .clear, .appTextSecondary, .appDivider)
            }
        }()
        return Text(spec.label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(spec.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(spec.bg)
            .overlay(Capsule().stroke(spec.border, lineWidth: 1))
            .clipShape(Capsule())
    }

    // MARK: Solo

    private var soloContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("From your plan")
                VStack(spacing: 0) {
                    Button { startWorkout = true } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appAccentDim)
                                Image(systemName: "dumbbell.fill").font(.system(size: 20)).foregroundStyle(Color.appAccent)
                            }
                            .frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push A · heavy upper").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                                Text("6 lifts · 52 min · today").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Text("Start").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.appAccent)
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                    AppDivider()
                    navRowValue(title: "Repeat Pull B · 11 Sep", value: "5.2t") { showPlan = true }
                    AppDivider()
                    navRow(title: "Build a workout from the library", color: .appAccent) { showPlan = true }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Open floor")
                VStack(spacing: 0) {
                    navRowValue(title: "Reserve a zone", value: "Quiet now", valueColor: .appSuccess) { showBooking = true }
                    AppDivider()
                    navRowValue(title: "Workout history", value: "128") { showPlan = true }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Solo sessions log to the same history as coached ones, so your volume graph stays complete.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .foregroundStyle(Color.appTextSecondary)
    }

    private func navRow(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 16)).foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func navRowValue(title: String, value: String, valueColor: Color = .appTextSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 16)).foregroundStyle(.white)
                Spacer()
                Text(value).font(.system(size: 14)).foregroundStyle(valueColor)
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AppState())
}
