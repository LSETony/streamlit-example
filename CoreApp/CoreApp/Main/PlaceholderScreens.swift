import SwiftUI

/// "Scan" and "Core AI" have no dedicated frame in the Figma file (they're two of the six
/// Home quick-action tiles). These stubs keep navigation complete while matching the
/// established dark / purple-accent visual language; replace with real screens once
/// their designs exist.
struct ScanView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.cardFill).frame(width: 140, height: 140)
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }
            Text("Scan a code at reception\nto check in")
                .multilineTextAlignment(.center)
                .font(Theme.Typeface.display(16))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scan")
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

struct CoreAIView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.purple.opacity(0.25)).frame(width: 140, height: 140)
                Image(systemName: "cpu")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }
            Text("Ask Core AI for a workout,\na recipe, or a recovery tip")
                .multilineTextAlignment(.center)
                .font(Theme.Typeface.display(16))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(Theme.Metrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Core AI")
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}
