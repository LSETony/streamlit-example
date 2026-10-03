import SwiftUI

/// Opened from Progress's "Log scan" button — lets a member enter the
/// numbers off the gym's InBody machine printout after a scan. Appends a
/// new InBodyEntry (AppState.logInBodyScan), which immediately updates the
/// Body Composition stat tiles and trend chart.
struct LogInBodyScanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bodyFat: String = ""
    @State private var bodyWater: String = ""
    @State private var visceralFat: String = ""
    @State private var bmr: String = ""

    private var parsedBodyFat: Double? { Double(bodyFat) }
    private var parsedBodyWater: Double? { Double(bodyWater) }
    private var parsedVisceralFat: Int? { Int(visceralFat) }
    private var parsedBMR: Int? { Int(bmr) }

    private var isValid: Bool {
        parsedBodyFat != nil && parsedBodyWater != nil && parsedVisceralFat != nil && parsedBMR != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log InBody Scan")
                            .font(.brand(28))
                            .foregroundStyle(.white)
                        Text("Enter the numbers from your latest InBody printout.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(spacing: 12) {
                        scanField(label: "Body Fat %", text: $bodyFat, placeholder: "16.2")
                        scanField(label: "Total Body Water %", text: $bodyWater, placeholder: "58.4")
                        scanField(label: "Visceral Fat Index", text: $visceralFat, placeholder: "7")
                        scanField(label: "Basal Metabolic Rate", text: $bmr, placeholder: "1720")
                    }

                    PrimaryButton(title: "Save scan", isEnabled: isValid, color: .appAccentPurple) {
                        guard let fat = parsedBodyFat, let water = parsedBodyWater, let vfi = parsedVisceralFat, let rate = parsedBMR else { return }
                        appState.logInBodyScan(bodyFatPercent: fat, totalBodyWaterPercent: water, visceralFatIndex: vfi, basalMetabolicRate: rate)
                        dismiss()
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func scanField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.4)))
                .keyboardType(.decimalPad)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
    }
}

#Preview {
    LogInBodyScanView()
        .environmentObject(AppState())
}
