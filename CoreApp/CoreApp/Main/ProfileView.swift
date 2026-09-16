import SwiftUI

/// Figma frame 95:249 "iPhone 16 & 17 Pro Max - 10" — member profile / membership card.
struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                memberRow
                qrCard
                membershipCard
                statsRow
                appleHealthCard

                PrimaryButton(title: "Logout", color: Theme.purple) {}
                    .padding(.top, 8)
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var memberRow: some View {
        HStack(spacing: 16) {
            Circle().fill(Theme.placeholder.opacity(0.3)).frame(width: 60, height: 60)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text("Jarvis Kitsune Jr").font(Theme.Typeface.display(16, weight: .semibold)).foregroundStyle(.white)
                Text("Member since March 2023").font(Theme.Typeface.display(10)).foregroundStyle(.white)
            }
            Spacer()
            VStack {
                Text("128 visits").font(Theme.Typeface.display(16, weight: .medium)).foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(Theme.orange, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous).stroke(Color.white, lineWidth: 1))
    }

    private var qrCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QR access pass").font(Theme.Typeface.display(24, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white)
            }
            Text("Turnstile and reception check-in")
                .font(Theme.Typeface.display(16))
                .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Membership").font(Theme.Typeface.display(20, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white)
            }
            Text("Unlimited 24/7").font(Theme.Typeface.stat(32)).foregroundStyle(.white)
            Text("renews 12 mar 2027").font(Theme.Typeface.display(16)).foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.purple, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "18", label: "visits")
            statTile(value: "6", label: "scans")
            statTile(value: "3", label: "pt left")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(Theme.Typeface.stat(32)).foregroundStyle(.white)
            Text(label).font(Theme.Typeface.display(16)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 111)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Color.white, lineWidth: 1))
    }

    private var appleHealthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Apple Health").font(Theme.Typeface.display(24, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white)
            }
            Text("Steps, sleep, heart rate syncing")
                .font(Theme.Typeface.display(16))
                .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack { ProfileView() }
}
