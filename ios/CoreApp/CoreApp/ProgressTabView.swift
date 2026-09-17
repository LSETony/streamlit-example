import SwiftUI

/// The Progress tab — confirmed as a real tab by the source's nav bar
/// component, but no dedicated Progress screen frame was in the Figma
/// file, so this surfaces the same real training-progress data as Home's
/// "Your Progress" card, just full-screen, rather than inventing content.
struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progress")
                    .font(.brand(32))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Training progress")
                    Text("\(appState.trainingProgressPercent)%")
                        .font(.digitalTimer(48))
                        .foregroundStyle(.white)
                    ProgressBarView(value: Double(appState.trainingProgressPercent) / 100, color: .appAccentPurple, height: 10)
                    HStack {
                        Text("day \(appState.trainingDay)").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(appState.trainingMinutesToday) mins training").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                    }
                }
                .appCard(padding: 20)

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Club occupancy")
                    HStack(alignment: .bottom, spacing: 10) {
                        Text("\(appState.occupancyPercent)")
                            .font(.digitalTimer(38))
                            .foregroundStyle(.white)
                        Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.bottom, 6)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(appState.occupancyBars.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(i == 3 ? Color.appAccent : Color.appSurfaceElevated)
                                .frame(height: max(4, appState.occupancyBars[i] * 40))
                        }
                    }
                    .frame(height: 40, alignment: .bottom)
                }
                .appCard(padding: 20)
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(AppState())
}
