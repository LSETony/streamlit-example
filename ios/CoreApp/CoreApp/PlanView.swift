import SwiftUI

/// Matches "isPlan": week compliance, the week's plan days, an exercise
/// library carousel, and workout history.
struct PlanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var startWorkout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                complianceCard
                planDaysList
                libraryCarousel
                historyList
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .navigationDestination(isPresented: $startWorkout) {
            WorkoutSessionView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "Week 6 of 12 · hypertrophy block")
            Text("Your plan")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var complianceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowLabel(text: "Week compliance")
                Spacer()
                Text("\(appState.weekComplianceDone)/\(appState.weekComplianceTotal)")
                    .font(.digitalTimer(20))
                    .foregroundStyle(Color.appAccent)
            }
            HStack(spacing: 6) {
                ForEach(0..<appState.weekComplianceTotal, id: \.self) { i in
                    Capsule()
                        .fill(i < appState.weekComplianceDone ? Color.appAccent : Color.appSurfaceElevated)
                        .frame(height: 6)
                }
            }
            Text("Written by Mika Orlov · updated after your 02 Sep scan")
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextSecondary)
        }
        .appCard(padding: 20)
    }

    private var planDaysList: some View {
        VStack(spacing: 10) {
            ForEach(appState.planDays) { day in
                Button {
                    if day.isToday { startWorkout = true }
                } label: {
                    HStack(spacing: 14) {
                        Text(day.day)
                            .font(.digitalTimer(15))
                            .foregroundStyle(day.isToday ? Color.appAccent : Color.appTextSecondary)
                            .frame(width: 38, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text(day.detail).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text(day.isToday ? "START" : "DONE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(day.isToday ? Color.appAccent : Color.appSuccess)
                    }
                    .padding(16)
                    .background(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                            .stroke(day.isToday ? Color.appAccent : Color.appDivider, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var libraryCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Exercise library · 240")
                Spacer()
                Text("SEE ALL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.appAccent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.library) { exercise in
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.appSurfaceElevated)
                                Text(exercise.group.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(Color.appTextSecondary)
                                    .padding(8)
                            }
                            .frame(height: 54)
                            Text(exercise.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(exercise.meta)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(14)
                        .background(Color.appSurface)
                        .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                    }
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "History")
            VStack(spacing: 0) {
                ForEach(appState.history) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            Text("\(entry.date) · \(entry.duration)").font(.system(size: 11)).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text(entry.volume).font(.digitalTimer(16)).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.vertical, 12)
                    AppDivider()
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PlanView() }
        .environmentObject(AppState())
}
