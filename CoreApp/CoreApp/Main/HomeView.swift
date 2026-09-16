import SwiftUI

/// Figma frame 51:896 "iPhone 16 & 17 Pro Max - 6" — the main hub screen.
struct HomeView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    heroWithOccupancy

                    progressCard

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        NavigationLink { WorkoutPlansView() } label: {
                            QuickActionTile(icon: "calendar", title: "Book", highlighted: true)
                        }
                        NavigationLink { PersonalTrainersView() } label: {
                            QuickActionTile(icon: "person", title: "Trainers")
                        }
                        NavigationLink { FoodRecipesView() } label: {
                            QuickActionTile(icon: "fork.knife", title: "Food")
                        }
                        NavigationLink { SupplementsView() } label: {
                            QuickActionTile(icon: "cart", title: "Store")
                        }
                        NavigationLink { ScanView() } label: {
                            QuickActionTile(icon: "qrcode.viewfinder", title: "Scan")
                        }
                        NavigationLink { CoreAIView() } label: {
                            QuickActionTile(icon: "cpu", title: "Core AI")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .tint(.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("RC Rezindtsii Arhitektorov")
                .font(Theme.Typeface.display(20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: 220, alignment: .leading)
            Spacer()
            HStack(spacing: 12) {
                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
                NavigationLink { ProfileView() } label: {
                    Image(systemName: "bag")
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var heroWithOccupancy: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: 0x2A2A2A), Color(hex: 0x141414)], startPoint: .top, endPoint: .bottom)
                )
                .frame(height: 260)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Club Occupancy")
                        .font(Theme.Typeface.display(24, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.orange)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("84")
                        .font(Theme.Typeface.stat(48))
                        .foregroundStyle(.white)
                    Text("38 of 90 in the club")
                        .font(Theme.Typeface.display(16))
                        .foregroundStyle(Theme.muted)
                }

                WeeklyBarChart(values: [0.3, 0.45, 1.0, 0.5], labels: ["06", "10", "14", "22"], highlightIndex: 2)
            }
            .padding(24)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(Theme.Typeface.display(24, weight: .semibold))
                .foregroundStyle(.white)

            HStack(alignment: .center) {
                Text("67%")
                    .font(Theme.Typeface.stat(48))
                    .foregroundStyle(.white)
                Spacer()
                WeeklyBarChart(values: [0.2, 0.4, 0.3, 0.7, 0.5, 0.9, 0.4], labels: [], highlightIndex: 3)
                    .frame(height: 46)
            }

            NavigationLink {
                ProgressDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Capsule()
                        .fill(Theme.placeholder.opacity(0.25))
                        .frame(height: 10)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.purple).frame(width: 220, height: 10)
                        }
                    HStack {
                        Text("day 1").font(Theme.Typeface.display(16)).foregroundStyle(.white)
                        Spacer()
                        Text("38 mins training").font(Theme.Typeface.display(16)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
    }
}

#Preview {
    HomeView()
}
